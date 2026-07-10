#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
CONFIG_DIR="$SCRIPT_DIR/config"
INVENTORY="$CONFIG_DIR/inventory.ini"

if [[ -f "$SCRIPT_DIR/secrets.sh" ]]; then
    source "$SCRIPT_DIR/secrets.sh"
fi

terraform -chdir="$INFRA_DIR" init -input=false
terraform -chdir="$INFRA_DIR" apply -auto-approve

IP="$(terraform -chdir="$INFRA_DIR" output -raw prd-eus-server-01-public-ip)"

if [[ -z "$IP" ]]; then
    echo "Error: could not read 'prd-eus-server-01-public-ip' from terraform output" >&2
    exit 1
fi
echo "VM public IP: $IP"

sed -i -E "s/ansible_host=[0-9]+(\.[0-9]+){3}/ansible_host=$IP/" "$INVENTORY"
echo "Updated ansible_host in $INVENTORY"

ansible-playbook -i "$INVENTORY" "$CONFIG_DIR/playbook.yml" --ask-vault-pass
