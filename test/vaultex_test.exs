defmodule VaultexTest do
  use ExUnit.Case
  doctest Vaultex

  test "Authentication of app_id and user_id is successful" do
    assert Vaultex.Client.auth(:app_id, valid_app_id()) == {:ok, :authenticated}
  end

  test "Authentication of app_id and user_id is unsuccessful" do
    assert Vaultex.Client.auth(:app_id, invalid_app_id()) ==
             {:error, ["invalid user ID or app ID"]}
  end

  test ":userpass authentication with correct password is successful" do
    assert Vaultex.Client.auth(:userpass, valid_userpass()) == {:ok, :authenticated}
  end

  test ":userpass authentication with wrong password is unsuccessful" do
    assert Vaultex.Client.auth(:userpass, invalid_userpass()) ==
             {:error, ["invalid username or password"]}
  end

  test ":token authentication with invalid token is unsuccessful" do
    assert Vaultex.Client.auth(:token, invalid_token()) == {:error, ["permission denied"]}
  end

  test ":token authentication with valid token is successful" do
    assert Vaultex.Client.auth(:token, valid_token()) == {:ok, :authenticated}
  end

  test "Read of valid secret key returns the correct value" do
    assert Vaultex.Client.read("generic/allowed/read/valid", :userpass, valid_userpass()) ==
             {:ok, %{"value" => "bar"}}
  end

  test "Read of non existing secret key returns error" do
    assert Vaultex.Client.read("generic/allowed/read/invalid", :userpass, valid_userpass()) ==
             {:error, ["Key not found"]}
  end

  test "Read of secret not allowed by policy returns error" do
    assert Vaultex.Client.read("generic/forbidden/valid", :userpass, valid_userpass()) ==
             {:error, ["1 error occurred:\n\n* permission denied"]}
  end

  test "Read of existing secret key given bad authentication returns error" do
    assert Vaultex.Client.read("generic/allowed_read", :token, invalid_token()) ==
             {:error, ["permission denied"]}
  end

  test "Write of valid secret key returns the correct value" do
    value = %{"test" => 123, "test2" => 456}

    assert Vaultex.Client.write("generic/allowed/write/valid", value, :userpass, valid_userpass()) ==
             {:ok}

    assert Vaultex.Client.read("generic/allowed/write/valid", :userpass, valid_userpass()) ==
             {:ok, value}
  end

  test "Token renewal" do
    :timer.sleep(1000)
    {renew_token} = valid_token()
    {:ok, before_info} = Vaultex.Client.token_lookup(renew_token, :token, root_token())
    assert before_info["ttl"] < token_ttl()

    assert Vaultex.Client.token_renew(renew_token, :token, root_token()) == {:ok}
    {:ok, after_info} = Vaultex.Client.token_lookup(renew_token, :token, root_token())

    assert before_info["ttl"] < after_info["ttl"]
  end

  test "Token self renewal" do
    :timer.sleep(1000)
    Vaultex.Client.auth(:token, valid_token())

    {:ok, before_info} = Vaultex.Client.token_lookup_self()
    assert before_info["ttl"] < token_ttl()

    assert Vaultex.Client.token_renew_self(:token, valid_token()) == {:ok}

    {:ok, after_info} = Vaultex.Client.token_lookup_self()
    assert before_info["ttl"] < after_info["ttl"]
  end

  test "Token lookup" do
    {token} = valid_token()

    case Vaultex.Client.token_lookup(token, :token, root_token()) do
      {:ok, %{"id" => id}} -> assert id == token
      x -> raise "Unexpected lookup result #{inspect(x)}"
    end
  end

  test "Token self lookup" do
    token = Vaultex.Client.client_token()

    case Vaultex.Client.token_lookup_self(:token, valid_token()) do
      {:ok, %{"id" => id}} -> assert id == token
      x -> raise "Unexpected lookup result #{inspect(x)}"
    end
  end

  test "Token KV put" do
    value = %{"test" => 123, "test2" => 456}

    {:ok, %{"version" => 1}} =
      Vaultex.Client.kv_put(
        "secret/data/allowed/write/valid",
        value,
        %{},
        :userpass,
        valid_userpass()
      )
  end

  test "Token KV get" do
    {:ok, %{"data" => %{"value" => "bar"}, "metadata" => %{"version" => 1}}} =
      Vaultex.Client.kv_get(
        "secret/data/allowed/read/valid",
        nil,
        :userpass,
        valid_userpass()
      )
  end

  test "Token KV versioning" do
    value1 = %{"test" => 123, "test2" => 456}

    {:ok, %{"version" => 1}} =
      Vaultex.Client.kv_put(
        "secret/data/allowed/write/version",
        value1,
        %{},
        :userpass,
        valid_userpass()
      )

    value2 = %{"test" => 123, "test2" => 456}

    {:ok, %{"version" => 2}} =
      Vaultex.Client.kv_put(
        "secret/data/allowed/write/version",
        value2,
        %{},
        :userpass,
        valid_userpass()
      )

    # latest should be version 2
    {:ok, %{"data" => ^value2, "metadata" => %{"version" => 2}}} =
      Vaultex.Client.kv_get(
        "secret/data/allowed/write/version",
        nil,
        :userpass,
        valid_userpass()
      )

    # Get version 1
    {:ok, %{"data" => ^value1, "metadata" => %{"version" => 1}}} =
      Vaultex.Client.kv_get(
        "secret/data/allowed/write/version",
        1,
        :userpass,
        valid_userpass()
      )

    # Get version 2
    {:ok, %{"data" => ^value2, "metadata" => %{"version" => 2}}} =
      Vaultex.Client.kv_get(
        "secret/data/allowed/write/version",
        2,
        :userpass,
        valid_userpass()
      )
  end

  test "Token create" do
    new_token_id = "12345"
    params = %{id: new_token_id, num_uses: 3, ttl: "1h"}

    case Vaultex.Client.token_create(params, :token, root_token()) do
      {:ok, %{"client_token" => id, "lease_duration" => 3600}} -> assert id == new_token_id
      x -> raise "Unexpected lookup result #{inspect(x)}"
    end
  end

  # helpers
  defp valid_userpass do
    {System.get_env("TEST_USER"), System.get_env("TEST_PASSWORD")}
  end

  defp invalid_userpass do
    {System.get_env("TEST_USER"), "wrong"}
  end

  defp invalid_token do
    {"invalid-token"}
  end

  defp valid_token do
    {System.get_env("VAULT_TOKEN")}
  end

  defp root_token do
    {System.get_env("VAULT_ROOT_TOKEN")}
  end

  defp valid_app_id do
    {System.get_env("TEST_APP_ID"), System.get_env("TEST_USER_ID")}
  end

  defp invalid_app_id do
    {"invalid", "invalid"}
  end

  def token_ttl do
    Integer.parse(System.get_env("TOKEN_TTL"))
  end
end
