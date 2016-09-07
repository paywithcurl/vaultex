defmodule Vaultex.Auth do
  # Is there a better way to get the default HTTPoison value? When this library is consumed by a Client
  # the config files in Vaultex appear to be ignored.
  @httpoison Application.get_env(:vaultex, :httpoison) || HTTPoison

  def handle(:app_id, {app_id, user_id}, state) do
    request(:post, "#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:userpass, {username, password}, state) do
    request(:post, "#{state.url}auth/userpass/login/#{username}", %{password: password}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:token, {token}, state) do
    {:ok, response} = request(:post, "#{state.url}sys/capabilities-self", %{path: "secret/"}, [{"Content-Type", "application/json"}, {"X-Vault-Token", token}])
    case response.status_code do
      200 -> {:reply, {:ok, :authenticated}, Map.merge(state, %{token: token})}
      _-> {:reply, {:error, response.body}, state}
    end
  end

  def handle(:ec2, {role}, state) do
    pkcs7 = get_aws_pkcs7
    nonce = get_nonce
    request(:post, "#{state.url}auth/aws-ec2/login", %{"pkcs7": pkcs7, "nonce": nonce, "role": role}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def get_aws_pkcs7() do
    {:ok, response} = request(:get, "http://169.254.169.254/latest/dynamic/instance-identity/pkcs7")
    case response.status_code do
      200 -> response.body
      _ -> nil
    end
  end

  defp handle_response({:ok, response}, state) do
    IO.puts("handle_response auth")
    IO.inspect(response)
    case response.body |> Poison.Parser.parse! do
      %{"errors" => messages} -> {:reply, {:error, messages}, state}
      %{"auth" => properties} -> {:reply, {:ok, :authenticated}, Map.merge(state, %{token: properties["client_token"]})}
    end
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  defp request(method, url, params = %{}, headers) do
    @httpoison.request(method, url, Poison.Encoder.encode(params, []), headers)
  end

  defp request(:get, url) do
    @httpoison.request(:get, url)
  end


  defp get_nonce() do
    System.get_env("VAULT_NONCE") || Application.get_env(:vaultex, :nonce) || ""
  end

end
