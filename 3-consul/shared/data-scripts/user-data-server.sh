#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${server_count}" "${retry_join}"


CLOUD_ENV="${cloud_env}"

sed -i "s/RETRY_JOIN/${retry_join}/g" /etc/consul.d/consul.hcl

# for aws only
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /etc/consul.d/consul.hcl
sed -i "s/SERVER_COUNT/${server_count}/g" /etc/consul.d/consul.hcl

sudo systemctl restart consul.service

wait 10

echo "Consul started"


