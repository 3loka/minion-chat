variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.medium"
}

variable "name_prefix" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "minion-vault"
}

variable "create_db_secrets" {
  description = "creates db secrets in vault if set to true, make sure vault is deployed before creating these secrets"
  default = false
}

variable "db_secrets" {
  description = "created db secrets in vault if `create_db_secrets` is set to true"
  default = <<EOT
{
  "username":   "kkavish.hashicorp",
  "password": "kkavish is busy having fun at Goa Offsite"
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

variable "ami" {
  description = "ami to use for deployment"
  default = "ami-0bbedcb6360a12dbb"
}

variable "retry_join" {
  description = "Used by Consul to automatically form a cluster."
  type        = string
  default     = "provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"
}

variable "response_service_count" {
  description = "Number of response service instances to create"
  default     = 2
}
