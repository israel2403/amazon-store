#!/bin/bash
set -e

echo "🚀 Deploying Production Environment"
echo "====================================="
echo ""

# Clean up any existing deployment
echo "🧹 Cleaning up existing resources..."
kubectl delete namespace amazon-api --ignore-not-found=true --wait=true 2>/dev/null || true
sleep 5

# Deploy prod environment
echo "📦 Deploying production environment with Kustomize..."
kubectl apply -k ../overlays/prod/

echo ""
echo "⏳ Waiting for core infrastructure..."

# Wait for Kafka (all 3 brokers)
echo "  ☕ Waiting for Kafka cluster (3 brokers with KRaft)..."
kubectl wait --for=condition=ready pod kafka-0 -n amazon-api --timeout=300s || echo "⚠️  kafka-0 taking longer..."
kubectl wait --for=condition=ready pod kafka-1 -n amazon-api --timeout=300s || echo "⚠️  kafka-1 taking longer..."
kubectl wait --for=condition=ready pod kafka-2 -n amazon-api --timeout=300s || echo "⚠️  kafka-2 taking longer..."

# Wait for Vault
echo "  🔐 Waiting for Vault..."
kubectl wait --for=condition=ready pod -l app=vault -n amazon-api --timeout=180s || echo "⚠️  Vault taking longer..."

# Wait for PostgreSQL
echo "  🐘 Waiting for PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n amazon-api --timeout=120s || echo "⚠️  PostgreSQL taking longer..."

# Initialize Vault
echo ""
echo "🔑 Initializing Vault..."
sleep 5
kubectl exec -n amazon-api deployment/vault -- sh /vault/scripts/init-vault.sh || echo "⚠️  Vault init may need manual intervention"

# Create topics
echo ""
echo "📝 Creating Kafka topics..."
kubectl apply -f ../infrastructure/kafka/kafka-topics-job.yaml
kubectl wait --for=condition=complete job/kafka-topics-init -n amazon-api --timeout=120s || echo "⚠️  Topics creation..."

# Wait for Jenkins
echo "  🔨 Waiting for Jenkins..."
kubectl wait --for=condition=ready pod -l app=jenkins -n amazon-api --timeout=300s || echo "⚠️  Jenkins taking longer..."

# Wait a bit for services to initialize
echo ""
echo "⏳ Waiting for application services (5 replicas each)..."
sleep 30

# Check apps (may take time with 5 replicas)
kubectl get pods -n amazon-api -l app=amazon-api-users
kubectl get pods -n amazon-api -l app=amazonapi-orders
kubectl get pods -n amazon-api -l app=notifications-service

echo ""
echo "====================================="
echo "✅ Production Environment Deployed!"
echo "====================================="
echo ""
echo "📊 Pod Status:"
kubectl get pods -n amazon-api
echo ""
echo "🏭 Production Configuration:"
echo "  • Kafka: 3 brokers (KRaft mode - no Zookeeper!)"
echo "  • PostgreSQL: 1 replica"
echo "  • Users API: 5 replicas"
echo "  • Orders API: 5 replicas"
echo "  • Notifications: 3 replicas"
echo "  • Vault: 1 replica"
echo "  • Jenkins: 1 replica"
echo "  • Replication Factor: 3"
echo "  • Resource Limits: High (production)"
echo ""
echo "🔌 Kafka Status:"
kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --list
echo ""
MINIKUBE_IP=$(minikube ip)
echo "🌐 Access URLs:"
echo "  • Vault: http://$MINIKUBE_IP:30200"
echo "  • Jenkins: http://$MINIKUBE_IP:30081"
echo ""
