defmodule Vaultex.Request do
  def post(url, params, token) do
    HTTPoison.request(:post, url, Poison.Encoder.encode(params, []), [{"X-Vault-Token", token}])
  end

  def get(url, token) do
    HTTPoison.request(:get, url, "", [{"X-Vault-Token", token}])
  end

  def put(url, params, token) do
    HTTPoison.request(:put, url, Poison.Encoder.encode(params, []), [{"X-Vault-Token", token}])
  end

  def delete(url, token) do
    HTTPoison.request(:delete, url, "", [{"X-Vault-Token", token}])
  end

  def handle_response({:ok, response}, state) do
    case response.status_code do
      204 -> {:reply, {:ok}, state}
      _ -> parse_body(response.body, state)
    end
  end

  def handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
    {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  def parse_body(body, state) do
    case body |> Poison.Parser.parse!() do
      %{"data" => nil} -> {:reply, {:ok}, state}
      %{"data" => data} -> {:reply, {:ok, data}, state}
      %{"errors" => []} -> {:reply, {:error, ["Key not found"]}, state}
      %{"errors" => messages} -> {:reply, {:error, messages}, state}
    end
  end
end
