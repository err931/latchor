# SPDX-FileCopyrightText: 2025 Minoru Maekawa
#
# SPDX-License-Identifier: EUPL-1.2

defmodule Latchor.Keyring.KeyExchange do
  @moduledoc """
  Handles Tang-compatible key exchange using the `jose` CLI.
  """

  @timeout 5000

  @doc """
  Executes a key exchange between server and client JWK maps.
  Returns the derived shared secret.
  """
  @spec exchange(map(), map()) :: binary()
  def exchange(server_jwk_map, client_jwk_map) do
    [server_jwk_map, client_jwk_map]
    |> Enum.map_join("\n", &JSON.encode!/1)
    |> run_jose_cli()
  end

  @spec run_jose_cli(binary()) :: binary()
  defp run_jose_cli(exchange_keys) when is_binary(exchange_keys) do
    port =
      Port.open({:spawn_executable, System.find_executable("jose")}, [
        :binary,
        args: ["jwk", "exc", "-l", "-", "-r", "-"]
      ])

    ref = Port.monitor(port)
    Port.command(port, exchange_keys)

    collect_stdout(port, ref, "")
  end

  defp collect_stdout(port, ref, acc) do
    receive do
      {^port, {:data, chunk}} ->
        collect_stdout(port, ref, acc <> chunk)

      {:DOWN, ^ref, :port, ^port, :normal} ->
        acc

      {:DOWN, ^ref, :port, ^port, reason} ->
        raise "jose jwk exc failed: #{inspect(reason)}"
    after
      @timeout ->
        Port.close(port)
        Port.demonitor(ref, [:flush])
        raise "jose jwk exc timed out"
    end
  end
end
