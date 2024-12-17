provider "aws" {
  region = var.region
}

provider "nomad" {
  address = local.nomad
}

provider "vault" {
  address = "http://${aws_instance.vault.public_ip}:8200"
  token   = local.vault_token
}
