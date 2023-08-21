#!/usr/bin/env bash

docker exec -it rabbitmq rabbitmqctl add_vhost dev-ß || echo "Already exist vhost dev"
docker exec -it rabbitmq rabbitmqctl add_vhost prod  || echo "Already exist vhost prod"
