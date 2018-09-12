defmodule Vaultex.TokenRenewer do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, state}
  end

  def renew_token(token, period) do
    GenServer.call(__MODULE__, {:renew, token, period})
  end

  # callbacks
  def handle_call({:renew, token, period}, _from, _state) do
    vault_renew_token(token)
    schedule_work(period)
    {:reply, :ok, {token, period}}
  end

  defp vault_renew_token(token) do
    response = Vaultex.Client.token_renew(token)

    case response do
      {:ok} -> Logger.info("Token renewed")
      {:error, error} -> Logger.error("Token renewal failed #{inspect(error)}")
    end

    response
  end

  def handle_info(:renew, {token, period} = state) do
    vault_renew_token(token)
    schedule_work(period)
    {:noreply, state}
  end

  defp schedule_work(period) do
    Process.send_after(self(), :renew, period)
  end
end
