# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Repo do
  use Ecto.Repo,
    otp_app: :latchor,
    adapter: Ecto.Adapters.SQLite3
end
