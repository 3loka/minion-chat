# Packer variables (all are required)
region                    = "us-east-1"
dockerhub_id              = "srahul3"

# Terraform variables (all are required)
ami                       = "ami-0ffbc549471967a80"

name_prefix               = "minion"
response_service_count    = 2

boundary_url              = "https://555c2085-9f56-478c-9196-7da82effec92.boundary.hashicorp.cloud"
boundary_cluster_id       = "555c2085-9f56-478c-9196-7da82effec92"