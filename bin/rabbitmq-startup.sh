#!/usr/bin/env bash

# https://gist.github.com/vncsna/64825d5609c146e80de8b1fd623011ca
set -euo pipefail

# Check if the RabbitMQ container is already running
RABBITMQ_CONTAINER_NAME="rabbitmq"
if [ $(docker ps -q -f name=^/${RABBITMQ_CONTAINER_NAME}$) ]; then
    echo "RabbitMQ container already running. Skipping RabbitMQ startup."
else
    echo "Starting RabbitMQ"
    # Start RabbitMQ
    docker compose up -d rabbitmq
    # Wait for RabbitMQ to start
    sleep 10
fi

