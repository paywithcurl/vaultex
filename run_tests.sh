#!/usr/bin/env bash

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_ROOT_TOKEN=46eaf643-283a-6af9-4c9a-836914d1f7a6

# start vault dev server
docker run --name vaultex-vault -e VAULT_DEV_ROOT_TOKEN_ID=${VAULT_ROOT_TOKEN} -p 8200:8200 -d vault
export VAULT_TOKEN=${VAULT_ROOT_TOKEN}

# Prepare vault setup for tests

## Policy
# try again if it fails as vault takes some time to be up
while true; do
    vault policy-write test-policy test/policy.hcl
    if [ $? -eq 0 ]; then
	break
    fi
    sleep 0.5
done

## Add data
vault write secret/allowed/read/valid value=bar
vault write secret/forbidden/read/valid value=flip

## Setup user pass auth
export TEST_USER=twist
export TEST_PASSWORD=nuggy

vault auth-enable userpass
vault write auth/userpass/users/${TEST_USER} \
    password=${TEST_PASSWORD} \
    policies=test-policy

## Setup app-id auth
vault auth-enable app-id
vault write auth/app-id/map/app-id/valid-app-id value=test-policy
vault write auth/app-id/map/user-id/valid-user-id value=valid-app-id
export TEST_APP_ID=valid-app-id
export TEST_USER_ID=valid-user-id


## Setup token auth
vault write auth/token/roles/test_role period="1h" allowed_policies=test-policy
export VAULT_TOKEN=`vault token-create -format=json -role test_role | jq -r ".auth.client_token"`


## Run the tests
mix test

docker rm -f vaultex-vault
