import Config

config :ecto_sqlite3, :json_library, JSON

config :jose, json_module: :json

config :latchor,
  ecto_repos: [Latchor.Repo]
