#!/bin/bash

# The script is dedicated to setting/installation/configuration of the AMI image. 
# It installs the necessary packages and dependencies for the server to run. 
# The script installs Docker, HashiCorp Apt Repository, and HashiStack Packages. 
# The script also disables the firewall and installs Consul.

set -e

# Disable interactive apt prompts
export DEBIAN_FRONTEND=noninteractive

cd /ops

CONFIGDIR=/ops/shared/config
CONSULVERSION=1.18.2

sudo apt-get install -y software-properties-common

sudo add-apt-repository universe && sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux
sudo apt-get clean

# Disable the firewall
sudo ufw disable || echo "ufw not installed"

# Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates gnupg2 
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/${distro} $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Install HashiCorp Apt Repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install HashiStack Packages
# sudo apt-get update && sudo apt-get -y install \
	# consul=$CONSULVERSION* \
	# nomad=$NOMADVERSION* \
	# vault=$VAULTVERSION* \
	# consul-template=$CONSULTEMPLATEVERSION*

# Install Consul only
sudo apt-get update && sudo apt-get -y install consul=$CONSULVERSION*

sudo docker image pull $DOCKERHUB_ID/helloservice:latest
sudo docker image pull $DOCKERHUB_ID/responseservice:latest