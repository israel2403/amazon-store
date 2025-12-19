#!/bin/bash
set -e

echo "🔐 Deploying Vault to Kubernetes..."

# Load environment variables
if [ -f ../.env ]; then
    export $(cat ../.env | grep -v '^#' | xargs)
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

# Create namespace
echo "📦 Creating amazon-api namespace..."
kubectl apply -f ../base/namespace/

# Create secrets for Vault
echo "🔑 Creating Vault secrets..."
kubectl create secret generic vault-secrets \
    --from-literal=root-token="${VAULT_ROOT_TOKEN}" \
    --namespace=amazon-api \
    --dry-run=client -o yaml | kubectl apply -f -

# Create secrets for Vault initialization script
echo "🔑 Creating secrets for Vault initialization..."
kubectl create secret generic vault-env-secrets \
    --from-literal=GITHUB_USERNAME="${GITHUB_USERNAME}" \
    --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
    --from-literal=DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME}" \
    --from-literal=DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN}" \
    --from-literal=JENKINS_ADMIN_USER="${JENKINS_ADMIN_USER}" \
    --from-literal=JENKINS_ADMIN_PASSWORD="${JENKINS_ADMIN_PASSWORD}" \
    --from-literal=K8S_NAMESPACE="${K8S_NAMESPACE}" \
    --from-literal=POSTGRES_DB="${POSTGRES_DB}" \
    --from-literal=POSTGRES_USER="${POSTGRES_USER}" \
    --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    --namespace=amazon-api \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy Vault components
echo "📝 Creating ConfigMap..."
kubectl apply -f ../infrastructure/vault/vault-configmap.yaml

echo "💾 Creating PersistentVolumeClaims..."
kubectl apply -f ../infrastructure/vault/vault-pvc.yaml

echo "🚀 Creating Vault Deployment..."
kubectl apply -f ../infrastructure/vault/vault-deployment.yaml

echo "🌐 Creating Vault Service..."
kubectl apply -f ../infrastructure/vault/vault-service.yaml

# Wait for Vault to be ready
echo "⏳ Waiting for Vault to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n amazon-api --timeout=120s

echo "✅ Vault deployed successfully!"
echo ""
echo "📊 Vault is accessible at:"
echo "   - Inside cluster: http://vault.amazon-api.svc.cluster.local:8200"
echo "   - From host: http://$(minikube ip):30200"
echo ""
echo "🔧 To initialize Vault with secrets, run:"
echo "   kubectl exec -it -n amazon-api deployment/vault -- /vault/scripts/init-vault.sh"
