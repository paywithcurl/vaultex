# Vaultex

Client for [Vault](https://www.vaultproject.io/)

## Installation

The package can be installed as:

  1. Add vaultex to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:vaultex, "~> 0.2.0"}]
end
```
  2. Ensure vaultex is started before your application:

```elixir
def application do
  [applications: [:vaultex]]
end
```
## Configuration

The vault endpoint can be specified with environment variables:

* `VAUL_ADDR`
* Or a specify individual parts of the url
  * `VAULT_HOST`
  * `VAULT_PORT`
  * `VAULT_SCHEME`

Or application variables:

* `:vaultex, :host`
* `:vaultex, :port`
* `:vaultex, :scheme`

These default to `localhost`, `8200`, `http` respectively.

## Usage

To read a secret you must provide the path to the secret and the authentication backend and credentials you will use to login. See the Vaultex.Client.auth/2 docs for supported auth backends.

```elixir
...
Vault.read("secret/foo", :userpass, {username, password}) #returns {:ok, %{"value" => bar"}}
```

## Supported operations

### Authentication

The following authentication methods are supported

* [:app_id](https://www.vaultproject.io/docs/auth/app-id.html) `{app_id, role_id}`
* [:token](https://www.vaultproject.io/docs/auth/token.html) `{token}`
* [:userpass](https://www.vaultproject.io/docs/auth/userpass.html) `{user, pass}`
* [:ec2](https://www.vaultproject.io/docs/auth/aws-ec2.html) `{role}` You need to also configure the vault nonce via `VAULT_NONCE` or the `:vaultex, :nonce` config.

### Operations

```
Vaultex.Client.read("secret/key", auth_method, auth_options)
Vaultex.Client.read("secret/key", :userpass, {"username", "password"})
```

```
Vaultex.Client.write("secret/key", value, auth_method, auth_options)
Vaultex.Client.write("secret/key", %{"test" => 123}, :token, {"1234-5678"})
```

## Running the tests

Install the required dependencies

* [docker](https://docs.docker.com/engine/installation/).
* [jq](https://stedolan.github.io/jq/download/)

Run the tests
```
./run_tests.sh
```
