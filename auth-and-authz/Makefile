.ONESHELL:# single shell invocation for all lines in the recipe
SHELL = bash# we depend on bash expansion for e.g. queue patterns

.DEFAULT_GOAL = help

### TARGETS ###

help:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

setup: ## Start rabbitmq+ldap+configure both
	@echo "Starting RabbitMQ"
	@(MODE=auth-and-authz ../bin/deploy-rabbit)
	@echo "Creating vhosts"
	@(./create-vhosts.sh)
	@echo "Starting Ldap"
	@(./start.sh)
	@echo "Importing ldif file"
	@(./import.sh)

teardown: ## Stop everything
	@(docker kill rabbitmq || docker rm rabbitmq)
	@(docker kill openldap || docker rm openldap)

start-perftest-producer: ## Start PerfTest producer application
	@docker run -d --rm \
	  --network rabbitmq_net \
	  --name $(name) \
	  pivotalrabbitmq/perf-test:latest \
	  --uri \"amqp://$(username):$(password)@rabbitmq:5672/$(vhost)\" \
		--producers 1 \
		--consumers 0 \
		--rate 1 \
		--flag persistent \
		--exchange \"$(exchange)\" \
		--auto-delete "false"

stop-perftest-producer: ## Stop perfTest producer
	@docker stop $(PRODUCER)
