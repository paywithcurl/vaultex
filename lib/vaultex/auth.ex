defmodule Vaultex.Auth do
  def handle(:approle, {role_id, secret_id}, state) do
    request(:post, "#{state.url}auth/approle/login", %{role_id: role_id, secret_id: secret_id}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:app_id, {app_id, user_id}, state) do
    request(:post, "#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:userpass, {username, password}, state) do
    request(:post, "#{state.url}auth/userpass/login/#{username}", %{password: password}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:github, {token}, state) do
    request(:post, "#{state.url}auth/github/login", %{token: token}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:token, {token}, state) do
    request(:get, "#{state.url}auth/token/lookup-self", %{}, [{"X-Vault-Token", token}])
    |> handle_response(state)
  end

  def handle(:ec2, {role}, state) do
    pkcs7 = get_aws_pkcs7()
    nonce = get_nonce()
    request(:post, "#{state.url}auth/aws-ec2/login", %{"pkcs7": pkcs7, "nonce": nonce, "role": role}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def get_aws_pkcs7 do
    result = request(:get, "http://169.254.169.254/latest/dynamic/instance-identity/pkcs7")
    case result do
      {:ok, response} -> response.body
    end
  end

  defp handle_response({:ok, response}, state) do
    case response.body |> Poison.Parser.parse! do
      %{"errors" => messages} -> {:reply, {:error, messages}, state}
      %{"data" => data, "auth" => nil} -> {:reply, {:ok, :authenticated}, Map.merge(state, %{token: data["id"]})}
      %{"auth" => properties} -> {:reply, {:ok, :authenticated}, Map.merge(state, %{token: properties["client_token"]})}
    end
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault [#{state.url}]", "#{reason}"]}, state}
  end

  defp request(method, url, params = %{}, headers) do
    HTTPoison.request(method, url, Poison.Encoder.encode(params, []), headers)
  end

  defp request(:get, url) do
    HTTPoison.request(:get, url)
  end

  defp get_nonce do
    System.get_env("VAULT_NONCE") || Application.get_env(:vaultex, :nonce) || ""
  end

end
