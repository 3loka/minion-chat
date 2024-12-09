# Packer variables (all are required)
region                    = "us-east-1"
dockerhub_id              = "<your-dockerhub-id>"

# Terraform variables (all are required)
ami                       = "ami-03c83c7b2955a1b4b"

name_prefix               = "minion"
response_service_count    = 2