#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${retry_join}"


CLOUD_ENV="${cloud_env}"

sed -i "s/RETRY_JOIN/${retry_join}/g" /etc/consul.d/consul.hcl

# for aws only
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /etc/consul.d/consul.hcl
sed -i "s/SERVER_COUNT/${server_count}/g" /etc/consul.d/consul.hcl

sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /etc/nomad.d/nomad.hcl

sudo systemctl restart consul.service
sudo systemctl enable nomad.service
sudo systemctl restart nomad.service

sleep 10

echo "Consul started"

# boundary dev -login-name="dev-admin" -password="p@ssw0rd"
# sudo boundary dev -api-listen-address="0.0.0.0" -cluster-listen-address="0.0.0.0"> boundary_output.log 2>&1 &

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
