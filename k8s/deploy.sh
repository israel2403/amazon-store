#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="amazon-api"

# Substitute environment variables in deployment.yaml
export DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"your-dockerhub-username"}

kubectl apply -f k8s/namespace.yaml
envsubst < k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/service.yaml

kubectl -n "${NAMESPACE}" rollout status deployment/amazon-api-users-deployment
