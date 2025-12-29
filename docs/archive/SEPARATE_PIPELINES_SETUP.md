# Separate Pipelines Setup Guide

This guide explains how to set up independent Jenkins pipelines for each microservice.

## 🏗️ Architecture Overview

**Option B: Separate Pipelines per Service**

Each service has its own:
- Jenkinsfile (in service directory)
- Jenkins job
- K8s deployment manifests
- Deployment script
- Independent build and deployment lifecycle

```
amazon-store/
├── amazon-api-users/
│   ├── Jenkinsfile          # Users pipeline
│   └── ...
├── amazonapi-orders/
│   ├── Jenkinsfile          # Orders pipeline
│   └── ...
└── k8s/
    ├── namespace.yaml       # Shared namespace
    ├── deployment.yaml      # Users deployment
    ├── service.yaml         # Users service
    ├── deployment-orders.yaml   # Orders deployment
    ├── service-orders.yaml      # Orders service
    ├── deploy-users.sh      # Users deploy script
    └── deploy-orders.sh     # Orders deploy script
```

## 📋 Services Configuration

### Service 1: amazon-api-users
- **Language**: Java (Maven)
- **Port**: 8081
- **Endpoint**: `/users-api`
- **NodePort**: 30081
- **Jenkinsfile**: `amazon-api-users/Jenkinsfile`
- **Deploy Script**: `k8s/deploy-users.sh`

### Service 2: amazonapi-orders
- **Language**: Java (Gradle)
- **Port**: 8082
- **Endpoint**: `/api/orders`
- **NodePort**: 30082
- **Jenkinsfile**: `amazonapi-orders/Jenkinsfile`
- **Deploy Script**: `k8s/deploy-orders.sh`

## 🚀 Jenkins Setup Instructions

### Step 1: Create Jenkins Job for Users Service

1. Go to Jenkins: http://localhost:8080
2. Click **"New Item"**
3. Enter name: `amazon-api-users-pipeline`
4. Select **"Pipeline"**
5. Click **OK**

**Configure:**

**General:**
- ✅ Check **"GitHub project"**
- Project url: `https://github.com/YOUR_USERNAME/amazon-store/`

**Build Triggers:**
- ✅ Check **"Poll SCM"**
- Schedule: `H/5 * * * *` (every 5 minutes)

**Pipeline:**
- **Definition**: `Pipeline script from SCM`
- **SCM**: `Git`
- **Repository URL**: `https://github.com/YOUR_USERNAME/amazon-store.git`
- **Credentials**: Select `github-credentials`
- **Branches to build**: `*/master`
- **Script Path**: `amazon-api-users/Jenkinsfile` ⚠️ **IMPORTANT**

**Save**

### Step 2: Create Jenkins Job for Orders Service

1. Click **"New Item"**
2. Enter name: `amazonapi-orders-pipeline`
3. Select **"Pipeline"**
4. Click **OK**

**Configure:**

**General:**
- ✅ Check **"GitHub project"**
- Project url: `https://github.com/YOUR_USERNAME/amazon-store/`

**Build Triggers:**
- ✅ Check **"Poll SCM"**
- Schedule: `H/5 * * * *` (every 5 minutes)

**Pipeline:**
- **Definition**: `Pipeline script from SCM`
- **SCM**: `Git`
- **Repository URL**: `https://github.com/YOUR_USERNAME/amazon-store.git`
- **Credentials**: Select `github-credentials`
- **Branches to build**: `*/master`
- **Script Path**: `amazonapi-orders/Jenkinsfile` ⚠️ **IMPORTANT**

**Save**

## 🧪 Testing the Pipelines

### Test Users Service Pipeline

```bash
# Trigger build in Jenkins UI
# Click "amazon-api-users-pipeline" → "Build Now"

# Wait for deployment to complete
kubectl get pods -n amazon-api -l app=amazon-api-users

# Get service URL
minikube service amazon-api-users-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazon-api-users-service -n amazon-api --url)/users-api
# Expected: {"helloWorldMsg":"Hello World!!!"}
```

### Test Orders Service Pipeline

```bash
# Trigger build in Jenkins UI
# Click "amazonapi-orders-pipeline" → "Build Now"

# Wait for deployment to complete
kubectl get pods -n amazon-api -l app=amazonapi-orders

# Get service URL
minikube service amazonapi-orders-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazonapi-orders-service -n amazon-api --url)/api/orders
# Expected: [] (empty array, or list of orders if database is populated)
```

## 🔄 Independent Development Workflow

### Making Changes to Users Service

```bash
# 1. Make changes
cd amazon-api-users/src/main/java/...
# Edit files...

# 2. Commit and push
git add amazon-api-users/
git commit -m "Update users service: add new feature"
git push origin master

# 3. Jenkins automatically detects changes
# Only amazon-api-users-pipeline runs!
# Orders service is unaffected

# 4. Verify deployment
kubectl logs -n amazon-api -l app=amazon-api-users --tail=50
```

### Making Changes to Orders Service

```bash
# 1. Make changes
cd amazonapi-orders/src/main/java/...
# Edit files...

# 2. Commit and push
git add amazonapi-orders/
git commit -m "Update orders service: add validation"
git push origin master

# 3. Jenkins automatically detects changes
# Only amazonapi-orders-pipeline runs!
# Users service is unaffected

# 4. Verify deployment
kubectl logs -n amazon-api -l app=amazonapi-orders --tail=50
```

## ✅ Advantages of Separate Pipelines

1. **Independent Deployments**: Update one service without affecting others
2. **Faster Builds**: Only build what changed
3. **Isolated Failures**: If one pipeline fails, others continue
4. **Clear Ownership**: Each team can own their service pipeline
5. **Different Build Schedules**: Set different poll schedules per service
6. **Technology Independence**: Maven vs Gradle, different Java versions, etc.

## 📊 Monitoring Both Services

```bash
# View all pods in namespace
kubectl get pods -n amazon-api

# View all services
kubectl get svc -n amazon-api

# View all deployments
kubectl get deployments -n amazon-api

# Stream logs from both services
kubectl logs -n amazon-api -l tier=backend -f

# Check resource usage
kubectl top pods -n amazon-api
```

## 🐛 Troubleshooting

### Issue: Pipeline can't find Jenkinsfile

**Problem**: Error: "Jenkinsfile not found"

**Solution**:
```bash
# Verify Jenkinsfile exists
ls -la amazon-api-users/Jenkinsfile
ls -la amazonapi-orders/Jenkinsfile

# Check Script Path in Jenkins job configuration
# Must be: amazon-api-users/Jenkinsfile
# NOT: Jenkinsfile
```

### Issue: Both pipelines trigger for any change

**Problem**: Pushing changes to one service triggers both pipelines

**Explanation**: This is expected behavior when using SCM polling. Both pipelines poll the same repository.

**Solutions**:

**Option 1: Accept it (Recommended for small projects)**
- Both pipelines run, but each only rebuilds its own service
- No actual harm, just some extra polling

**Option 2: Use Webhooks with path filters (Advanced)**
- Configure GitHub webhooks
- Use Jenkins Multibranch Pipeline with change detection
- More complex setup, better for larger teams

### Issue: Orders service deployment fails

**Problem**: Pods in CrashLoopBackOff

**Solution**:
```bash
# Check logs
kubectl logs -n amazon-api -l app=amazonapi-orders

# Common issue: Database not available
# The orders service expects PostgreSQL
# You may need to:
# 1. Deploy PostgreSQL in Kubernetes
# 2. Update environment variables in k8s/deployment-orders.yaml
# 3. Or run without database for testing (modify service)
```

## 🔗 Related Files

- `amazon-api-users/Jenkinsfile` - Users service pipeline
- `amazonapi-orders/Jenkinsfile` - Orders service pipeline
- `k8s/deploy-users.sh` - Users deployment script
- `k8s/deploy-orders.sh` - Orders deployment script
- `k8s/deployment.yaml` - Users K8s deployment
- `k8s/deployment-orders.yaml` - Orders K8s deployment
- `k8s/service.yaml` - Users K8s service
- `k8s/service-orders.yaml` - Orders K8s service
- `Jenkinsfile.monorepo-backup` - Old monorepo pipeline (backup)

## 📚 Next Steps

1. ✅ Create both Jenkins jobs
2. ✅ Run both pipelines manually
3. ✅ Verify both services are deployed
4. ✅ Test both endpoints
5. 🔄 Make a change to one service and verify only that pipeline runs
6. 📖 Read DEPLOYMENT_STEPS.md for general deployment guidance
7. 🔐 Review VAULT_MIGRATION.md for production security setup
