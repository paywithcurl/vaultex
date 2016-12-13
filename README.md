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

Each operation has 2 interfaces, with and without auth information. The ones taking auth information
will try to do the operation and authenticate and retry on failure. The others assume the client is
already authenticated.

#### Read

```
Vaultex.Client.read(path, auth_method, auth_options)
Vaultex.Client.read(path)
```

```
Vaultex.Client.read(path, :userpass, {"username", "password"})
Vaultex.Client.read(path)
```

#### Write
```
Vaultex.Client.write(path, value, auth_method, auth_options)
Vaultex.Client.write(path, value)
```

```
Vaultex.Client.write(path, %{"test" => 123}, :token, {"1234-5678"})
Vaultex.Client.write(path, %{"test" => 123})
```

#### Token lookup
```
Vaultex.Client.token_lookup(token, auth_method, auth_options)
Vaultex.Client.token_lookup(token)
```

#### Token self lookup
```
Vaultex.Client.token_lookup_self(auth_method, auth_options)
Vaultex.Client.token_lookup_self()
```

#### Token renew

```
Vaultex.Client.token_renew(token, auth_method, auth_options)
Vaultex.Client.token_renew(token)
```

#### Token self renew
```
Vaultex.Client.token_renew_self(auth_method, auth_options)
Vaultex.Client.token_renew_self()
```

#### Get the token used by Vaultex

```
Vaultex.Client.client_token
```

## Running the tests

Install the required dependencies

* [docker](https://docs.docker.com/engine/installation/).
* [jq](https://stedolan.github.io/jq/download/)

Run the tests
```
./run_tests.sh
```
