# CI/CD Architecture

## Overview

Your Jenkins-based CI/CD pipeline automatically deploys services to isolated dev and prod environments based on the git branch.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │  amazon-api    │  │ amazon-api-dev │  │amazon-api-   │ │
│  │  (shared infra)│  │ (development)  │  │prod          │ │
│  │                │  │                │  │(production)  │ │
│  │  • Jenkins     │  │  • Users (1)   │  │  • Users (5) │ │
│  │  • Vault       │  │  • Orders (1)  │  │  • Orders(5) │ │
│  │                │  │  • Notif (1)   │  │  • Notif (3) │ │
│  │                │  │  • Kafka (1)   │  │  • Kafka (3) │ │
│  │                │  │  • PostgreSQL  │  │  • PostgreSQL│ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Namespaces

### 1. `amazon-api` (Shared Infrastructure)
- **Jenkins**: CI/CD orchestration
- **Vault**: Secret management for production
- **Purpose**: Shared services that manage both environments

### 2. `amazon-api-dev` (Development Environment)
- Minimal resources (1 replica per service)
- Uses K8s Secrets (no Vault)
- Single Kafka broker
- 5Gi storage

### 3. `amazon-api-prod` (Production Environment)
- HA configuration (3-5 replicas per service)
- Uses Vault for secrets
- 3-broker Kafka cluster
- 20Gi storage

## Pipeline Flow

### Development Branch (feature/dev/develop)
```
1. Commit to dev branch
   ↓
2. Jenkins detects change
   ↓
3. Load credentials from K8s Secrets
   ↓
4. Build & Test (mvn/gradle/npm)
   ↓
5. Build & Push Docker image (tag: latest + build number)
   ↓
6. Deploy to amazon-api-dev
   ↓
7. kubectl apply -k k8s/overlays/dev/
   ↓
8. Restart deployment in amazon-api-dev
```

### Master Branch (Production)
```
1. Merge to master branch
   ↓
2. Jenkins detects change
   ↓
3. Load credentials from Vault (amazon-api namespace)
   ↓
4. Build & Test
   ↓
5. Build & Push Docker image (tag: latest + build number)
   ↓
6. Deploy to amazon-api-dev FIRST (testing)
   ↓
7. kubectl apply -k k8s/overlays/dev/
   ↓
8. Deploy to amazon-api-prod (production)
   ↓
9. kubectl apply -k k8s/overlays/prod/
   ↓
10. Update image tag in amazon-api-prod
```

## Service Jenkinsfiles

Each service has its own Jenkinsfile:

### amazon-api-users/Jenkinsfile
- **Build Tool**: Maven (Spring Boot)
- **Dev Deploy**: `amazon-api-dev` namespace
- **Prod Deploy**: `amazon-api-prod` namespace (master only)

### amazonapi-orders/Jenkinsfile
- **Build Tool**: Gradle (Spring Boot)
- **Dev Deploy**: `amazon-api-dev` namespace
- **Prod Deploy**: `amazon-api-prod` namespace (master only)

### notifications-service/Jenkinsfile
- **Build Tool**: NPM (Node.js)
- **Dev Deploy**: `amazon-api-dev` namespace
- **Prod Deploy**: `amazon-api-prod` namespace (master only)

## Deployment Strategy

### Development
- **Trigger**: Every commit to any branch
- **Method**: Kustomize overlay (`kubectl apply -k k8s/overlays/dev/`)
- **Rollout**: Immediate restart to pick up new image
- **Approval**: None required

### Production
- **Trigger**: Only commits to `master` branch
- **Method**: Kustomize overlay (`kubectl apply -k k8s/overlays/prod/`)
- **Rollout**: Controlled restart with 5m timeout
- **Approval**: None (automatic on master merge)

## Credentials Management

### Development
- **Source**: Kubernetes Secrets
- **Location**: `amazon-api-dev` namespace
- **Credentials**:
  - DockerHub username/token
  - Database passwords
  
### Production
- **Source**: HashiCorp Vault
- **Location**: `amazon-api` namespace
- **Vault URL**: `http://vault.amazon-api.svc.cluster.local:8200`
- **Path**: `kv/amazon-api/dockerhub`
- **Credentials**:
  - DockerHub username/token (from Vault)
  - Database passwords (injected by Vault)

## Image Tagging Strategy

Each build creates two tags:
```
${DOCKERHUB_USERNAME}/${SERVICE_NAME}:${BUILD_NUMBER}
${DOCKERHUB_USERNAME}/${SERVICE_NAME}:latest
```

Example:
```
israelhf24/amazon-api-users:42
israelhf24/amazon-api-users:latest
```

The build number tag ensures traceability, while `latest` provides a stable reference.

## Key Benefits

1. **Branch-based Deployment**: Dev branches deploy to dev, master deploys to both
2. **Environment Isolation**: Dev and prod are completely separate
3. **Automatic CI/CD**: No manual intervention required
4. **Secrets Management**: Dev uses K8s Secrets, prod uses Vault
5. **Scalability**: Different resource allocations per environment
6. **Traceability**: Build numbers in image tags

## Common Operations

### Deploy a Feature to Dev
```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "Add new feature"
git push origin feature/my-feature

# 3. Jenkins automatically deploys to amazon-api-dev
```

### Deploy to Production
```bash
# 1. Merge to master (via PR or direct push)
git checkout master
git merge feature/my-feature
git push origin master

# 2. Jenkins automatically:
#    - Deploys to amazon-api-dev (testing)
#    - Deploys to amazon-api-prod (production)
```

### Manual Deployment
```bash
# Dev
kubectl apply -k k8s/overlays/dev/

# Prod
kubectl apply -k k8s/overlays/prod/
```

### Rollback
```bash
# Dev
kubectl rollout undo deployment/<service-name> -n amazon-api-dev

# Prod
kubectl rollout undo deployment/<service-name> -n amazon-api-prod
```

## Monitoring Deployments

### Check Pipeline Status
- Access Jenkins UI
- View pipeline logs for each service

### Check Kubernetes Status
```bash
# Dev environment
kubectl get pods -n amazon-api-dev
kubectl logs -n amazon-api-dev deployment/<service-name>

# Prod environment
kubectl get pods -n amazon-api-prod
kubectl logs -n amazon-api-prod deployment/<service-name>
```

### Watch Rollout Progress
```bash
# Dev
kubectl rollout status deployment/<service-name> -n amazon-api-dev

# Prod
kubectl rollout status deployment/<service-name> -n amazon-api-prod
```

## Troubleshooting

### Pipeline Fails at Build Stage
- Check build tool configuration (Maven/Gradle/NPM)
- Verify dependencies are available
- Check Jenkins logs

### Pipeline Fails at Deploy Stage
- Verify kubectl has access to cluster
- Check namespace exists
- Verify kustomization files are valid

### Pods CrashLoopBackOff After Deployment
- Check pod logs: `kubectl logs <pod-name> -n <namespace>`
- Verify ConfigMap and Secrets exist
- Check database/Kafka connectivity
- Verify image exists in DockerHub

### Vault Connection Issues (Prod Only)
- Verify Vault is running in `amazon-api` namespace
- Check Vault token is valid
- Verify secret path exists in Vault

## Future Enhancements

- Add manual approval gate for prod deployments
- Implement blue-green deployments
- Add automated testing stage
- Set up monitoring and alerting
- Add rollback automation
- Implement canary deployments
