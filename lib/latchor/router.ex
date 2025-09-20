# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Router do
  @moduledoc """
  HTTP router for Tang-compatible key exchange and advertisement endpoints.
  """

  use Plug.Router

  alias Latchor.Keyring
  alias Latchor.Keyring.KeyExchange

  require Logger

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: JSON
  )

  plug(:match)
  plug(:dispatch)

  # Health Check
  get "/health" do
    send_resp(conn, :ok, "")
  end

  # Returns the signed advertisement JWK for the latest key.
  get "/adv" do
    Logger.info("Received latest key advertisement request")
    respond_with_signed_jwk(conn, Keyring.fetch())
  end

  # Returns the signed advertisement JWK for a specific key ID.
  get "/adv/:kid" do
    Logger.info("Received key advertisement request for key ID: #{kid}")

    case Keyring.fetch(kid) do
      nil -> send_resp(conn, :not_found, "")
      jwk_record -> respond_with_signed_jwk(conn, jwk_record)
    end
  end

  # Performs key recovery using the provided parameters and key ID.
  post "/rec/:kid" do
    Logger.info("Received key recovery request for key ID: #{kid}")

    changeset = Keyring.validate(conn.body_params)

    if changeset.valid? do
      case Keyring.fetch_derive_jwk(kid) do
        nil ->
          Logger.error("Key ID not found for recovery: #{kid}")
          send_resp(conn, :not_found, "")

        derive_jwk_map ->
          Logger.info("Performing key exchange for key ID: #{kid}")
          recovery_jwk = KeyExchange.exchange(derive_jwk_map, conn.body_params)

          conn
          |> put_resp_content_type("application/jwk+json")
          |> send_resp(:ok, recovery_jwk)
      end
    else
      Logger.error("Invalid recovery request parameters for key ID: #{kid}")
      send_resp(conn, :bad_request, "")
    end
  end

  # Rotates the server keys and returns the new key ID.
  put "/rotate_keys" do
    new_keys = Keyring.create_new_keys!()
    Logger.info("Keys rotated successfully. New key ID: #{new_keys.sig_kid}")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, JSON.encode!(%{status: "ok", kid: new_keys.sig_kid}))
  end

  # Deletes all key records except the most recently inserted one.
  delete "/purge_old_keys" do
    case Keyring.delete_old_keys() do
      {:ok, %{delete_old: {count, _}}} ->
        Logger.info("Deleted #{count} old key(s)")
        send_resp(conn, :ok, JSON.encode!(%{status: "ok", deleted: count}))

      {:error, step, reason, _} ->
        Logger.error("Failed to purge old keys at step #{inspect(step)}: #{inspect(reason)}")
        send_resp(conn, :bad_request, JSON.encode!(%{status: "error"}))
    end
  end

  # Fallback for unmatched routes
  match _ do
    Logger.error("Received request for unknown route: #{conn.request_path}")
    send_resp(conn, :not_found, "")
  end

  @spec respond_with_signed_jwk(Plug.Conn.t(), map()) :: Plug.Conn.t()
  defp respond_with_signed_jwk(conn, jwk_record) do
    signed_jwk = Keyring.sign(jwk_record)

    conn
    |> put_resp_content_type("application/jose+json")
    |> send_resp(:ok, JSON.encode!(signed_jwk))
  end
end
