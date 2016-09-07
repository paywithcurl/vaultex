defmodule Vaultex.Write do
  # Is there a better way to get the default HTTPoison value? When this library is consumed by a Client
  # the config files in Vaultex appear to be ignored.
  @httpoison Application.get_env(:vaultex, :httpoison) || HTTPoison

  def handle(key, value, state = %{token: token}) do
    request(:put, "#{state.url}#{key}", value, [{"X-Vault-Token", token}])
    |> handle_response(state)
  end

  def handle(_key, _value, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end

  defp handle_response({:ok, response}, state) do
    IO.puts("handle_response write")
    IO.inspect(response)
    case response do
      %{status_code: 204} -> {:reply, {:ok}, state}
      _ -> {:reply, {:error, response.body |> Poison.Parser.parse! |> Map.fetch("errors")}, state}
    end
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  defp request(method, url, params = %{}, headers) do
    @httpoison.request(method, url, Poison.Encoder.encode(params, []), headers)
  end
end
