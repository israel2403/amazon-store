#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="amazon-api"

# Get DOCKERHUB_USERNAME from environment or use default
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"your-dockerhub-username"}

echo "Deploying amazonapi-orders service..."

# Create namespace if it doesn't exist
kubectl apply -f k8s/namespace.yaml

# Deploy PostgreSQL first
echo "Deploying PostgreSQL..."
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
kubectl -n "${NAMESPACE}" wait --for=condition=ready pod -l app=postgres --timeout=120s

# Use sed to replace ${DOCKERHUB_USERNAME} with actual value
sed "s/\${DOCKERHUB_USERNAME}/${DOCKERHUB_USERNAME}/g" k8s/deployment-orders.yaml | kubectl apply -f -

kubectl apply -f k8s/service-orders.yaml

echo "Waiting for deployment to complete..."
kubectl -n "${NAMESPACE}" rollout status deployment/amazonapi-orders-deployment

echo "amazonapi-orders deployed successfully!"
kubectl -n "${NAMESPACE}" get pods -l app=amazonapi-orders
