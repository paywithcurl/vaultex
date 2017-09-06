defmodule Vaultex.Client do
  @moduledoc """
  Provides a functionality to authenticate and read from a vault endpoint.
  """

  use GenServer
  alias Vaultex.Auth, as: Auth
  alias Vaultex.Read, as: Read
  alias Vaultex.Delete, as: Delete
  alias Vaultex.Write, as: Write
  alias Vaultex.Token, as: Token
  @version "v1"

  def start_link() do
    GenServer.start_link(__MODULE__, %{progress: "starting"}, name: :vaultex)
  end

  def init(state) do
    {:ok, Map.merge(state, %{url: url()})}
  end

  @doc """
  Authenticates with vault using a tuple. This can be executed before attempting to read secrets from vault.

  ## Parameters

    - method: Auth backend to use for authenticating, can be one of `:approle, :app_id, :userpass, :github`
    - credentials: A tuple used for authentication depending on the method, `{role_id, secret_id}` for :approle, `{app_id, user_id}` for `:app_id`, `{username, password}` for `:userpass`, `{github_token}` for `:github`

  ## Examples

    ```
    iex> Vaultex.Client.auth(:app_id, {app_id, user_id})
    {:ok, :authenticated}

    iex> Vaultex.Client.auth(:userpass, {username, password})
    {:error, ["Something didn't work"]}

    iex> Vaultex.Client.auth(:github, {github_token})
    {:ok, :authenticated}
    ```
  """
  def auth(method, credentials) do
    GenServer.call(:vaultex, {:auth, method, credentials})
  end

  @doc """
  Reads a secret from vault given a path.

  ## Parameters

    - key: A String path to be used for querying vault.
    - auth_method and credentials: See Vaultex.Client.auth

  ## Examples

    ```
    iex> Vaultex.Client.read "secret/foo", :app_id, {app_id, user_id}
    {:ok, %{"value" => "bar"}}

    iex> Vaultex.Client.read "secret/baz", :userpass, {username, password}
    {:error, ["Key not found"]}

    iex> Vaultex.Client.read "secret/bar", :github, {github_token}
    {:ok, %{"value" => "bar"}}
    ```

  """
  def read(key, auth_method, credentials) do
    wrap_retry_with_auth(fn -> read(key) end, auth_method, credentials)
  end

  defp read(key) do
    GenServer.call(:vaultex, {:read, key})
  end

  @doc """
  Delete a secret from vault given a path.

  ## Parameters

    - key: A String path to be used for querying vault.
    - auth_method: Auth backend to use for authenticating, can be one of [:app_id, :userpass]
    - credentials: An {app_id, user_id} tuple used for authentication

  ## Examples

    iex> Vaultex.Client.delete "secret/foo", :app_id, {app_id, user_id}
    {:ok, %{"value" => bar"}}

    iex> Vaultex.Client.delete "secret/baz", :userpass, {username, password}
    {:error, ["Key not found"]}
  """
  def delete(key, auth_method, credentials) do
    wrap_retry_with_auth(fn -> delete(key) end, auth_method, credentials)
  end

  defp delete(key) do
    GenServer.call(:vaultex, {:delete, key})
  end

  @doc """
  Writes a secret to Vault given a path.

  ## Parameters

    - key: A String path where the secret will be written.
    - value: A String => String map that will be stored in Vault
    - auth_method and credentials: See Vaultex.Client.auth

  ## Examples

    ```
    iex> Vaultex.Client.write "secret/foo", %{"value" => "bar"}, :app_id, {app_id, user_id}
    :ok
    ```
  """
  def write(key, value, auth_method, credentials) do
    wrap_retry_with_auth(fn -> write(key, value) end, auth_method, credentials)
  end

  def write(key, value) do
    GenServer.call(:vaultex, {:write, key, value})
  end

  def client_token do
    GenServer.call(:vaultex, {:gettoken})
  end

  @doc """
  Renews a token.

  ## Parameters

    - token: A String token to be renewed. It needs to be a renewable token or it will return an error.
    - auth_method: Auth backend to use for authenticating, can be one of [:app_id, :userpass]
    - credentials: An {app_id, user_id} tuple used for authentication

  ## Examples

    iex> Vaultex.Client.token_renw "123-456", :app_id, {app_id, user_id}
    :ok
  """
  def token_renew(token, auth_method, credentials) do
    wrap_retry_with_auth(fn -> token_renew(token) end, auth_method, credentials)
  end

  def token_renew(token) do
    GenServer.call(:vaultex, {:tokenrenew, token})
  end

  def token_renew_self(auth_method, credentials) do
    wrap_retry_with_auth(fn -> token_renew_self() end, auth_method, credentials)
  end

  def token_renew_self() do
    GenServer.call(:vaultex, {:tokenrenewself})
  end

  def token_lookup(token, auth_method, credentials) do
    wrap_retry_with_auth(fn -> token_lookup(token) end, auth_method, credentials)
  end

  def token_lookup(token) do
    GenServer.call(:vaultex, {:tokenlookup, token})
  end

  def token_lookup_self(auth_method, credentials) do
    wrap_retry_with_auth(fn -> token_lookup_self() end, auth_method, credentials)
  end

  def token_lookup_self() do
    GenServer.call(:vaultex, {:tokenlookupself})
  end

  # callbacks
  def handle_call({:read, key}, _from, state) do
    Read.handle(key, state)
  end

  def handle_call({:delete, key}, _from, state) do
    Delete.handle(key, state)
  end

  def handle_call({:write, key, value}, _from, state) do
    Write.handle(key, value, state)
  end

  def handle_call({:auth, method, credentials}, _from, state) do
    Auth.handle(method, credentials, state)
  end

  def handle_call({:tokenrenew, token}, _from, state) do
    Token.handle(:renew, token, state)
  end

  def handle_call({:tokenrenewself}, _from, state) do
    Token.handle(:renewself, nil, state)
  end

  def handle_call({:tokenlookup, token}, _from, state) do
    Token.handle(:lookup, token, state)
  end

  def handle_call({:tokenlookupself}, _from, state) do
    Token.handle(:lookupself, nil, state)
  end

  def handle_call({:gettoken}, _from, state) do
    case state do
      %{token: x} -> {:reply, x, state}
      %{} -> {:reply, nil, state}
    end
  end

  # environment

  defp url do
    "#{scheme()}://#{host()}:#{port()}/#{@version}/"
  end

  defp host do
    parsed_vault_addr().host || get_env(:host)
  end

  defp port do
    parsed_vault_addr().port || get_env(:port)
  end

  defp scheme do
    parsed_vault_addr().scheme || get_env(:scheme)
  end

  defp parsed_vault_addr do
    get_env(:vault_addr) |> to_string |> URI.parse
  end

  defp get_env(:host) do
    System.get_env("VAULT_HOST") || Application.get_env(:vaultex, :host) || "localhost"
  end

  defp get_env(:port) do
      System.get_env("VAULT_PORT") || Application.get_env(:vaultex, :port) || 8200
  end

  defp get_env(:scheme) do
      System.get_env("VAULT_SCHEME") || Application.get_env(:vaultex, :scheme) || "http"
  end

  defp get_env(:vault_addr) do
    System.get_env("VAULT_ADDR") || Application.get_env(:vaultex, :vault_addr)
  end

  # helpers
  defp wrap_retry_with_auth(cb, auth_method, credentials) do
    response = cb.()
    case response do
      :ok -> response
      {:ok, _} -> response
      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
          do: cb.()
    end
  end
end
