variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.medium"
}

variable "create_db_secrets" {
  description = "creates db secrets in vault if set to true, make sure vault is deployed before creating these secrets"
  default = false
}

variable "db_secrets" {
  description = "created db secrets in vault if `create_db_secrets` is set to true"
  default = <<EOT
{
  "username":   "kkavish",
  "password": "kkavish@Hashicorp"
}
EOT
}

variable "deploy_apps" {
  description = "deploys HelloService and ResponseService is set to true."
  default = false
}

variable "docker_registry" {
  description = "docker registry where images are hosted"
  default = "docker.io"
}

variable "docker_user" {
  description = "username for docker registry"
}

variable "docker_password" {
  description = "password for docker registry"
}
