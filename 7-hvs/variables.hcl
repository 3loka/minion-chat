# Packer variables (all are required)
region                    = "us-east-1"
dockerhub_id              = "absolutelightning"

# Terraform variables (all are required)
ami                       = "ami-02b8ce7ffa9bc5e15"

name_prefix               = "minion"
response_service_count    = 2

hcp_organization_id = "10e68840-cdc5-4a26-a55a-3a7312cc25ea"
hcp_project_id = "92e138d0-cb39-4e2b-9062-a2204059b78d"