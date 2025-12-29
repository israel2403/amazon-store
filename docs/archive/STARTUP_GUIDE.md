# 🚀 Complete Startup Guide

Follow these steps **in order** to bring up the entire amazon-store system.

## ✅ Prerequisites Check

Before starting, verify you have:

```bash
# Check Docker
docker --version

# Check Minikube
minikube version

# Check kubectl
kubectl version --client

# Check Java
java --version

# Current directory
pwd
# Should be: /home/isra/Proyectos/apis/amazon-store
```

---

## 📋 Step-by-Step Startup

### Step 1: Check Your .env File

**File**: `.env` (root level)

```bash
cat .env
```

**Should contain**:
```bash
# Vault
VAULT_ADDR=http://localhost:8200
VAULT_ROOT_TOKEN=myroot

# GitHub
GITHUB_USERNAME=israel2403
GITHUB_TOKEN=ghp_...

# DockerHub
DOCKERHUB_USERNAME=israelhf24
DOCKERHUB_TOKEN=dckr_pat_...

# Jenkins
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=...

# Kubernetes
K8S_NAMESPACE=amazon-api

# PostgreSQL
POSTGRES_DB=amazon_orders
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SecurePostgres123!
```

✅ **If correct, proceed to Step 2**  
❌ **If missing, run**: `cp .env.example .env` then edit it

---

### Step 2: Setup Vault and Load Secrets

**Command**:
```bash
./setup-vault.sh
```

**What it does**:
1. Validates your .env file
2. Starts Vault container
3. Loads all secrets into Vault:
   - GitHub credentials
   - DockerHub credentials
   - Jenkins credentials
   - PostgreSQL credentials
   - K8s namespace

**Expected output**:
```
🚀 Amazon Store - Vault Setup Script
=====================================

🔍 Validating environment variables...
✅ All required variables are set

📦 Starting Vault container...
✅ Vault container is already running

🔐 Loading secrets into Vault...
🔑 Storing GitHub credentials...
🐳 Storing DockerHub credentials...
🔨 Storing Jenkins credentials...
☸️  Storing Kubernetes config...
🐘 Storing PostgreSQL credentials...

✅ Vault setup complete!
```

**Verify**:
```bash
# Check Vault container
docker ps | grep vault

# Check secrets in Vault
docker exec -e VAULT_TOKEN=myroot amazon-api-vault \
  vault kv list kv/amazon-api
```

---

### Step 3: Start Minikube

**Command**:
```bash
minikube start
```

**Verify**:
```bash
minikube status

# Should show:
# minikube
# type: Control Plane
# host: Running
# kubelet: Running
# apiserver: Running
# kubeconfig: Configured
```

---

### Step 4: Start Jenkins

**Command**:
```bash
docker compose up -d jenkins
```

**Wait for Jenkins to start** (takes 1-2 minutes):
```bash
# Watch logs
docker logs -f amazon-api-jenkins

# Wait until you see:
# "Jenkins is fully up and running"
# Then press Ctrl+C
```

**Verify**:
```bash
# Check Jenkins is running
docker ps | grep jenkins

# Test Jenkins web interface
curl -I http://localhost:8080
# Should return: HTTP/1.1 403 Forbidden (this is OK, means it's running)
```

**Access Jenkins**:
- URL: http://localhost:8080
- Username: `admin`
- Password: Run `grep JENKINS_ADMIN_PASSWORD .env | cut -d'=' -f2`

---

### Step 5: Start PostgreSQL (for Orders Service)

**Command**:
```bash
cd amazonapi-orders
docker compose up -d
cd ..
```

**Verify**:
```bash
# Check PostgreSQL is running
docker ps | grep postgres-orders

# Test connection
docker exec -it amazonapi-orders-postgres pg_isready -U postgres
# Should output: /var/run/postgresql:5432 - accepting connections
```

---

### Step 6: Create Jenkins Jobs (One-Time Setup)

You need to create two Jenkins jobs **manually** in the web UI.

#### Job 1: Users Service

1. Go to Jenkins: http://localhost:8080
2. Click **"New Item"**
3. Name: `amazon-api-users-pipeline`
4. Type: **Pipeline**
5. Click **OK**

**Configure**:
- ✅ **GitHub project**: `https://github.com/israel2403/amazon-store/`
- ✅ **Poll SCM**: Schedule: `H/5 * * * *`
- ✅ **Pipeline**:
  - Definition: `Pipeline script from SCM`
  - SCM: `Git`
  - Repository URL: `https://github.com/israel2403/amazon-store.git`
  - Credentials: (select github-credentials if private)
  - Branch: `*/master`
  - **Script Path**: `amazon-api-users/Jenkinsfile` ⚠️ **IMPORTANT**

Click **Save**

#### Job 2: Orders Service

1. Click **"New Item"**
2. Name: `amazonapi-orders-pipeline`
3. Type: **Pipeline**
4. Click **OK**

**Configure**:
- ✅ **GitHub project**: `https://github.com/israel2403/amazon-store/`
- ✅ **Poll SCM**: Schedule: `H/5 * * * *`
- ✅ **Pipeline**:
  - Definition: `Pipeline script from SCM`
  - SCM: `Git`
  - Repository URL: `https://github.com/israel2403/amazon-store.git`
  - Credentials: (select github-credentials if private)
  - Branch: `*/master`
  - **Script Path**: `amazonapi-orders/Jenkinsfile` ⚠️ **IMPORTANT**

Click **Save**

---

### Step 7: Deploy Services to Kubernetes

#### Option A: Via Jenkins (Recommended)

**In Jenkins UI**:
1. Click `amazon-api-users-pipeline`
2. Click **"Build Now"**
3. Wait for build to complete (check Console Output)

4. Click `amazonapi-orders-pipeline`
5. Click **"Build Now"**
6. Wait for build to complete

**Monitor builds**:
```bash
# Watch pipeline progress in terminal
watch kubectl get pods -n amazon-api
```

#### Option B: Deploy Manually

```bash
# Deploy users service
bash k8s/deploy-users.sh

# Deploy orders service
bash k8s/deploy-orders.sh
```

---

### Step 8: Verify Deployments

**Check pods**:
```bash
kubectl get pods -n amazon-api

# Expected output:
# NAME                                          READY   STATUS    RESTARTS   AGE
# amazon-api-users-deployment-xxxxx-xxxxx       1/1     Running   0          2m
# amazon-api-users-deployment-xxxxx-xxxxx       1/1     Running   0          2m
# amazon-api-users-deployment-xxxxx-xxxxx       1/1     Running   0          2m
# amazonapi-orders-deployment-xxxxx-xxxxx       1/1     Running   0          2m
# amazonapi-orders-deployment-xxxxx-xxxxx       1/1     Running   0          2m
# amazonapi-orders-deployment-xxxxx-xxxxx       1/1     Running   0          2m
```

**Check services**:
```bash
kubectl get svc -n amazon-api

# Expected output:
# NAME                       TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
# amazon-api-users-service   NodePort   10.xxx.xxx.xxx   <none>        8081:30081/TCP   2m
# amazonapi-orders-service   NodePort   10.xxx.xxx.xxx   <none>        8082:30082/TCP   2m
```

---

### Step 9: Test the Services

#### Test Users Service

```bash
# Get service URL
minikube service amazon-api-users-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazon-api-users-service -n amazon-api --url)/users-api

# Expected: {"helloWorldMsg":"Hello World!!!"}
```

#### Test Orders Service

```bash
# Get service URL
minikube service amazonapi-orders-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazonapi-orders-service -n amazon-api --url)/api/orders

# Expected: [] (empty array)

# Create an order
curl -X POST http://$(minikube service amazonapi-orders-service -n amazon-api --url)/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "productId": "product456",
    "quantity": 2
  }'
```

---

## 🎉 Success Checklist

- [ ] Vault container running
- [ ] Vault has all secrets loaded
- [ ] Minikube cluster running
- [ ] Jenkins running on port 8080
- [ ] PostgreSQL running for orders service
- [ ] Two Jenkins jobs created
- [ ] Users service deployed (3 pods running)
- [ ] Orders service deployed (3 pods running)
- [ ] Users API responds: `/users-api`
- [ ] Orders API responds: `/api/orders`

---

## 🔍 Quick Status Check Commands

**Check everything at once**:
```bash
echo "=== VAULT ==="
docker ps | grep vault

echo "=== MINIKUBE ==="
minikube status

echo "=== JENKINS ==="
docker ps | grep jenkins

echo "=== POSTGRESQL ==="
docker ps | grep postgres

echo "=== KUBERNETES PODS ==="
kubectl get pods -n amazon-api

echo "=== KUBERNETES SERVICES ==="
kubectl get svc -n amazon-api
```

---

## 🛑 Shutdown Everything

When you're done:

```bash
# Stop Kubernetes deployments
kubectl delete namespace amazon-api

# Stop Minikube
minikube stop

# Stop Jenkins and Vault
docker compose down

# Stop PostgreSQL
cd amazonapi-orders
docker compose down
cd ..
```

---

## 🔄 Restart After Shutdown

```bash
# 1. Start Vault (if needed)
docker compose up -d vault
./setup-vault.sh  # Only if Vault data was lost

# 2. Start Minikube
minikube start

# 3. Start Jenkins
docker compose up -d jenkins

# 4. Start PostgreSQL
cd amazonapi-orders && docker compose up -d && cd ..

# 5. Deploy services via Jenkins or manually
# (Jenkins jobs will auto-deploy if you push to GitHub)
```

---

## 📚 Additional Documentation

- **Vault Setup**: `VAULT_SETUP.md`
- **Pipeline Setup**: `SEPARATE_PIPELINES_SETUP.md`
- **PostgreSQL**: `POSTGRESQL_VAULT_INTEGRATION.md`
- **Quick Commands**: `QUICK_REFERENCE.md`
- **Orders Service**: `amazonapi-orders/README.md`

---

## 🆘 Troubleshooting

See each step above for verification commands. If something fails:

1. **Check logs**: `docker logs <container-name>`
2. **Check status**: `docker ps` or `kubectl get pods -n amazon-api`
3. **Restart the specific component** and try again

For detailed troubleshooting, see:
- `VAULT_SETUP.md` → Troubleshooting section
- `SEPARATE_PIPELINES_SETUP.md` → Troubleshooting section
- `amazonapi-orders/README.md` → Troubleshooting section
