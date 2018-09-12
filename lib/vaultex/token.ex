defmodule Vaultex.Token do
  import Vaultex.Request

  def handle(:renew, renew_token, %{token: token} = state) do
    post("#{state.url}auth/token/renew/#{renew_token}", %{}, token)
    |> handle_response(state)
  end

  def handle(:renewself, _, %{token: token} = state) do
    post("#{state.url}auth/token/renew-self", %{}, token)
    |> handle_response(state)
  end

  def handle(:lookup, lookup_token, %{token: token} = state) do
    get("#{state.url}auth/token/lookup/#{lookup_token}", token)
    |> handle_response(state)
  end

  def handle(:lookupself, _, %{token: token} = state) do
    get("#{state.url}auth/token/lookup-self", token)
    |> handle_response(state)
  end

  def handle(_action, _key, %{} = state) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end
end
