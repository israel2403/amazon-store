#!/bin/bash
set -e

echo "🚀 Deploying Complete Amazon Store Infrastructure"
echo "=================================================="
echo ""

# Load environment variables
if [ -f ../.env ]; then
    export $(cat ../.env | grep -v '^#' | xargs)
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

MINIKUBE_IP=$(minikube ip)

# Step 1: Create namespace
echo "📦 Step 1: Creating amazon-api namespace..."
kubectl apply -f ../base/namespace/
echo "✅ Namespace created"
echo ""

# Step 2: Deploy Vault
echo "🔐 Step 2: Deploying Vault..."
./deploy-vault.sh
echo ""

# Step 3: Initialize Vault
echo "🔑 Step 3: Initializing Vault with secrets..."
sleep 5  # Give Vault a moment to fully start
kubectl exec -n amazon-api deployment/vault -- /vault/scripts/init-vault.sh
echo "✅ Vault initialized"
echo ""

# Step 4: Deploy PostgreSQL
echo "🐘 Step 4: Deploying PostgreSQL..."
kubectl apply -f ../base/postgres/
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
kubectl apply -f ../apps/orders/
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
