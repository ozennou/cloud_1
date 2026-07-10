CONFIG_DIR := config
INVENTORY  := $(CONFIG_DIR)/inventory.ini
PLAYBOOK   := $(CONFIG_DIR)/playbook.yml
VAULT      := $(CONFIG_DIR)/group_vars/prd_servers/vault.yml

INFRA_DIR := infra

ANSIBLE          := ansible
ANSIBLE_PLAYBOOK := ansible-playbook
ANSIBLE_VAULT    := ansible-vault
TERRAFORM        := . ./secrets.sh && terraform -chdir=$(INFRA_DIR)

VAULT_ARGS := --ask-vault-pass

.PHONY: help up play run deploy check dry-run syntax ping facts list \
        encrypt decrypt view edit rekey \
        tf-init tf-plan tf-apply tf-output tf-fmt tf-validate tf-destroy

up: ## Provision infra and run the full deployment (deploy.sh)
	./deploy.sh

play run deploy: ## Run the playbook
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) $(VAULT_ARGS)

check dry-run: ## Run the playbook in check (dry-run) mode
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) $(VAULT_ARGS) --check --diff

syntax: ## Check the playbook syntax
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --syntax-check

ping: ## Ping all hosts in the inventory
	$(ANSIBLE) all -i $(INVENTORY) -m ping $(VAULT_ARGS)

facts: ## Gather facts from all hosts
	$(ANSIBLE) all -i $(INVENTORY) -m setup $(VAULT_ARGS)

list: ## List all hosts in the inventory
	$(ANSIBLE) all -i $(INVENTORY) --list-hosts

encrypt: ## Encrypt the vault file
	$(ANSIBLE_VAULT) encrypt $(VAULT)

decrypt: ## Decrypt the vault file
	$(ANSIBLE_VAULT) decrypt $(VAULT)

view: ## View the encrypted vault file
	$(ANSIBLE_VAULT) view $(VAULT)

edit: ## Edit the encrypted vault file in place
	$(ANSIBLE_VAULT) edit $(VAULT)

rekey: ## Change the vault password
	$(ANSIBLE_VAULT) rekey $(VAULT)

tf-init: ## Initialize terraform
	$(TERRAFORM) init -input=false

tf-plan: ## Show the terraform execution plan
	$(TERRAFORM) plan

tf-apply: ## Apply the terraform infrastructure
	$(TERRAFORM) apply -auto-approve

tf-output: ## Show terraform outputs
	$(TERRAFORM) output

tf-fmt: ## Format the terraform files
	$(TERRAFORM) fmt

tf-validate: ## Validate the terraform configuration
	$(TERRAFORM) validate

tf-destroy: ## Destroy the terraform infrastructure
	$(TERRAFORM) destroy -auto-approve
