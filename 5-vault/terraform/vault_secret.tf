provider "vault" {
  address = "http://${aws_instance.vault.public_ip}:8200"
  token = "root"
}

resource "vault_generic_secret" "example" {
  count = var.create_db_secrets ? 1 : 0

  path = "secret/database/creds/my-role"

  data_json = var.db_secrets
}
