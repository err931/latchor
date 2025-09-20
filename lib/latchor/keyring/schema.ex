# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Keyring.Schema do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @invalid_jwk "Invalid JWK structure"

  schema "keyring" do
    field(:sig_jwk, :map)
    field(:derive_jwk, :map)
    field(:sig_kid, :string)
    field(:derive_kid, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Build a changeset for the Latchor.Keyring schema.

  Notes:
  - put_thumbprint/3 needs a JOSE.JWK struct.
  - Always call put_thumbprint/3 before converting the JWK to a map.
  """
  def changeset(keyring, params) do
    keyring
    |> cast(params, [:sig_jwk, :derive_jwk])
    |> validate_required([:sig_jwk, :derive_jwk])
    |> validate_jwk_struct(:sig_jwk)
    |> validate_jwk_struct(:derive_jwk)
    |> put_thumbprint(:sig_jwk, :sig_kid)
    |> put_thumbprint(:derive_jwk, :derive_kid)
    |> validate_required([:sig_kid, :derive_kid])
    |> update_change(:sig_jwk, &jwk_to_map/1)
    |> update_change(:derive_jwk, &jwk_to_map/1)
  end

  defp validate_jwk_struct(changeset, field) do
    case get_field(changeset, field) do
      %JOSE.JWK{} -> changeset
      _ -> add_error(changeset, field, @invalid_jwk)
    end
  end

  defp put_thumbprint(changeset, jwk_field, kid_field) do
    case get_field(changeset, jwk_field) do
      %JOSE.JWK{} = jwk -> put_change(changeset, kid_field, JOSE.JWK.thumbprint(jwk))
      _ -> changeset
    end
  end

  defp jwk_to_map(%JOSE.JWK{} = jwk) do
    {_, map} = JOSE.JWK.to_map(jwk)
    map
  end

  defp jwk_to_map(other), do: other
end
