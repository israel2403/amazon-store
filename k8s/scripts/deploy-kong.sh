#!/bin/bash

# Deploy Kong Ingress Controller for Amazon API
# This script deploys Kong as the API Gateway replacing Spring Cloud Gateway

set -e

echo "=========================================="
echo "Kong Ingress Controller Deployment"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

K8S_DIR="$(dirname "$0")"

# Step 1: Create Kong namespace
echo -e "${YELLOW}[1/6] Creating Kong namespace...${NC}"
kubectl apply -f "$K8S_DIR/kong-namespace.yaml"

# Step 2: Deploy Kong Ingress Controller
echo -e "${YELLOW}[2/6] Deploying Kong Ingress Controller...${NC}"
kubectl apply -f "$K8S_DIR/kong-deployment.yaml"

# Step 3: Wait for Kong to be ready
echo -e "${YELLOW}[3/6] Waiting for Kong to be ready...${NC}"
kubectl wait --namespace kong \
  --for=condition=ready pod \
  --selector=app=kong-ingress-controller \
  --timeout=120s

# Step 4: Create or update application namespace
echo -e "${YELLOW}[4/6] Ensuring application namespace exists...${NC}"
kubectl apply -f "$K8S_DIR/namespace.yaml"

# Step 5: Deploy backend services (users and orders)
echo -e "${YELLOW}[5/6] Deploying backend services...${NC}"
kubectl apply -f "$K8S_DIR/deployment.yaml"
kubectl apply -f "$K8S_DIR/service.yaml"
kubectl apply -f "$K8S_DIR/deployment-orders.yaml"
kubectl apply -f "$K8S_DIR/service-orders.yaml"

# Step 6: Deploy Kong Ingress routes
echo -e "${YELLOW}[6/6] Configuring Kong Ingress routes...${NC}"
kubectl apply -f "$K8S_DIR/kong-ingress.yaml"

echo ""
echo -e "${GREEN}=========================================="
echo "Kong deployment completed successfully!"
echo -e "==========================================${NC}"
echo ""
echo "Kong Proxy is accessible at:"
echo "  HTTP:  http://localhost:30080"
echo "  HTTPS: https://localhost:30443"
echo ""
echo "API Routes:"
echo "  Users API:  http://localhost:30080/users-api"
echo "  Orders API: http://localhost:30080/api/orders"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n kong"
echo "  kubectl get pods -n amazon-api"
echo "  kubectl get ingress -n amazon-api"
echo "  kubectl logs -n kong -l app=kong-ingress-controller -c ingress-controller"
echo ""
