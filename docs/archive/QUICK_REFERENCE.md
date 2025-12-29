# Quick Reference - Separate Pipelines

## 🎯 Two Services, Two Pipelines

| Service | Users | Orders |
|---------|-------|--------|
| **Language** | Java (Maven) | Java (Gradle) |
| **Port** | 8081 | 8082 |
| **NodePort** | 30081 | 30082 |
| **Endpoint** | `/users-api` | `/api/orders` |
| **Jenkinsfile** | `amazon-api-users/Jenkinsfile` | `amazonapi-orders/Jenkinsfile` |
| **Deploy Script** | `k8s/deploy-users.sh` | `k8s/deploy-orders.sh` |
| **K8s Deployment** | `k8s/deployment.yaml` | `k8s/deployment-orders.yaml` |
| **K8s Service** | `k8s/service.yaml` | `k8s/service-orders.yaml` |

## 📋 Jenkins Job Configuration

### Job 1: amazon-api-users-pipeline
```
Script Path: amazon-api-users/Jenkinsfile
```

### Job 2: amazonapi-orders-pipeline
```
Script Path: amazonapi-orders/Jenkinsfile
```

## 🧪 Test Commands

### Users Service
```bash
# Get URL
minikube service amazon-api-users-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazon-api-users-service -n amazon-api --url)/users-api
# Expected: {"helloWorldMsg":"Hello World!!!"}
```

### Orders Service
```bash
# Get URL
minikube service amazonapi-orders-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazonapi-orders-service -n amazon-api --url)/api/orders
# Expected: []
```

## 🔍 Monitoring Commands

```bash
# View all pods
kubectl get pods -n amazon-api

# View all services
kubectl get svc -n amazon-api

# View users service logs
kubectl logs -n amazon-api -l app=amazon-api-users --tail=50

# View orders service logs
kubectl logs -n amazon-api -l app=amazonapi-orders --tail=50
```

## 📚 Documentation

- **SEPARATE_PIPELINES_SETUP.md** - Complete setup guide
- **IMPLEMENTATION_SUMMARY.md** - What was changed
- **README.md** - General documentation
- **DEPLOYMENT_STEPS.md** - Deployment procedures
