#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/client.sh "${cloud_env}" "${retry_join}"

NOMAD_HCL_PATH="/etc/nomad.d/nomad.hcl"
CLOUD_ENV="${cloud_env}"
CONSULCONFIGDIR=/etc/consul.d

# wait for consul to start
sleep 10

PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/instance-id)

# starting the application
if [ "${application_name}" = "hello-service" ]; then
  sudo docker run -d --name ${application_name} --network=host -e RESPONSE_SERVICE_HOST=response-service.service.consul ${dockerhub_id}/helloservice:latest
elif [ "${application_name}" = "response-service" ]; then
  sudo docker run -d --name ${application_name} --network=host -e INSTANCE_ID=$INSTANCE_ID ${dockerhub_id}/responseservice:latest
else
  echo "Unknown application name: ${application_name}"
fi

API_PAYLOAD='{
  "Name": "'${application_name}'",
  "ID": "'${application_name}'-'$INSTANCE_ID'",
  "Address": "'$PUBLIC_IP'",
  "Port": '${application_port}',
  "Meta": {
    "version": "1.0.0"
  },
  "EnableTagOverride": false,
  "Checks": [
    {
      "Name": "HTTP Health Check",
      "HTTP": "http://'$PUBLIC_IP':'${application_port}'/'${application_health_ep}'",
      "Interval": "10s",
      "Timeout": "1s"
    }
  ]
}'

echo $API_PAYLOAD > /tmp/api_payload.json

# Register the service with Consul
curl -X PUT http://${consul_ip}:8500/v1/agent/service/register \
-H "Content-Type: application/json" \
-d "$API_PAYLOAD"

sleep 10

curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://consul.service.consul:8500/v1/kv/minion_phrases