#!/bin/bash
apt-get update -y
apt-get install -y docker.io

# for aws only
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)

sudo mkdir -p /home/ubuntu/
sudo touch /home/ubuntu/pki-worker.hcl
sudo tee /home/ubuntu/pki-worker.hcl <<EOF
hcp_boundary_cluster_id = "${boundary_cluster_id}"

listener "tcp" {
    address = "0.0.0.0:9202"
    purpose = "proxy"
}
        
worker {
    public_addr = "$PUBLIC_IP"
    auth_storage_path = "/home/ubuntu/worker1"
    tags {
    type = ["dev"]
    }
}
EOF

echo "Boundary setup started"
# sudo apt-get update && sudo apt-get -y install boundary
# # start boundary worker
# sudo boundary server -config="/home/ubuntu/pki-worker.hcl" > boundary_output.log 2>&1 &

cd /home/ubuntu/
sudo apt-get update -y && sudo apt-get install -y jq unzip
wget -q "$(curl -fsSL "https://api.releases.hashicorp.com/v1/releases/boundary/latest?license_class=enterprise" | jq -r '.builds[] | select(.arch == "amd64" and .os == "linux") | .url')"
unzip -o *.zip
echo "Boundary setup completed"

echo "Starting boundary server"
sudo ./boundary server -config="/home/ubuntu/pki-worker.hcl" > boundary_output.log 2>&1 &
echo "Boundary server started"