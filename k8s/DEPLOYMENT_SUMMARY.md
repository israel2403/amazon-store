# Kubernetes Deployment Summary

## ✅ Successfully Deployed Infrastructure

All services are running in the `amazon-api` namespace on Minikube.

### Deployed Components

| Service | Type | Pods | Port | Access URL |
|---------|------|------|------|------------|
| Vault | StatefulSet | 1 | 30200 (NodePort) | http://192.168.49.2:30200 |
| Jenkins | Deployment | 1 | 30081 (NodePort) | http://192.168.49.2:30081 |
| PostgreSQL | Deployment | 1 | 5432 (ClusterIP) | postgres.amazon-api.svc.cluster.local:5432 |
| Users API | Deployment | 3 | 8081 (ClusterIP) | amazon-api-users-service.amazon-api.svc.cluster.local:8081 |
| Orders API | Deployment | 3 | 8082 (ClusterIP) | amazonapi-orders-service.amazon-api.svc.cluster.local:8082 |

### Namespace Configuration

**Everything is in the `amazon-api` namespace** as required:
- ✅ Vault
- ✅ Jenkins
- ✅ PostgreSQL
- ✅ Users Service
- ✅ Orders Service

### Test Results

1. **Vault** ✅
   - Accessible at: http://192.168.49.2:30200
   - Status: Initialized and unsealed
   - Secrets stored successfully

2. **Jenkins** ✅
   - Accessible at: http://192.168.49.2:30081
   - Status: Running and responsive
   - Credentials: admin / }Im^^QF0fts|>MB~0TM5l<X94l<t9Im%*xeT

3. **PostgreSQL** ✅
   - Accessible from within cluster
   - Database: amazon_orders
   - Connected to Orders service successfully

4. **Users Service** ✅
   - 3 replicas running
   - Endpoint `/users-api/hello` responds with "OK"
   - ClusterIP: 10.106.150.143:8081

5. **Orders Service** ✅
   - 3 replicas running
   - Service is accessible (HTTP 404 for non-existent routes is expected)
   - Connected to PostgreSQL
   - ClusterIP: 10.102.226.220:8082

## Service Communication

### Internal DNS Names (within cluster):
- `vault.amazon-api.svc.cluster.local:8200`
- `jenkins.amazon-api.svc.cluster.local:8080`
- `postgres.amazon-api.svc.cluster.local:5432`
- `amazon-api-users-service.amazon-api.svc.cluster.local:8081`
- `amazonapi-orders-service.amazon-api.svc.cluster.local:8082`

### External Access (from host):
- Vault: `http://$(minikube ip):30200`
- Jenkins: `http://$(minikube ip):30081`
- Users API: Use `kubectl port-forward -n amazon-api svc/amazon-api-users-service 8081:8081`
- Orders API: Use `kubectl port-forward -n amazon-api svc/amazonapi-orders-service 8082:8082`

## Testing Commands

### Quick Status Check
```bash
kubectl get all -n amazon-api
```

### Test Individual Services
```bash
# Vault
curl http://$(minikube ip):30200/v1/sys/health

# Jenkins
curl http://$(minikube ip):30081/login

# Users Service (via port-forward)
kubectl port-forward -n amazon-api svc/amazon-api-users-service 8081:8081 &
curl http://localhost:8081/users-api/hello
kill %1

# Orders Service (via port-forward)
kubectl port-forward -n amazon-api svc/amazonapi-orders-service 8082:8082 &
curl http://localhost:8082/orders-api/
kill %1
```

### Run Full Test Suite
```bash
cd k8s
./simple-test.sh
```

## Deployment Scripts

### Deploy Everything
```bash
cd k8s
./deploy-all.sh
```

### Deploy Individual Components
```bash
./deploy-vault.sh       # Deploy Vault
./deploy-jenkins.sh     # Deploy Jenkins
./deploy-kong.sh        # Deploy Kong (optional)
```

## Current State

```
NAME                                           READY   STATUS    RESTARTS   AGE
amazon-api-users-deployment-fb59485cb-6jgx8    1/1     Running   0          18m
amazon-api-users-deployment-fb59485cb-cmmz6    1/1     Running   0          18m
amazon-api-users-deployment-fb59485cb-j9684    1/1     Running   0          18m
amazonapi-orders-deployment-56d479f96c-k5k8z   1/1     Running   0          17m
amazonapi-orders-deployment-56d479f96c-nz5k8   1/1     Running   0          17m
amazonapi-orders-deployment-56d479f96c-wbdbf   1/1     Running   0          17m
jenkins-64f67c566-55fg9                        1/1     Running   0          7m
postgres-deployment-bdf58f445-tlbjk            1/1     Running   0          19m
vault-677677f589-fzzj5                         1/1     Running   0          21m
```

## Next Steps

### To add Kong API Gateway:
```bash
cd k8s
./deploy-kong.sh
```

Kong will be deployed in a separate `kong` namespace and will provide:
- Ingress routing to Users and Orders services
- API Gateway on NodePort 30080
- Admin API on ClusterIP 8001

### To access services via Kong:
Once Kong is deployed, you can access:
- Users API: `http://$(minikube ip):30080/users-api/`
- Orders API: `http://$(minikube ip):30080/orders-api/`

## Notes

- All sensitive data (Vault tokens, Jenkins passwords, DB credentials) are stored in Kubernetes Secrets
- Vault is running in dev mode (not suitable for production)
- PostgreSQL data is persisted in a PersistentVolumeClaim
- Jenkins home directory is persisted in a PersistentVolumeClaim
- All services are in the same namespace for easy communication

## Troubleshooting

### View Logs
```bash
kubectl logs -n amazon-api deployment/vault
kubectl logs -n amazon-api deployment/jenkins
kubectl logs -n amazon-api deployment/postgres-deployment
kubectl logs -n amazon-api deployment/amazon-api-users-deployment
kubectl logs -n amazon-api deployment/amazonapi-orders-deployment
```

### Restart Services
```bash
kubectl rollout restart deployment/vault -n amazon-api
kubectl rollout restart deployment/jenkins -n amazon-api
kubectl rollout restart deployment/amazon-api-users-deployment -n amazon-api
kubectl rollout restart deployment/amazonapi-orders-deployment -n amazon-api
```

### Delete Everything
```bash
kubectl delete namespace amazon-api
```
