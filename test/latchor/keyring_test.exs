# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.KeyringTest do
  use ExUnit.Case

  alias Latchor.Keyring
  alias Latchor.Keyring.Schema
  alias Latchor.Repo

  @curve :secp521r1

  setup do
    Repo.delete_all(Schema)
    :ok
  end

  describe "fetch/0" do
    test "When no record exists in DB, generate and return a new key" do
      # Check DB is empty
      assert Repo.all(Schema) == []
      schema = Keyring.fetch()

      # Check result is Schema struct
      assert %Schema{} = schema

      # Check sig_jwk is a map
      assert is_map(schema.sig_jwk)

      # Check derive_jwk is a map
      assert is_map(schema.derive_jwk)

      # Check one record is saved
      assert Repo.aggregate(Schema, :count) == 1
    end

    test "When a record exists in DB, return the existing key" do
      created = Keyring.create_new_keys!()
      fetched = Keyring.fetch()

      # Check sig_jwk matches created
      assert fetched.sig_jwk == created.sig_jwk

      # Check derive_jwk matches created
      assert fetched.derive_jwk == created.derive_jwk
    end
  end

  describe "fetch/1" do
    setup do
      schema = Keyring.create_new_keys!()
      %{sig_kid: schema.sig_kid}
    end

    test "When given an existing sig_kid, return the matching key", %{sig_kid: sig_kid} do
      # Check sig_kid is a string
      assert is_binary(sig_kid)
      schema = Keyring.fetch(sig_kid)

      # Check result is Schema struct
      assert %Schema{} = schema

      # Check sig_jwk is a map
      assert is_map(schema.sig_jwk)

      # Check derive_jwk is a map
      assert is_map(schema.derive_jwk)
    end

    test "When given a non-existent sig_kid, return nil" do
      # Check nil is returned for unknown sig_kid
      assert Keyring.fetch("non-existent-kid") == nil
    end

    test "When sig_kid is nil, raise FunctionClauseError" do
      # Check error is raised for nil sig_kid
      assert_raise FunctionClauseError, fn ->
        Keyring.fetch(nil)
      end
    end
  end

  describe "fetch_derive_jwk/1" do
    setup do
      schema = Keyring.create_new_keys!()
      %{derive_kid: schema.derive_kid}
    end

    test "When given an existing derive_kid, return the JWK", %{derive_kid: derive_kid} do
      # Check derive_kid is a string
      assert is_binary(derive_kid)
      jwk = Keyring.fetch_derive_jwk(derive_kid)

      # Check JWK is a map
      assert is_map(jwk)
    end

    test "When given a non-existent derive_kid, return nil" do
      # Check nil is returned for unknown derive_kid
      assert Keyring.fetch_derive_jwk("non-existent-kid") == nil
    end

    test "When derive_kid is nil, raise FunctionClauseError" do
      # Check error is raised for nil derive_kid
      assert_raise FunctionClauseError, fn ->
        Keyring.fetch_derive_jwk(nil)
      end
    end
  end

  describe "sign/1" do
    setup do
      schema = Keyring.create_new_keys!()
      %{schema: schema}
    end

    test "Return a valid JWS structure that passes signature verification", %{schema: schema} do
      jws_map = Keyring.sign(schema)

      # Check JWS has protected, payload, and signature
      assert %{"protected" => _, "payload" => _, "signature" => _} = jws_map
      sig_jwk = JOSE.JWK.from_map(schema.sig_jwk)

      {verified, decoded_payload, _jws} =
        JOSE.JWS.verify(sig_jwk, jws_map)

      # Check signature is valid
      assert verified

      # Check payload is JSON with "keys"
      assert {:ok, %{"keys" => keys}} = JSON.decode(decoded_payload)

      # Check two keys are present
      assert length(keys) == 2
    end

    test "Raise an error when given an incomplete Schema" do
      bad_schema = %Schema{sig_jwk: nil, derive_jwk: nil}

      # Check error is raised for bad schema
      assert_raise FunctionClauseError, fn ->
        Keyring.sign(bad_schema)
      end
    end
  end

  describe "validate/1" do
    test "Return a valid changeset for a valid JWK" do
      {_, jwk} =
        @curve
        |> JOSE.JWK.generate_key()
        |> JOSE.JWK.to_map()

      changeset = Keyring.validate(jwk)

      # Check changeset is valid
      assert changeset.valid?
    end

    test "Return an invalid changeset for an invalid JWK" do
      invalid_jwk = %{"kty" => "EC"}
      changeset = Keyring.validate(invalid_jwk)

      # Check changeset is invalid
      refute changeset.valid?
    end

    test "Return an invalid changeset for an empty map" do
      changeset = Keyring.validate(%{})

      # Check changeset is invalid
      refute changeset.valid?
    end
  end

  describe "create_new_keys!/0" do
    test "Save a new key to the DB" do
      count_before = Repo.aggregate(Schema, :count)
      schema = Keyring.create_new_keys!()
      count_after = Repo.aggregate(Schema, :count)

      # Check count increased by one
      assert count_after == count_before + 1

      # Check sig_jwk is a map
      assert is_map(schema.sig_jwk)

      # Check derive_jwk is a map
      assert is_map(schema.derive_jwk)
    end
  end

  describe "delete_old_keys/0" do
    test "Delete keys older than the retention period" do
      Enum.each(1..5, fn _ -> Keyring.create_new_keys!() end)
      count_before = Repo.aggregate(Schema, :count)

      # Check we created 5 keys
      assert count_before == 5

      Keyring.delete_old_keys()
      count_after = Repo.aggregate(Schema, :count)

      # Check only newest key remains
      assert count_after == 1
    end

    test "Do nothing when there are no old keys" do
      Keyring.create_new_keys!()
      count_before = Repo.aggregate(Schema, :count)

      Keyring.delete_old_keys()
      count_after = Repo.aggregate(Schema, :count)

      # Check count did not change
      assert count_after == count_before
    end
  end
end
