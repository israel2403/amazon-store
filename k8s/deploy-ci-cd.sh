#!/bin/bash
set -e

echo "🚀 Deploying CI/CD infrastructure to Kubernetes..."
echo "=================================================="
echo ""

# Deploy Vault first
./deploy-vault.sh

echo ""
echo "=================================================="
echo ""

# Deploy Jenkins
./deploy-jenkins.sh

echo ""
echo "=================================================="
echo "✅ CI/CD infrastructure deployed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Initialize Vault with secrets:"
echo "      kubectl exec -it -n amazon-api deployment/vault -- /vault/scripts/init-vault.sh"
echo ""
echo "   2. Access Jenkins at: http://$(minikube ip):30080"
echo "   3. Access Vault at: http://$(minikube ip):30200"
