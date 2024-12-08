#!/bin/bash

set -e

docker login -u $DOCKER_USER -p $DOCKER_PASSWORD

cd HelloService
docker build --tag $DOCKER_USER/hello_service:latest .

docker image push $DOCKER_USER/hello_service:latest

cd ../ResponseService
docker build --tag $DOCKER_USER/response_service:latest .

docker image push $DOCKER_USER/response_service:latest
