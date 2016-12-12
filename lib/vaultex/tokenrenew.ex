defmodule Vaultex.TokenRenew do

  import Vaultex.Request

  def handle(token, %{token: token} = state) do
    post("#{state.url}auth/token/renew/#{token}", %{}, token)
    |> handle_response(state)
  end

  def handle(_key, %{} = state) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end

end
