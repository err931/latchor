# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Keyring.SchemaTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias Latchor.Keyring.Schema

  @curve :secp521r1

  setup do
    sig_jwk = JOSE.JWK.generate_key(@curve)
    derive_jwk = JOSE.JWK.generate_key(@curve)
    %{sig_jwk: sig_jwk, derive_jwk: derive_jwk}
  end

  describe "changeset/2 with valid params" do
    test "produces a valid changeset and converts JWKs to maps", %{
      sig_jwk: sig_jwk,
      derive_jwk: derive_jwk
    } do
      changeset = Schema.changeset(%Schema{}, %{sig_jwk: sig_jwk, derive_jwk: derive_jwk})

      assert %{valid?: true} = changeset
      assert get_change(changeset, :sig_kid) == JOSE.JWK.thumbprint(sig_jwk)
      assert get_change(changeset, :derive_kid) == JOSE.JWK.thumbprint(derive_jwk)

      assert is_map(get_change(changeset, :sig_jwk))
      assert is_map(get_change(changeset, :derive_jwk))
    end
  end

  describe "changeset/2 with invalid sig_jwk" do
    test "is invalid when missing", %{derive_jwk: derive_jwk} do
      changeset = Schema.changeset(%Schema{}, %{derive_jwk: derive_jwk})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :sig_jwk)
    end

    test "is invalid when not a JOSE.JWK struct", %{derive_jwk: derive_jwk} do
      changeset = Schema.changeset(%Schema{}, %{sig_jwk: %{}, derive_jwk: derive_jwk})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :sig_jwk)
    end
  end

  describe "changeset/2 with invalid derive_jwk" do
    test "is invalid when missing", %{sig_jwk: sig_jwk} do
      changeset = Schema.changeset(%Schema{}, %{sig_jwk: sig_jwk})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :derive_jwk)
    end

    test "is invalid when not a JOSE.JWK struct", %{sig_jwk: sig_jwk} do
      changeset =
        Schema.changeset(%Schema{}, %{sig_jwk: sig_jwk, derive_jwk: %{"alg" => "ES512"}})

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :derive_jwk)
    end
  end
end
