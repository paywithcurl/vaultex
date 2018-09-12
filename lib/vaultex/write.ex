defmodule Vaultex.Write do
  import Vaultex.Request

  def handle(key, value, state = %{token: token}) do
    post(:"#{state.url}#{key}", value, token)
    |> handle_response(state)
  end

  def handle(_key, _value, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end
end
