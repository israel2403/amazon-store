#!/bin/bash
set -e

echo "🔐 Initializing Vault with secrets..."

# Wait for Vault to be ready
until vault status > /dev/null 2>&1; do
  echo "Waiting for Vault to be ready..."
  sleep 2
done

echo "✅ Vault is ready!"

# Enable KV secrets engine v2
echo "📝 Enabling KV secrets engine..."
vault secrets enable -version=2 -path=kv kv || echo "KV engine already enabled"

# Store GitHub credentials
echo "🔑 Storing GitHub credentials..."
vault kv put kv/amazon-api/github \
  username="${GITHUB_USERNAME}" \
  token="${GITHUB_TOKEN}"

# Store DockerHub credentials
echo "🐳 Storing DockerHub credentials..."
vault kv put kv/amazon-api/dockerhub \
  username="${DOCKERHUB_USERNAME}" \
  token="${DOCKERHUB_TOKEN}"

# Store Jenkins credentials
echo "🔨 Storing Jenkins credentials..."
vault kv put kv/amazon-api/jenkins \
  admin_user="${JENKINS_ADMIN_USER}" \
  admin_password="${JENKINS_ADMIN_PASSWORD}"

# Store K8s namespace
echo "☸️  Storing Kubernetes config..."
vault kv put kv/amazon-api/kubernetes \
  namespace="${K8S_NAMESPACE}"

# Store PostgreSQL credentials
echo "🐘 Storing PostgreSQL credentials..."
vault kv put kv/amazon-api/postgres \
  database="${POSTGRES_DB}" \
  username="${POSTGRES_USER}" \
  password="${POSTGRES_PASSWORD}"

# Verify secrets were stored
echo ""
echo "✅ Secrets stored successfully!"
echo ""
echo "Verifying secrets (showing keys only, not values):"
echo "=================================================="
vault kv get kv/amazon-api/github | grep -E "^(username|token)" || true
vault kv get kv/amazon-api/dockerhub | grep -E "^(username|token)" || true
vault kv get kv/amazon-api/jenkins | grep -E "^(admin_user|admin_password)" || true
vault kv get kv/amazon-api/kubernetes | grep -E "^namespace" || true
vault kv get kv/amazon-api/postgres | grep -E "^(database|username|password)" || true

echo ""
echo "🎉 Vault initialization complete!"
