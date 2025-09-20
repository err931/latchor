# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Latchor.Router

  @opts Router.init([])
  @latchor_url "http://127.0.0.1:37564"
  @plaintext "Lorem ipsum"

  describe "Router unit tests" do
    test "GET /health returns ok" do
      conn =
        :get
        |> conn("/health")
        |> Router.call(@opts)

      assert conn.status == 200
    end
  end

  describe "Clevis integration tests" do
    test "encrypt/decrypt round-trip" do
      {encrypted, 0} =
        System.shell(
          ~s(echo "#{@plaintext}" | clevis encrypt tang '{"url":"#{@latchor_url}"}' -y)
        )

      refute encrypted == @plaintext
      assert encrypted != ""

      {decrypted, 0} =
        System.shell(~s(echo -n "#{encrypted}" | clevis decrypt))

      assert String.trim(decrypted) == @plaintext
    end
  end
end
