#!/bin/bash

# Initialize Vault with secrets for Jenkins pipelines
# This script configures a dev-mode Vault instance

set -e

NAMESPACE="amazon-api"
VAULT_POD=$(kubectl get pod -n $NAMESPACE -l app=vault -o jsonpath='{.items[0].metadata.name}')
VAULT_TOKEN="dev-root-token"

echo "🔐 Initializing Vault secrets..."

if [ -z "$VAULT_POD" ]; then
  echo "❌ Error: Vault pod not found in namespace $NAMESPACE"
  exit 1
fi

echo "✅ Found Vault pod: $VAULT_POD"

# Enable KV v2 secrets engine
echo "📝 Enabling KV v2 secrets engine..."
kubectl exec -n $NAMESPACE $VAULT_POD -- \
  vault secrets enable -path=kv kv-v2 2>/dev/null || echo "KV engine already enabled"

# Prompt for DockerHub credentials
echo ""
echo "📦 Enter your DockerHub credentials:"
read -p "DockerHub Username: " DOCKERHUB_USERNAME
read -sp "DockerHub Token/Password: " DOCKERHUB_TOKEN
echo ""

# Store DockerHub credentials
echo "🔒 Storing DockerHub credentials in Vault..."
kubectl exec -n $NAMESPACE $VAULT_POD -- \
  vault kv put kv/amazon-api/dockerhub \
  username="$DOCKERHUB_USERNAME" \
  token="$DOCKERHUB_TOKEN"

# Store Postgres credentials (from existing secrets)
echo "🔒 Storing Postgres credentials in Vault..."
POSTGRES_PASSWORD=$(kubectl get secret postgres-secrets -n $NAMESPACE -o jsonpath='{.data.postgres-password}' | base64 -d)

kubectl exec -n $NAMESPACE $VAULT_POD -- \
  vault kv put kv/amazon-api/postgres \
  database="amazon_store" \
  username="postgres" \
  password="$POSTGRES_PASSWORD"

echo ""
echo "✅ Vault initialization complete!"
echo ""
echo "📋 Stored secrets:"
echo "  - kv/amazon-api/dockerhub (username, token)"
echo "  - kv/amazon-api/postgres (database, username, password)"
echo ""
echo "🔑 Vault root token: $VAULT_TOKEN"
echo "🌐 Vault address: http://vault.amazon-api.svc.cluster.local:8200"
echo ""
