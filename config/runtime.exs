import Config

common = %{log_level: :debug, db_path: "/tmp/latchor"}

env_settings = %{
  prod: %{log_level: :info, db_path: "/var/lib/latchor"},
  test: %{log_level: :warning}
}

env = Map.merge(common, Map.get(env_settings, config_env(), %{}))

# Logger settings
config :logger, level: env.log_level

# Database settings
config :latchor, Latchor.Repo,
  database: Path.join(env.db_path, "keyring.db"),
  default_transaction_mode: :immediate,
  synchronous: :full,
  auto_vacuum: :incremental,
  secure_delete: :on
