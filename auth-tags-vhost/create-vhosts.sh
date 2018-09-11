#!/usr/bin/env bash

rabbitmqctl add_vhost dev || echo "Already exist vhost dev"
rabbitmqctl add_vhost prod  || echo "Already exist vhost prod"
