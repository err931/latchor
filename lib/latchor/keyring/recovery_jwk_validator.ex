# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Keyring.RecoveryJWKValidator do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @allow_kty ["EC"]
  @allow_alg ["ECMR"]
  @allow_key_ops ["deriveKey"]

  @primary_key false
  embedded_schema do
    field(:alg, :string)
    field(:crv, :string)
    field(:key_ops, {:array, :string})
    field(:kty, :string)
    field(:x, :string)
    field(:y, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, __schema__(:fields))
    |> validate_required([:crv, :kty, :x, :y])
    |> validate_inclusion(:alg, @allow_alg)
    |> validate_inclusion(:kty, @allow_kty)
    |> validate_subset(:key_ops, @allow_key_ops)
  end
end
