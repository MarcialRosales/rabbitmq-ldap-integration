#!/usr/bin/env bash

docker exec rabbitmq rabbitmqctl add_vhost dev || echo "Already exist vhost dev"
docker exec rabbitmq rabbitmqctl add_vhost prod  || echo "Already exist vhost prod"
