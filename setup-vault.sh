#!/usr/bin/env bash
set -e

echo "🚀 Amazon Store - Vault Setup Script"
echo "====================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env from .env.example and fill in your credentials:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
REQUIRED_VARS=(
    "VAULT_ROOT_TOKEN"
    "GITHUB_USERNAME"
    "GITHUB_TOKEN"
    "DOCKERHUB_USERNAME"
    "DOCKERHUB_TOKEN"
    "JENKINS_ADMIN_PASSWORD"
    "POSTGRES_DB"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
)

echo "🔍 Validating environment variables..."
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Missing required variables in .env:"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    exit 1
fi

echo "✅ All required variables are set"
echo ""

# Check if Vault container is running
echo "🔍 Checking Vault container status..."
if ! docker ps | grep -q amazon-api-vault; then
    echo "📦 Starting Vault container..."
    docker compose up -d vault
    echo "⏳ Waiting for Vault to be ready (30 seconds)..."
    sleep 30
else
    echo "✅ Vault container is already running"
fi

# Check Vault status
echo ""
echo "🔍 Checking Vault status..."
VAULT_STATUS=$(docker exec amazon-api-vault vault status -format=json 2>/dev/null || echo '{}')

if echo "$VAULT_STATUS" | grep -q '"initialized":true'; then
    echo "✅ Vault is already initialized"
else
    echo "📝 Vault needs initialization"
fi

# Run the initialization script inside Vault container
echo ""
echo "🔐 Loading secrets into Vault..."
docker exec -e GITHUB_USERNAME="$GITHUB_USERNAME" \
            -e GITHUB_TOKEN="$GITHUB_TOKEN" \
            -e DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME" \
            -e DOCKERHUB_TOKEN="$DOCKERHUB_TOKEN" \
            -e JENKINS_ADMIN_USER="$JENKINS_ADMIN_USER" \
            -e JENKINS_ADMIN_PASSWORD="$JENKINS_ADMIN_PASSWORD" \
            -e K8S_NAMESPACE="$K8S_NAMESPACE" \
            -e POSTGRES_DB="$POSTGRES_DB" \
            -e POSTGRES_USER="$POSTGRES_USER" \
            -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
            -e VAULT_TOKEN="$VAULT_ROOT_TOKEN" \
            amazon-api-vault sh -c "cd /vault && sh /vault/scripts/init-vault.sh"

echo ""
echo "✅ Vault setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Start Jenkins: docker compose up -d jenkins"
echo "2. Create Jenkins jobs as described in SEPARATE_PIPELINES_SETUP.md"
echo "3. Run your pipelines!"
echo ""
echo "🔍 To verify secrets in Vault:"
echo "  docker exec -e VAULT_TOKEN=$VAULT_ROOT_TOKEN amazon-api-vault vault kv get kv/amazon-api/dockerhub"
