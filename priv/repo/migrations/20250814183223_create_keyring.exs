defmodule Latchor.Repo.Migrations.CreateKeyring do
  use Ecto.Migration

  def change do
    create table(:keyring) do
      add(:sig_jwk, :text, null: false)
      add(:derive_jwk, :text, null: false)
      add(:sig_kid, :string, null: false)
      add(:derive_kid, :string, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false, null: false)
    end

    create(unique_index(:keyring, [:sig_kid]))
    create(unique_index(:keyring, [:derive_kid]))
    create(index(:keyring, [:inserted_at]))
  end
end
