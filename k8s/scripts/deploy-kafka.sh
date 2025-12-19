#!/bin/bash
set -e

echo "🚀 Deploying Kafka Cluster to Kubernetes..."
echo ""

# Ensure namespace exists
echo "📦 Ensuring amazon-api namespace exists..."
kubectl apply -f ../base/namespace/

# Deploy Zookeeper first
echo "🐘 Step 1: Deploying Zookeeper ensemble (3 replicas)..."
kubectl apply -f ../infrastructure/kafka/zookeeper-statefulset.yaml

# Wait for Zookeeper to be ready
echo "⏳ Waiting for Zookeeper pods to be ready..."
kubectl wait --for=condition=ready pod -l app=zookeeper -n amazon-api --timeout=180s

echo "✅ Zookeeper is ready!"
echo ""

# Deploy Kafka
echo "☕ Step 2: Deploying Kafka brokers (3 replicas)..."
kubectl apply -f ../infrastructure/kafka/kafka-statefulset.yaml

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka pods to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka -n amazon-api --timeout=300s

echo "✅ Kafka cluster is ready!"
echo ""

# Create topics
echo "📝 Step 3: Creating Kafka topics..."
kubectl apply -f ../infrastructure/kafka/kafka-topics-configmap.yaml
kubectl apply -f ../infrastructure/kafka/kafka-topics-job.yaml

echo "⏳ Waiting for topics creation job..."
kubectl wait --for=condition=complete job/kafka-topics-init -n amazon-api --timeout=120s || echo "⚠️  Topic creation may need more time"

echo ""
echo "=================================================="
echo "✅ Kafka Cluster Deployed Successfully!"
echo "=================================================="
echo ""
echo "📊 Kafka Cluster Details:"
echo "  • Zookeeper nodes: 3"
echo "  • Kafka brokers: 3"
echo "  • Replication factor: 3"
echo "  • Default partitions: 3"
echo ""
echo "🔌 Connection strings (from within cluster):"
echo "  kafka-0.kafka-headless.amazon-api.svc.cluster.local:9092"
echo "  kafka-1.kafka-headless.amazon-api.svc.cluster.local:9092"
echo "  kafka-2.kafka-headless.amazon-api.svc.cluster.local:9092"
echo ""
echo "  Or use the service: kafka.amazon-api.svc.cluster.local:9092"
echo ""
echo "📋 Check status:"
echo "  kubectl get pods -n amazon-api -l app=kafka"
echo "  kubectl get pods -n amazon-api -l app=zookeeper"
echo ""
echo "🔍 View topics:"
echo "  kubectl exec -it kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --list"
echo ""
