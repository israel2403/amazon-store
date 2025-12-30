# Quick Start Guide

Get your Spring Boot Hello World app deployed with CI/CD in minutes!

## ✅ Prerequisites Check

```bash
# Run the verification script
./verify-setup.sh
```

If any issues are found, install the missing tools.

## 🚀 5-Minute Deployment

### 1. Start Minikube
```bash
minikube start
kubectl cluster-info  # Verify cluster is running
```

### 2. Deploy Infrastructure (Jenkins, Vault, PostgreSQL)
```bash
# Deploy to dev environment
kubectl apply -k k8s/overlays/dev/

# Wait for Jenkins to be ready (takes 2-3 minutes)
kubectl rollout status -n amazon-api deployment/jenkins --timeout=5m

# Check all pods are running
kubectl get pods -n amazon-api
```

### 3. Access Jenkins
```bash
# Get Jenkins URL (NodePort service)
minikube service jenkins -n amazon-api --url
# Or use: http://$(minikube ip):30081
```

**Jenkins Credentials:**
- URL: http://192.168.49.2:30081 (or the URL from above command)
- Username: `admin`
- Password: `admin123`

### 4. Unseal Vault (if needed)
```bash
# Check Vault status
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault status

# If sealed, unseal it
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault operator unseal jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=
```

### 5. Create Jenkins Pipelines

1. Go to Jenkins: http://192.168.49.2:30081 (use the URL from step 3)
2. Login with `admin` / `admin123`

**Create Users Service Pipeline:**
1. Click **"New Item"**
2. Enter name: `amazon-api-users-pipeline`
3. Select **"Pipeline"**, click **OK**
4. Scroll to **"Pipeline"** section:
   - **Definition**: "Pipeline script from SCM"
   - **SCM**: Git
   - **Repository URL**: `https://github.com/YOUR_USERNAME/amazon-store.git`
   - **Branch**: `*/master`
   - **Script Path**: `amazon-api-users/Jenkinsfile`
5. Click **Save**

**Create Orders Service Pipeline:**
1. Repeat steps above with name: `amazonapi-orders-pipeline`
2. **Script Path**: `amazonapi-orders/Jenkinsfile`

**Create Notifications Service Pipeline:**
1. Repeat steps above with name: `notifications-service-pipeline`
2. **Script Path**: `notifications-service/Jenkinsfile`

### 6. Run the Pipelines

1. Click on each pipeline and select **"Build Now"**
2. Watch the pipeline execute:
   - ✅ Load credentials from Vault
   - ✅ Build & test (Maven/Gradle/npm)
   - ✅ Build Docker image
   - ✅ Push to DockerHub
   - ✅ Deploy to Development (amazon-api-dev)
   - ✅ Deploy to Production (amazon-api-prod, master branch only)

### 7. Test the Deployed Apps

```bash
# Get the service URL
minikube service amazon-api-users-service -n amazon-api --url

# Or use port-forward
kubectl port-forward -n amazon-api svc/amazon-api-users-service 8081:8081

# Test it
curl http://localhost:8081/users-api
# Expected: {"helloWorldMsg":"Hello World!!!"}

curl http://localhost:8081/users-api/hello
# Expected: OK
```

## 🎉 You're Done!

Your Spring Boot app is now:
- ✅ Containerized with Docker
- ✅ Deployed to Kubernetes
- ✅ Automated with Jenkins CI/CD

## 📊 Monitor Your Deployment

```bash
# View pods
kubectl get pods -n amazon-api

# View logs
kubectl logs -n amazon-api -l app=amazon-api-users -f

# View service
kubectl get svc -n amazon-api

# Scale deployment
kubectl scale deployment amazon-api-users-deployment -n amazon-api --replicas=5
```

## 🔧 Troubleshooting

### Jenkins won't start
```bash
# Check Jenkins pod status
kubectl get pods -n amazon-api -l app=jenkins

# Check Jenkins logs
kubectl logs -n amazon-api -l app=jenkins --tail=100

# Restart Jenkins if needed
kubectl rollout restart -n amazon-api deployment/jenkins
```

### Can't access Jenkins web UI
```bash
# Get Jenkins service details
kubectl get svc -n amazon-api jenkins

# Get minikube IP and NodePort
minikube service jenkins -n amazon-api --url

# Or access directly
echo "http://$(minikube ip):30081"
```

### Vault is sealed
```bash
# Check Vault status
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault status

# Unseal Vault
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- vault operator unseal jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=
```

### Minikube issues
```bash
minikube status
minikube delete  # If needed
minikube start
```

### Pipeline fails with authentication error
```bash
# Check Vault has DockerHub credentials
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/dockerhub"

# Check Jenkins can reach Vault
kubectl exec -n amazon-api -l app=jenkins -- curl -s http://vault.amazon-api.svc.cluster.local:8200/v1/sys/health
```

### Pod not starting
```bash
kubectl describe pod -n amazon-api-dev <pod-name>
kubectl logs -n amazon-api-dev <pod-name>
kubectl logs -n amazon-api-dev <pod-name> --previous  # If crashed
```

## 📝 What's Next?

- [ ] Set up GitHub webhook for automatic builds
- [ ] Add integration tests
- [ ] Monitor with Prometheus/Grafana
- [ ] Migrate to HashiCorp Vault (see `VAULT_MIGRATION.md`)

## 📚 Documentation

- **README.md** - Complete project documentation
- **docs/VAULT.md** - Vault setup, unsealing, and secret management
- **docs/TROUBLESHOOTING.md** - Common issues and solutions
- **docs/SPRING_PROFILES_GUIDE.md** - Spring profiles configuration
- **k8s/docs/** - Kubernetes-specific documentation

## 🔒 Security Reminders

- 🔑 Jenkins credentials: admin/admin123 (stored in K8s secrets)
- 🛡️ Vault root token: hvs.qb4jSCwkdHBZwFZw14A7M7qV
- 🔐 Vault unseal key: jmm68gKlxBNmr4PNK1k5TPvbijP+XNs6DwN+YCK6jP8=
- ⚠️ Rotate DockerHub tokens every 90 days in Vault
- 📋 Review `docs/VAULT.md` for production hardening

## 💡 Tips

**View all services:**
```bash
kubectl get all -n amazon-api-dev
kubectl get all -n amazon-api-prod
```

**Restart a service:**
```bash
kubectl rollout restart -n amazon-api-dev deployment/amazon-api-users-deployment
```

**Reset dev environment:**
```bash
kubectl delete namespace amazon-api-dev
kubectl apply -k k8s/overlays/dev/
```

**Reset prod environment:**
```bash
kubectl delete namespace amazon-api-prod
kubectl apply -k k8s/overlays/prod/
```

**View Jenkins admin password:**
```bash
kubectl get secret -n amazon-api jenkins-secrets -o jsonpath='{.data.JENKINS_ADMIN_PASSWORD}' | base64 -d
```

**Access Jenkins pod directly:**
```bash
kubectl exec -it -n amazon-api $(kubectl get pod -n amazon-api -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- /bin/bash
```

---

**Need help?** Check the full documentation in `README.md`
