#!/usr/bin/env bash
# Generate .env file from shell environment variables

set -e

echo "🔧 Generating .env file for Vault-enabled setup..."

REQUIRED_VARS=(
    VAULT_ROOT_TOKEN
    VAULT_ROLE_ID
    VAULT_SECRET_ID
    JENKINS_ADMIN_USER
    JENKINS_ADMIN_PASSWORD
    K8S_NAMESPACE
)

MISSING_VARS=()
for VAR_NAME in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR_NAME}" ]; then
        MISSING_VARS+=("$VAR_NAME")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Error: Missing environment variables: ${MISSING_VARS[*]}"
    echo ""
    echo "Please export these (from Vault initialization output) before running this script."
    exit 1
fi

# Allow overriding the local Vault address while defaulting to the docker-compose URL
VAULT_ADDR_VALUE=${VAULT_ADDR:-http://localhost:8200}

cat > .env << EOF
# .env - Generated from shell environment variables
# Do NOT commit this file!

VAULT_ADDR=${VAULT_ADDR_VALUE}
VAULT_ROOT_TOKEN=${VAULT_ROOT_TOKEN}
VAULT_ROLE_ID=${VAULT_ROLE_ID}
VAULT_SECRET_ID=${VAULT_SECRET_ID}

JENKINS_ADMIN_USER=${JENKINS_ADMIN_USER}
JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD}

K8S_NAMESPACE=${K8S_NAMESPACE}
EOF

echo "✅ .env file generated successfully!"
echo ""
echo "⚠️  Security reminder:"
echo "  - Store DockerHub/GitHub credentials in Vault (see VAULT_MIGRATION.md)"
echo "  - .env is excluded from git; keep it local only"
