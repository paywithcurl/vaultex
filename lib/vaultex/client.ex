defmodule Vaultex.Client do
  @moduledoc """
  Provides a functionality to authenticate and read from a vault endpoint.
  The communication relies on :app_id and :user_id variables being set.
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
    addr = get_env(:addr)

    url =
      case addr do
        nil -> "#{get_env(:scheme)}://#{get_env(:host)}:#{get_env(:port)}"
        _ -> "#{addr}"
      end

    # add the version to the path
    suffix = "#{@version}/"

    url =
      case String.ends_with?(url, [suffix]) do
        true -> url
        false -> "#{url}/#{suffix}"
      end

    {:ok, Map.merge(state, %{url: url})}
  end

  @doc """
   Authenticates with vault using an {app_id, user_id} tuple. This must be executed before attempting to read secrets from vault.

   ## Parameters

     - method: Auth backend to use for authenticating, can be one of [:app_id, :userpass]
     - credentials: An {app_id, user_id} tuple used for authentication

   ## Examples

     iex> Vaultex.Client.auth(:app_id, {app_id, user_id})
     {:ok, :authenticated}

     iex> Vaultex.Client.auth(:userpass, {username, password})
     {:error, ["Something didn't work"]}
  """
  def auth(method, credentials) do
    GenServer.call(:vaultex, {:auth, method, credentials})
  end

  @doc """
  Reads a secret from vault given a path.

  ## Parameters

    - key: A String path to be used for querying vault.
    - auth_method: Auth backend to use for authenticating, can be one of [:app_id, :userpass]
    - credentials: An {app_id, user_id} tuple used for authentication

  ## Examples

    iex> Vaultex.Client.read "secret/foo", :app_id, {app_id, user_id}
    {:ok, %{"value" => bar"}}

    iex> Vaultex.Client.read "secret/baz", :userpass, {username, password}
    {:error, ["Key not found"]}
  """
  def read(key, auth_method, credentials) do
    wrap_retry_with_auth(fn -> read(key) end, auth_method, credentials)
  end

  def read(key) do
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

  def delete(key) do
    GenServer.call(:vaultex, {:delete, key})
  end

  @doc """
  Writes a secret to vault given a path.

  ## Parameters

    - key: A String path to be used for querying vault.
    - value: A Map of values to store
    - auth_method: Auth backend to use for authenticating, can be one of [:app_id, :userpass]
    - credentials: An {app_id, user_id} tuple used for authentication

  ## Examples

    iex> Vaultex.Client.write "secret/foo", %{"test" => 123}, :app_id, {app_id, user_id}
    {:ok}
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
    {:ok}
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

  def token_create(params, auth_method, credentials) do
    wrap_retry_with_auth(fn -> token_create(params) end, auth_method, credentials)
  end

  def token_create(params) do
    GenServer.call(:vaultex, {:tokencreate, params})
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

  def handle_call({:tokencreate, params}, _from, state) do
    Token.handle(:create, params, state)
  end

  def handle_call({:gettoken}, _from, state) do
    case state do
      %{token: x} -> {:reply, x, state}
      %{} -> {:reply, nil, state}
    end
  end

  # environment
  defp get_env(:host) do
    System.get_env("VAULT_HOST") || Application.get_env(:vaultex, :host) || "localhost"
  end

  defp get_env(:port) do
    System.get_env("VAULT_PORT") || Application.get_env(:vaultex, :port) || 8200
  end

  defp get_env(:scheme) do
    System.get_env("VAULT_SCHEME") || Application.get_env(:vaultex, :scheme) || "http"
  end

  defp get_env(:addr) do
    System.get_env("VAULT_ADDR") || Application.get_env(:vaultex, :addr) || nil
  end

  # helpers
  defp wrap_retry_with_auth(cb, auth_method, credentials) do
    response = cb.()

    case response do
      {:ok} ->
        response

      {:ok, _} ->
        response

      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
             do: cb.()
    end
  end
end
