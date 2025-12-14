#!/bin/bash
set -e

echo "🔨 Deploying Jenkins to Kubernetes..."

# Load environment variables
if [ -f ../.env ]; then
    export $(cat ../.env | grep -v '^#' | xargs)
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

# Build Jenkins Docker image and load it into Minikube
echo "🏗️  Building Jenkins custom image..."
eval $(minikube docker-env)
docker build -t jenkins-custom:latest ../jenkins/

echo "📦 Ensuring amazon-api namespace exists..."
kubectl apply -f namespace.yaml

# Create secrets for Jenkins
echo "🔑 Creating Jenkins secrets..."
kubectl create secret generic jenkins-secrets \
    --from-literal=admin-user="${JENKINS_ADMIN_USER}" \
    --from-literal=admin-password="${JENKINS_ADMIN_PASSWORD}" \
    --namespace=amazon-api \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy Jenkins components
echo "📝 Creating ConfigMap..."
kubectl apply -f jenkins-configmap.yaml

echo "👤 Creating ServiceAccount and RBAC..."
kubectl apply -f jenkins-rbac.yaml

echo "💾 Creating PersistentVolumeClaim..."
kubectl apply -f jenkins-pvc.yaml

echo "🚀 Creating Jenkins Deployment..."
kubectl apply -f jenkins-deployment.yaml

echo "🌐 Creating Jenkins Service..."
kubectl apply -f jenkins-service.yaml

# Wait for Jenkins to be ready
echo "⏳ Waiting for Jenkins to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=jenkins -n amazon-api --timeout=300s

echo "✅ Jenkins deployed successfully!"
echo ""
echo "📊 Jenkins is accessible at:"
echo "   - Inside cluster: http://jenkins.amazon-api.svc.cluster.local:8080"
echo "   - From host: http://$(minikube ip):30081"
echo ""
echo "🔑 Login credentials:"
echo "   Username: ${JENKINS_ADMIN_USER}"
echo "   Password: ${JENKINS_ADMIN_PASSWORD}"
