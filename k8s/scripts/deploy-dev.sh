#!/bin/bash
set -e

echo "🚀 Deploying Development Environment"
echo "====================================="
echo ""

# Clean up any existing deployment
echo "🧹 Cleaning up existing resources..."
kubectl delete namespace amazon-api --ignore-not-found=true --wait=true 2>/dev/null || true
sleep 5

# Deploy dev environment
echo "📦 Deploying development environment with Kustomize..."
kubectl apply -k ../overlays/dev/

echo ""
echo "⏳ Waiting for core services to be ready..."

# Wait for Kafka (KRaft mode - no Zookeeper needed!)
echo "  ☕ Waiting for Kafka (KRaft)..."
kubectl wait --for=condition=ready pod -l app=kafka-kraft -n amazon-api --timeout=300s || echo "⚠️  Kafka taking longer..."

# Wait for PostgreSQL
echo "  🐘 Waiting for PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n amazon-api --timeout=120s || echo "⚠️  PostgreSQL taking longer..."

# Create topics
echo ""
echo "📝 Creating Kafka topics..."
kubectl apply -f ../infrastructure/kafka/kafka-topics-job.yaml

# Wait a bit for services to initialize
echo "⏳ Waiting for application services..."
sleep 20

# Wait for apps
kubectl wait --for=condition=ready pod -l app=amazon-api-users -n amazon-api --timeout=180s || echo "⚠️  Users service..."
kubectl wait --for=condition=ready pod -l app=amazonapi-orders -n amazon-api --timeout=180s || echo "⚠️  Orders service..."
kubectl wait --for=condition=ready pod -l app=notifications-service -n amazon-api --timeout=180s || echo "⚠️  Notifications service..."

echo ""
echo "====================================="
echo "✅ Development Environment Deployed!"
echo "====================================="
echo ""
echo "📊 Pod Status:"
kubectl get pods -n amazon-api
echo ""
echo "🔧 Development Configuration:"
echo "  • Kafka: 1 broker (KRaft mode, no Zookeeper!)"
echo "  • PostgreSQL: 1 replica"
echo "  • Users API: 1 replica"
echo "  • Orders API: 1 replica"
echo "  • Notifications: 1 replica"
echo "  • Replication Factor: 1"
echo "  • Resource Limits: Low (dev mode)"
echo ""
echo "🔌 Test Kafka:"
echo "  kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --list"
echo ""
