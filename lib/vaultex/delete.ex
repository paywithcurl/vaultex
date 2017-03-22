defmodule Vaultex.Delete do

  import Vaultex.Request

  def handle(key, state = %{token: token}) do
    delete("#{state.url}#{key}", token)
    |> handle_response(state)
  end

  def handle(_key, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end

end
