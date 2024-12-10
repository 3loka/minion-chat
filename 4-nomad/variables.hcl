# Packer variables (all are required)
region                    = "us-east-1"
dockerhub_id              = "<your-dockerhub-id>"

# Terraform variables (all are required)
ami                       = "ami-0e7432c53bd8c771b"

name_prefix               = "minion"
response_service_count    = 2