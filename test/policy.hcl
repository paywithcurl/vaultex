path "auth/token/renew/*" {
    policy = "write"
}

path "secret/allowed/read/*" {
  policy = "read"
}

path "secret/allowed/write/*" {
  policy = "write"
}
