resource "nomad_job" "hello_service" {
  count = var.deploy_apps ? 1 : 0

  jobspec = templatefile("${path.module}/nomad-jobs/hello-service.nomad", {
    consul_server      = local.consul
    vault_addr         = "http://${aws_instance.vault.public_ip}:8200"
    vault_token        = local.vault_token
    image              = "kkavish/hello_service:latest"
    dockerhub_user     = var.docker_user
    dockerhub_password = var.docker_password
  })
}

resource "vault_policy" "db_access" {
  depends_on = [time_sleep.wait_90_seconds]

  name = "db-access-policy"

  policy = <<EOT
path "database/creds/app-role" {
  capabilities = ["read"]
}
EOT
}

resource "nomad_job" "response_service" {
  count = var.deploy_apps ? 1 : 0

  jobspec = templatefile("${path.module}/nomad-jobs/response-service.nomad", {
    consul_server      = local.consul
    vault_policy       = vault_policy.db_access.name
    image              = "kkavish/response_service:latest"
    dockerhub_user     = var.docker_user
    dockerhub_password = var.docker_password
  })
}
