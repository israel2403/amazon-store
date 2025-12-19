# CI/CD Infrastructure on Kubernetes (Minikube)

This guide explains how to deploy Vault and Jenkins to Kubernetes (Minikube) instead of using Docker Compose.

## Architecture

- **Namespace**: `ci-cd` - Contains all CI/CD components
- **Vault**: Secrets management system running in dev mode
- **Jenkins**: CI/CD automation server with Docker, kubectl, and Maven support

## Prerequisites

1. Minikube running
   ```bash
   minikube start
   ```

2. Environment variables configured in `.env` file at project root
   ```
   VAULT_ROOT_TOKEN=your-token
   JENKINS_ADMIN_USER=admin
   JENKINS_ADMIN_PASSWORD=your-password
   GITHUB_USERNAME=your-username
   GITHUB_TOKEN=your-token
   DOCKERHUB_USERNAME=your-username
   DOCKERHUB_TOKEN=your-token
   K8S_NAMESPACE=amazon-api
   POSTGRES_DB=amazon_db
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=your-password
   ```

## Deployment

### Option 1: Deploy Everything at Once

```bash
cd k8s
chmod +x deploy-ci-cd.sh
./deploy-ci-cd.sh
```

### Option 2: Deploy Components Separately

#### Deploy Vault

```bash
cd k8s
chmod +x deploy-vault.sh
./deploy-vault.sh
```

After Vault is running, initialize it with secrets:

```bash
kubectl exec -it -n ci-cd deployment/vault -- /vault/scripts/init-vault.sh
```

#### Deploy Jenkins

```bash
cd k8s
chmod +x deploy-jenkins.sh
./deploy-jenkins.sh
```

## Access Services

### Vault
- **From host**: `http://$(minikube ip):30200`
- **Inside cluster**: `http://vault.ci-cd.svc.cluster.local:8200`
- **Token**: Value from `VAULT_ROOT_TOKEN` in `.env`

### Jenkins
- **From host**: `http://$(minikube ip):30080`
- **Inside cluster**: `http://jenkins.ci-cd.svc.cluster.local:8080`
- **Credentials**: 
  - Username: Value from `JENKINS_ADMIN_USER` in `.env`
  - Password: Value from `JENKINS_ADMIN_PASSWORD` in `.env`

## Components

### Vault

**Files:**
- `vault-namespace.yaml` - Creates ci-cd namespace
- `vault-configmap.yaml` - Contains init script for Vault
- `vault-pvc.yaml` - Persistent storage for data and logs
- `vault-deployment.yaml` - Vault deployment (dev mode)
- `vault-service.yaml` - NodePort service (port 30200)

**Features:**
- Running in dev mode (not for production!)
- Persistent storage for data and logs
- Pre-configured with init script to populate secrets
- Health checks configured

### Jenkins

**Files:**
- `jenkins-configmap.yaml` - Configuration as Code (CasC)
- `jenkins-pvc.yaml` - Persistent storage for Jenkins home
- `jenkins-rbac.yaml` - ServiceAccount and permissions
- `jenkins-deployment.yaml` - Jenkins deployment
- `jenkins-service.yaml` - NodePort service (ports 30080, 30050)

**Features:**
- Custom Docker image with Docker, kubectl, and Maven
- Configuration as Code (CasC) pre-configured
- Vault integration configured
- Access to host Docker socket for building images
- RBAC permissions to manage Kubernetes resources
- Persistent storage for Jenkins home directory

## Managing Resources

### View all CI/CD resources
```bash
kubectl get all -n ci-cd
```

### Check Vault logs
```bash
kubectl logs -n ci-cd deployment/vault -f
```

### Check Jenkins logs
```bash
kubectl logs -n ci-cd deployment/jenkins -f
```

### Delete all CI/CD resources
```bash
kubectl delete namespace ci-cd
```

### Restart a service
```bash
kubectl rollout restart deployment/vault -n ci-cd
kubectl rollout restart deployment/jenkins -n ci-cd
```

## Differences from Docker Compose

1. **Networking**: Services communicate via Kubernetes DNS (e.g., `vault.ci-cd.svc.cluster.local`)
2. **Storage**: Uses PersistentVolumeClaims instead of host volumes
3. **Secrets**: Kubernetes Secrets instead of environment variables
4. **Access**: NodePort services instead of port mapping
5. **Docker**: Jenkins accesses host Docker socket (same as Docker Compose)

## Troubleshooting

### Jenkins can't connect to Vault
- Check if Vault is running: `kubectl get pods -n ci-cd`
- Verify Vault service: `kubectl get svc -n ci-cd`
- Check Jenkins logs for connection errors

### Jenkins image pull errors
- Make sure you're using Minikube's Docker daemon: `eval $(minikube docker-env)`
- Rebuild the image: `docker build -t jenkins-custom:latest jenkins/`

### Permission issues with volumes
- The init container should fix permissions automatically
- Check init container logs: `kubectl logs -n ci-cd <pod-name> -c fix-permissions`

### Can't access services from host
- Get Minikube IP: `minikube ip`
- Make sure NodePort services are created: `kubectl get svc -n ci-cd`
- Check if Minikube tunnel is needed: `minikube service list`

## Production Considerations

**⚠️ This setup is for development only!**

For production:
1. Use Vault in production mode (not dev mode)
2. Use proper secrets management (not .env files)
3. Use LoadBalancer or Ingress instead of NodePort
4. Configure resource limits appropriately
5. Use proper TLS/SSL certificates
6. Implement proper backup strategies
7. Use external Docker registry instead of host Docker socket
8. Configure proper Jenkins agents/slaves
