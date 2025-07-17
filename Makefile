# Compilers/tools and flags
NIX := nix
NIXFLAGS := -L --impure
MIGRATION_NAME ?= undefined

# Directories
TST_DIR := supabase/tests

.PHONY: bootenv
bootenv: ## start up the environment. Do this before any other command but clean.
	nix develop

.PHONY: clean
clean: ## remove state of the local database
	rm -rf .devenv

.PHONY: pure-database
pure-database: clean ## starts up a local PostgreSQL cleaning the local environment. This will hang and delete your local ephemeral database data. This rule should be executed before the setup and the build rules.
	PGPASSWORD= PGUSER= PGDATABASE= nix develop .#services $(NIXFLAGS)

.PHONY: database
database: ## starts up a local PostgreSQL. This will hang. This rule should be executed before the setup and the build rules.
	PGPASSWORD= PGUSER= PGDATABASE= nix develop .#services $(NIXFLAGS)

.PHONY: setup
setup: ## sets up a local PostgreSQL cluster. See the flake file for the env arguments for this
	nix run .#setup $(NIXFLAGS)

.PHONY: build
build:  ## build a migration file out of the diff of your current SQL files and supabase. sets up a shadow database with the same structure as supabase and diffs it against the database that was built with the local SQL files. make build MIGRATION_NAME='name'
        ifeq ($(MIGRATION_NAME), undefined)
		@echo -e "\033[0;31mUndefined migration name. Use this rule like: make build MIGRATION_NAME='name'\033[0m"
		@exit 1


        else
		MIGRATION_FILE=$(MIGRATION_NAME) nix run .#build $(NIXFLAGS)
        endif

.PHONY: help
help: ## prints the help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
