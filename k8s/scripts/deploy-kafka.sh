#!/bin/bash
set -e

ENVIRONMENT="${1:-prod}"

if [ "$ENVIRONMENT" != "prod" ] && [ "$ENVIRONMENT" != "dev" ]; then
  echo "❌ Invalid environment: $ENVIRONMENT"
  echo "Usage: $0 [dev|prod]"
  echo "Default: prod"
  exit 1
fi

echo "🚀 Deploying Kafka Cluster to Kubernetes [$ENVIRONMENT]..."
echo ""

# Determine namespace and pod count
if [ "$ENVIRONMENT" = "prod" ]; then
  NAMESPACE="amazon-api-prod"
  REPLICAS=3
  OVERLAY="prod"
else
  NAMESPACE="amazon-api-dev"
  REPLICAS=1
  OVERLAY="dev"
fi

echo "📦 Deploying to: $NAMESPACE (Kafka replicas: $REPLICAS)"
echo ""

# Deploy using kustomize with the appropriate overlay
echo "🎯 Applying Kustomize overlay: overlays/$OVERLAY"
kubectl apply -k k8s/overlays/$OVERLAY

echo "⏳ Waiting for Kafka pods to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka -n $NAMESPACE --timeout=300s

echo ""
echo "=================================================="
echo "✅ Kafka Cluster Deployed Successfully!"
echo "=================================================="
echo ""
echo "📊 Kafka Cluster Details:"
echo "  • Environment: $ENVIRONMENT"
echo "  • Namespace: $NAMESPACE"
echo "  • Kafka brokers/controllers: $REPLICAS"
echo "  • Replication factor: $REPLICAS"
echo ""

echo "🔌 Connection strings (from within cluster):"
for ((i=0; i<$REPLICAS; i++)); do
  echo "  kafka-$i.kafka-headless.$NAMESPACE.svc.cluster.local:9092"
done
echo ""
echo "  Or use the service: kafka.$NAMESPACE.svc.cluster.local:9092"
echo ""
echo "📋 Check status:"
echo "  kubectl get pods -n $NAMESPACE -l app=kafka"
echo ""
echo "🔍 View topics:"
echo "  kubectl exec -it kafka-0 -n $NAMESPACE -- kafka-topics --bootstrap-server localhost:9092 --list"
echo ""
