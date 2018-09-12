path "auth/token/renew/*" {
    policy = "write"
}

path "auth/token/create" {
    policy = "write"
}

path "generic/allowed/read/*" {
  policy = "read"
}

path "generic/allowed/write/*" {
  policy = "write"
}

path "secret/data/allowed/read/*" {
  policy = "read"
}

path "/secret/data/allowed/write/*" {
  policy = "write"
}
