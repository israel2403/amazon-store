#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="amazon-api"

# Get DOCKERHUB_USERNAME from environment or use default
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"your-dockerhub-username"}

echo "Deploying amazon-api-users service..."

# Create namespace if it doesn't exist
kubectl apply -f k8s/namespace.yaml

# Use sed to replace ${DOCKERHUB_USERNAME} with actual value
sed "s/\${DOCKERHUB_USERNAME}/${DOCKERHUB_USERNAME}/g" k8s/deployment.yaml | kubectl apply -f -

kubectl apply -f k8s/service.yaml

echo "Waiting for deployment to complete..."
kubectl -n "${NAMESPACE}" rollout status deployment/amazon-api-users-deployment

echo "amazon-api-users deployed successfully!"
kubectl -n "${NAMESPACE}" get pods -l app=amazon-api-users
