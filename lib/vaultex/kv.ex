defmodule Vaultex.KV do
  import Vaultex.Request

  def handle(:put, key, data, options, state = %{token: token}) do
    post(:"#{state.url}#{key}", %{data: data, options: options}, token)
    |> handle_response(state)
  end

  def handle(:put, _key, _value, _options, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end

  def handle(:get, key, version, state = %{token: token}) do
    url = "#{state.url}#{key}"

    url =
      case version do
        nil -> url
        v -> "#{url}?version=#{v}"
      end

    get(url, token)
    |> handle_response(state)
  end

  def handle(:get, _key, _version, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end
end
