#!/bin/bash
set -e

echo "🚀 Deploying Complete Amazon Store Infrastructure"
echo "=================================================="
echo ""

# Load environment variables
if [ -f ../.env ]; then
    set -a
    source <(cat ../.env | grep -v '^#' | grep -v '^$')
    set +a
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

MINIKUBE_IP=$(minikube ip)

# Step 1: Create namespace
echo "📦 Step 1: Creating amazon-api namespace..."
kubectl apply -f ../base/namespace/namespace.yaml
kubectl apply -f ../base/namespace/dev-namespace.yaml
kubectl apply -f ../base/namespace/prod-namespace.yaml
echo "✅ Namespace created"
echo ""

# Step 2: Deploy Vault
echo "🔐 Step 2: Deploying Vault..."
./deploy-vault.sh
echo ""

# Step 3: Initialize Vault
echo "🔑 Step 3: Initializing Vault with secrets..."
sleep 5  # Give Vault a moment to fully start

# Get the vault pod name
VAULT_POD=$(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}')

# Check if Vault keys file exists
VAULT_KEYS_FILE="/tmp/vault-keys.json"

# Check if Vault is already initialized
if kubectl exec -n amazon-api $VAULT_POD -- vault status 2>&1 | grep -q "Initialized.*true"; then
    echo "Vault is already initialized"
    # Try to load keys from file if exists
    if [ -f "$VAULT_KEYS_FILE" ]; then
        echo "Loading Vault keys from $VAULT_KEYS_FILE"
        UNSEAL_KEY=$(jq -r '.unseal_key' $VAULT_KEYS_FILE)
        VAULT_ROOT_TOKEN=$(jq -r '.root_token' $VAULT_KEYS_FILE)
    else
        echo "⚠️  Vault is already initialized but keys file not found"
        echo "Using VAULT_ROOT_TOKEN from .env file"
    fi
else
    echo "Initializing Vault..."
    # Initialize Vault and capture keys
    VAULT_INIT_OUTPUT=$(kubectl exec -n amazon-api $VAULT_POD -- vault operator init -key-shares=1 -key-threshold=1 -format=json)
    UNSEAL_KEY=$(echo $VAULT_INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
    ROOT_TOKEN=$(echo $VAULT_INIT_OUTPUT | jq -r '.root_token')
    
    echo "Vault initialized with new keys"
    echo "IMPORTANT: Save these keys securely!"
    echo "Unseal Key: $UNSEAL_KEY"
    echo "Root Token: $ROOT_TOKEN"
    
    # Save keys to file
    echo "{\"unseal_key\": \"$UNSEAL_KEY\", \"root_token\": \"$ROOT_TOKEN\"}" > $VAULT_KEYS_FILE
    echo "Keys saved to $VAULT_KEYS_FILE"
    
    # Update VAULT_ROOT_TOKEN for subsequent commands
    VAULT_ROOT_TOKEN=$ROOT_TOKEN
fi

# Unseal Vault
echo "Unsealing Vault..."
if kubectl exec -n amazon-api $VAULT_POD -- vault status 2>&1 | grep -q "Sealed.*true"; then
    if [ -n "$UNSEAL_KEY" ]; then
        kubectl exec -n amazon-api $VAULT_POD -- vault operator unseal "$UNSEAL_KEY"
    else
        echo "⚠️  Vault is sealed but no unseal key available. Please unseal manually."
        echo "Skipping Vault secret initialization..."
        echo ""
    fi
else
    echo "Vault is already unsealed"
fi

# Only proceed with secret storage if Vault is unsealed
if kubectl exec -n amazon-api $VAULT_POD -- vault status 2>&1 | grep -q "Sealed.*false"; then
    # Login to Vault
    echo "Logging into Vault..."
    kubectl exec -n amazon-api $VAULT_POD -- vault login "${VAULT_ROOT_TOKEN}"
    
    # Enable KV secrets engine
    echo "Enabling KV secrets engine..."
    kubectl exec -n amazon-api $VAULT_POD -- vault secrets enable -version=2 -path=kv kv 2>/dev/null || echo "KV engine already enabled"
    
    # Store secrets
    echo "Storing secrets in Vault..."
    kubectl exec -n amazon-api $VAULT_POD -- vault kv put kv/amazon-api/github username="${GITHUB_USERNAME}" token="${GITHUB_TOKEN}"
    kubectl exec -n amazon-api $VAULT_POD -- vault kv put kv/amazon-api/dockerhub username="${DOCKERHUB_USERNAME}" token="${DOCKERHUB_TOKEN}"
    kubectl exec -n amazon-api $VAULT_POD -- vault kv put kv/amazon-api/jenkins admin_user="${JENKINS_ADMIN_USER}" admin_password="${JENKINS_ADMIN_PASSWORD}"
    kubectl exec -n amazon-api $VAULT_POD -- vault kv put kv/amazon-api/kubernetes namespace="${K8S_NAMESPACE}"
    kubectl exec -n amazon-api $VAULT_POD -- vault kv put kv/amazon-api/postgres database="${POSTGRES_DB}" username="${POSTGRES_USER}" password="${POSTGRES_PASSWORD}"
    
    echo "✅ Vault initialized with secrets"
fi
echo ""

# Step 4: Deploy PostgreSQL
echo "🐘 Step 4: Deploying PostgreSQL..."

# Create app-secrets for PostgreSQL
echo "Creating app-secrets..."
kubectl create secret generic app-secrets \
    --from-literal=POSTGRES_USER="${POSTGRES_USER}" \
    --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    --namespace=amazon-api \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f ../base/postgres/postgres-pvc.yaml
kubectl apply -f ../base/postgres/postgres-deployment.yaml
kubectl apply -f ../base/postgres/postgres-service.yaml
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n amazon-api --timeout=120s
echo "✅ PostgreSQL deployed"
echo ""

# Step 5: Deploy Users Service
echo "👤 Step 5: Deploying Users Service..."
# Replace placeholder with actual docker username
sed "s/\${DOCKERHUB_USERNAME}/${DOCKERHUB_USERNAME}/g" ../apps/users/deployment.yaml | kubectl apply -f -
kubectl apply -f ../apps/users/service.yaml
echo "⏳ Waiting for Users Service to be ready..."
kubectl wait --for=condition=ready pod -l app=amazon-api-users -n amazon-api --timeout=180s || echo "⚠️  Users service taking longer than expected..."
echo "✅ Users Service deployed"
echo ""

# Step 6: Deploy Orders Service
echo "📦 Step 6: Deploying Orders Service..."
kubectl apply -f ../apps/orders/deployment.yaml
kubectl apply -f ../apps/orders/service.yaml
echo "⏳ Waiting for Orders Service to be ready..."
kubectl wait --for=condition=ready pod -l app=amazonapi-orders -n amazon-api --timeout=180s || echo "⚠️  Orders service taking longer than expected..."
echo "✅ Orders Service deployed"
echo ""

# Step 7: Deploy Kong (in its own namespace)
echo "🦍 Step 7: Deploying Kong API Gateway..."
./deploy-kong.sh
echo ""

# Step 8: Deploy Jenkins
echo "🔨 Step 8: Deploying Jenkins..."
./deploy-jenkins.sh
echo ""

# Summary
echo "=================================================="
echo "✅ Complete Infrastructure Deployed!"
echo "=================================================="
echo ""
echo "📊 Services Status:"
echo "-------------------"
kubectl get pods -n amazon-api
echo ""
echo "🌐 Access URLs (Minikube IP: $MINIKUBE_IP):"
echo "-------------------------------------------"
echo "  • Users API:    http://$MINIKUBE_IP:30081/users-api/ (via Kong)"
echo "  • Orders API:   http://$MINIKUBE_IP:30081/orders-api/ (via Kong)"
echo "  • Vault:        http://$MINIKUBE_IP:30200"
echo "  • Jenkins:      http://$MINIKUBE_IP:30081 (if Kong not on 30080)"
echo "  • Kong Proxy:   http://$MINIKUBE_IP:30081"
echo ""
echo "🔑 Credentials:"
echo "---------------"
echo "  • Vault Token:  ${VAULT_ROOT_TOKEN}"
echo "  • Jenkins User: ${JENKINS_ADMIN_USER}"
echo "  • Jenkins Pass: ${JENKINS_ADMIN_PASSWORD}"
echo ""
