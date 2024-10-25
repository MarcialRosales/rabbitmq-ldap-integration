.ONESHELL:# single shell invocation for all lines in the recipe
SHELL = bash# we depend on bash expansion for e.g. queue patterns

.DEFAULT_GOAL = help

### TARGETS ###

help:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

start-ldap: ## Start Openldap 
	@./bin/deploy-ldap

import-ldap: ## Import to ldap e.g. make import-ldap FILE=mgt-per-vhost-auth/import.ldif
	@./bin/import-ldap $(FILE)

stop-ldap: ## Stop Openldap
	@docker stop ldap

start-rabbitmq:  ## Run RabbitMQ Server
	@./bin/deploy-rabbit

stop-rabbitmq: ## Stop RabbitMQ Server
	@docker stop rabbitmq

start-perftest-producer: ## Start PerfTest producer application
	@./bin/run-perftest $(USERNAME) $(PWD) $(VHOST) \
		--queue "q-perf-test" \
		--producers 1 \
		--consumers 0 \
		--rate 1 \
		--flag persistent \
		--exchange "x-incoming-transaction" \
		--auto-delete "false"

stop-perftest-producer: ## Stop perfTest producer
	@docker stop $(USERNAME)

start-perftest-consumer: ## Start Perftest consumer application
	@./bin/run-perftest $(USERNAME) $(PWD) $(VHOST) \
		--queue "q-perf-test" \
		--producers 0 \
		--consumers 1 \
		--rate 1 \
		--flag persistent \
		--exchange "x-incoming-transaction" \
		--auto-delete "false"

stop-perftest-consumer: ## Stop perfTest consumer
	@docker stop $(USERNAME)

