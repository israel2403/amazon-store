#!/bin/bash

# Vault Secret Setup Script for Production
# This script configures Vault to store production secrets

set -e

VAULT_NAMESPACE="vault-system"
VAULT_POD=$(kubectl get pod -n $VAULT_NAMESPACE -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

echo "🔐 Setting up Vault secrets for production..."

# Check if Vault is running
if [ -z "$VAULT_POD" ]; then
  echo "❌ Error: Vault pod not found. Please deploy Vault first."
  exit 1
fi

echo "✅ Found Vault pod: $VAULT_POD"

# Enable Kubernetes auth method (if not already enabled)
echo "📝 Configuring Vault Kubernetes auth..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault auth enable kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

# Configure Kubernetes auth
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create a policy for amazon-store
echo "📝 Creating Vault policy for amazon-store..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write amazon-store - <<EOF
path "secret/data/amazon-store/prod/*" {
  capabilities = ["read", "list"]
}
EOF

# Create role for amazon-store service account
echo "📝 Creating Vault role..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/amazon-store \
  bound_service_account_names=amazon-store-sa \
  bound_service_account_namespaces=amazon-api \
  policies=amazon-store \
  ttl=24h

# Store production secrets
echo "🔒 Storing production secrets in Vault..."
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amazon-store/prod/database \
  POSTGRES_USER="postgres" \
  POSTGRES_PASSWORD="CHANGE_THIS_IN_PRODUCTION"

echo ""
echo "✅ Vault setup complete!"
echo ""
echo "⚠️  IMPORTANT: Change the default password!"
echo "To update the production password, run:"
echo ""
echo "kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault kv put secret/amazon-store/prod/database \\"
echo "  POSTGRES_USER=\"postgres\" \\"
echo "  POSTGRES_PASSWORD=\"YOUR_SECURE_PASSWORD\""
echo ""
