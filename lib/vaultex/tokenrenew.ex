defmodule Vaultex.TokenRenew do

  def handle(token, %{token: token} = state) do
    request(:post, "#{state.url}auth/token/renew/#{token}", [{"X-Vault-Token", token}])
    |> handle_response(state)
  end

  def handle(_key, %{} = state) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end

  defp handle_response({:ok, response}, state) do
    case response do
      %{status_code: 200} -> {:reply, {:ok}, state}
      _ -> {:reply, {:error, response.body |> Poison.Parser.parse! |> Map.fetch("errors")}, state}
    end
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  defp request(method, url, headers) do
    HTTPoison.request(method, url, "", headers)
  end
end
