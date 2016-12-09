defmodule Vaultex.Client do
  @moduledoc """
  Provides a functionality to authenticate and read from a vault endpoint.
  The communication relies on :app_id and :user_id variables being set.
  """

  use GenServer
  alias Vaultex.Auth, as: Auth
  alias Vaultex.Read, as: Read
  alias Vaultex.Write, as: Write
  alias Vaultex.TokenRenew, as: TokenRenew
  @version "v1"

  def start_link() do
    GenServer.start_link(__MODULE__, %{progress: "starting"}, name: :vaultex)
  end

  def init(state) do
    addr = get_env(:addr)
    url = case addr do
	    nil -> "#{get_env(:scheme)}://#{get_env(:host)}:#{get_env(:port)}/#{@version}/"
	    _ -> addr
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
    response = read(key)
    case response do
      {:ok, _} -> response
      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
          do: read(key)
    end
  end

  defp read(key) do
    GenServer.call(:vaultex, {:read, key})
  end

  def write(key, value, auth_method, credentials) do
    response = write(key, value)
    case response do
      {:ok} -> response # 204 write has no response
      {:ok, _} -> response
      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
          do: write(key, value)
    end
  end

  defp write(key, value) do
    GenServer.call(:vaultex, {:write, key, value})
  end

  def token_renew(token, auth_method, credentials) do
    response = token_renew(token)
    case response do
      {:ok} -> response
      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
          do: token_renew(token)
    end
  end

  def token_renew(token) do
    GenServer.call(:vaultex, {:tokenrenew, token})
  end

  # callbacks
  def handle_call({:read, key}, _from, state) do
    Read.handle(key, state)
  end

  def handle_call({:write, key, value}, _from, state) do
    Write.handle(key, value, state)
  end

  def handle_call({:auth, method, credentials}, _from, state) do
    Auth.handle(method, credentials, state)
  end

  def handle_call({:tokenrenew, token}, _from, state) do
    TokenRenew.handle(token, state)
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

  defp get_env(:addr) do
      System.get_env("VAULT_ADDR") || Application.get_env(:vaultex, :addr) || nil
  end

end
