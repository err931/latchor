# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Keyring do
  @moduledoc """
  Tang-compatible key management for Latchor.

  This module handles:
  - Generating and storing signing/derivation keys
  - Providing public keys in JWK format
  - Performing key exchange according to Tang protocol
  """

  import Ecto.Query

  alias Latchor.Keyring.RecoveryJWKValidator
  alias Latchor.Keyring.Schema
  alias Latchor.Repo

  @curve :secp521r1
  @signature_opts %{"alg" => "ES512", "key_ops" => ["sign", "verify"]}
  @derive_opts %{"alg" => "ECMR", "key_ops" => ["deriveKey"]}
  @jws_header %{"alg" => "ES512", "cty" => "jwk-set+json"}
  @verify_key_ops %{"key_ops" => ["verify"]}

  @doc """
  Fetches the latest key pair from the database.
  If none exists, generates and stores a new one.
  """
  @spec fetch() :: Schema.t()
  def fetch, do: fetch_latest_keys() || create_new_keys!()

  @doc """
  Fetches a key pair by its signature key ID.
  """
  @spec fetch(String.t()) :: Schema.t() | nil
  def fetch(sig_kid) when is_binary(sig_kid) do
    Schema
    |> where([k], k.sig_kid == ^sig_kid)
    |> select([k], struct(k, [:sig_jwk, :derive_jwk]))
    |> Repo.one()
  end

  @doc """
  Signs the server's public keys (signature + derivation) into a JWS.
  Returns the signed JWS map.
  """
  @spec sign(Schema.t()) :: map()
  def sign(%Schema{} = schema) do
    sig_jwk = JOSE.JWK.from_map(schema.sig_jwk)
    derive_jwk = JOSE.JWK.from_map(schema.derive_jwk)

    public_sig_jwk_map = sig_jwk |> JOSE.JWK.merge(@verify_key_ops) |> public_jwk_map()
    public_derive_jwk_map = public_jwk_map(derive_jwk)

    jwks_payload = JSON.encode!(%{"keys" => [public_sig_jwk_map, public_derive_jwk_map]})

    {_, signed_map} = JOSE.JWS.sign(sig_jwk, jwks_payload, @jws_header)
    signed_map
  end

  @doc """
  Validates a given JWK map using the RecoveryJWKValidator changeset.
  """
  @spec validate(map()) :: Ecto.Changeset.t()
  def validate(jwk_map), do: RecoveryJWKValidator.changeset(%RecoveryJWKValidator{}, jwk_map)

  @doc """
  Fetches the derivation JWK by its key ID.
  """
  @spec fetch_derive_jwk(String.t()) :: map() | nil
  def fetch_derive_jwk(derive_kid) when is_binary(derive_kid) do
    Schema
    |> where([k], k.derive_kid == ^derive_kid)
    |> select([k], k.derive_jwk)
    |> Repo.one()
  end

  @doc """
  Generates a new signing and derivation key pair, stores it in the database,
  and returns the stored schema.
  """
  @spec create_new_keys!() :: Schema.t()
  def create_new_keys! do
    sig_jwk = generate_jwk(@signature_opts)
    derive_jwk = generate_jwk(@derive_opts)
    save_keys!(sig_jwk, derive_jwk)
  end

  @doc """
  Deletes all key records except the most recently inserted one.
  """
  def delete_old_keys do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_old,
      from(k in Schema,
        where:
          k.id !=
            subquery(
              Schema
              |> last(:inserted_at)
              |> select([k], k.id)
            )
      )
    )
    |> Repo.transaction()
  end

  @spec fetch_latest_keys() :: Schema.t() | nil
  defp fetch_latest_keys do
    Schema
    |> last(:inserted_at)
    |> select([k], struct(k, [:sig_jwk, :derive_jwk]))
    |> Repo.one()
  end

  @spec generate_jwk(map()) :: map()
  defp generate_jwk(opts) do
    @curve
    |> JOSE.JWK.generate_key()
    |> JOSE.JWK.merge(opts)
  end

  @spec save_keys!(map(), map()) :: Schema.t()
  defp save_keys!(sig_jwk, derive_jwk) do
    %Schema{}
    |> Schema.changeset(%{sig_jwk: sig_jwk, derive_jwk: derive_jwk})
    |> Repo.insert!()
  end

  @spec public_jwk_map(JOSE.JWK.t()) :: map()
  defp public_jwk_map(jwk) do
    {_, jwk_map} = JOSE.JWK.to_public_map(jwk)
    jwk_map
  end
end
