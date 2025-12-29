# Complete Deployment Steps - DevOps CI/CD Setup

Follow these steps **in order** to get your CI/CD pipeline running.

## ✅ System Status Check

Before proceeding with setup, verify your current system status:

```bash
# Check Docker services
docker compose ps

# Check Minikube cluster
minikube status

# Check deployed applications
kubectl get pods -n amazon-api
kubectl get svc -n amazon-api

# Test application endpoints
minikube service amazon-api-users-service -n amazon-api --url
curl http://$(minikube service amazon-api-users-service -n amazon-api --url)/users-api
curl http://$(minikube service amazon-api-users-service -n amazon-api --url)/users-api/hello
```

**Expected Results:**
- Jenkins container: Running on port 8080
- Minikube: All components (host, kubelet, apiserver) Running
- Pods: 3 replicas of amazon-api-users-deployment in Running status
- Service: amazon-api-users-service exposed on NodePort 30081
- API Response: `{"helloWorldMsg":"Hello World!!!"}`
- Health Check: `OK`

**Note:** If Vault container is not running, that's expected - it's defined in docker-compose.yml but may need to be started separately.

---

## 🚨 IMPORTANT: Before You Start

**Security Check:**
```bash
# Verify .env is NOT going to be committed
cat .gitignore | grep "^\.env$"
# Should show: .env

# Double-check .env contains real credentials (not placeholders)
cat .env | head -5
```

---

## Phase 1: Local Setup (15 minutes)

### Step 1: Initialize Git Repository

```bash
cd /home/isra/Proyectos/apis/amazon-store

# Initialize git
git init

# Check what will be committed
git status

# IMPORTANT: Verify .env is NOT listed (should be ignored)
# If you see .env listed, STOP and fix .gitignore
```

### Step 2: Make Initial Commit (Locally)

```bash
# Add all files (except those in .gitignore)
git add .

# Verify .env is NOT staged
git status | grep ".env"
# Should show nothing or only .env.example

# Create initial commit
git commit -m "Initial commit: Spring Boot Hello World with CI/CD

- Complete Spring Boot application with Hello World endpoint
- Jenkins CI/CD pipeline configuration
- Kubernetes deployment manifests
- Docker multi-stage build
- Documentation and setup scripts
- Health check endpoints for K8s probes"

# Verify commit
git log --oneline
```

### Step 3: Start Local Infrastructure

```bash
# Start Minikube first
minikube start

# Verify Minikube is running
kubectl cluster-info
minikube status

# Start Jenkins (use 'docker compose' without hyphen for newer Docker versions)
docker compose up -d

# Wait for Jenkins to start (takes 1-2 minutes)
echo "Waiting for Jenkins to start..."
sleep 60

# Check Jenkins logs
docker logs amazon-api-jenkins --tail 50

# Jenkins should show: "Jenkins is fully up and running"
```

### Step 4: Access Jenkins

```bash
# Get Jenkins URL
echo "Jenkins URL: http://localhost:8080"
echo "Username: admin"
echo "Password: $JENKINS_ADMIN_PASSWORD"

# Open in browser
xdg-open http://localhost:8080 2>/dev/null || echo "Open http://localhost:8080 in your browser"
```

**Login to Jenkins:**
- Username: `admin`
- Password: Run `echo $JENKINS_ADMIN_PASSWORD` to see it

---

## Phase 2: GitHub Setup (10 minutes)

### Step 5: Create GitHub Repository

**Option A: Via Web (Recommended)**
1. Go to https://github.com/new
2. Repository name: `amazon-store` (or your preferred name)
3. Description: "Spring Boot Hello World with Jenkins CI/CD and Kubernetes"
4. **Visibility: Private** (recommended for credentials safety)
5. **DO NOT** initialize with README, .gitignore, or license
6. Click **"Create repository"**

**Option B: Via CLI (if you have `gh` CLI)**
```bash
gh repo create amazon-store --private --source=. --remote=origin
```

### Step 6: Connect Local Repo to GitHub

```bash
# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/amazon-store.git

# Verify remote is added
git remote -v

# Push to GitHub
git branch -M master
git push -u origin master
```

**Troubleshooting:**
If you get authentication errors:
```bash
# Use personal access token instead of password
# Token should be the one in your ~/.zshrc: $GITHUB_TOKEN
git push -u origin master
# Username: israel2403
# Password: <paste your $GITHUB_TOKEN>
```

---

## Phase 3: Configure Jenkins (15 minutes)

### Step 7: Verify Jenkins Credentials

Jenkins should auto-configure credentials from your `.env` file (via Configuration as Code).

**Verify in Jenkins UI:**
1. Go to: **Dashboard → Manage Jenkins → Credentials → System → Global credentials**
2. You should see:
   - `dockerhub-username-id`
   - `dockerhub-token-id`
   - `github-credentials`

**If credentials are missing:**
```bash
# Check if Jenkins loaded the .env file
docker exec -it amazon-api-jenkins env | grep DOCKER
docker exec -it amazon-api-jenkins env | grep GITHUB

# If empty, restart Jenkins
docker compose restart jenkins
```

### Step 8: Create Jenkins Pipeline Job

1. **Go to Jenkins Dashboard**: http://localhost:8080
2. Click **"New Item"** (top left)
3. **Item name**: `amazon-api-users-pipeline`
4. Select **"Pipeline"**
5. Click **OK**

**Configure the Pipeline:**

**General Section:**
- ✅ Check **"GitHub project"**
- Project url: `https://github.com/YOUR_USERNAME/amazon-store/`

**Build Triggers:**
- ✅ Check **"Poll SCM"**
- Schedule: `H/1 * * * *` (checks every minute - for testing)
- Later change to: `H/5 * * * *` (every 5 minutes)

**Pipeline Section:**
- **Definition**: Select `Pipeline script from SCM`
- **SCM**: Select `Git`
- **Repository URL**: `https://github.com/YOUR_USERNAME/amazon-store.git`
- **Credentials**: Select `github-credentials` (if private repo)
- **Branches to build**: `*/master`
- **Script Path**: `Jenkinsfile`

**Save** the configuration.

---

## Phase 4: First Pipeline Run (20 minutes)

### Step 9: Verify Docker Access from Jenkins

```bash
# Jenkins needs to access Docker
docker exec -it amazon-api-jenkins docker ps

# If you get permission errors:
sudo chmod 666 /var/run/docker.sock

# Restart Jenkins
docker compose restart jenkins
```

### Step 10: Verify Kubernetes Access from Jenkins

```bash
# Check if Jenkins can access kubectl
docker exec -it amazon-api-jenkins kubectl cluster-info

# If you get errors, verify minikube is running
minikube status

# Ensure ~/.kube is mounted correctly
docker exec -it amazon-api-jenkins ls -la /var/jenkins_home/.kube/
```

### Step 11: Run Your First Build

**In Jenkins UI:**
1. Click on your pipeline: `amazon-api-users-pipeline`
2. Click **"Build Now"** (left sidebar)
3. Watch the build progress (click on build #1)
4. Click **"Console Output"** to see detailed logs

**Expected Pipeline Stages:**
1. ✅ **Checkout** - Pulls code from GitHub
2. ✅ **Build & Test** - Compiles with Maven
3. ✅ **Docker Build & Push** - Builds and pushes image to DockerHub
4. ✅ **Deploy to Minikube** - Deploys to Kubernetes

### Step 12: Verify Deployment

```bash
# Check if namespace was created
kubectl get namespace amazon-api

# Check if pods are running
kubectl get pods -n amazon-api

# Check deployment status
kubectl get deployment -n amazon-api

# Check service
kubectl get svc -n amazon-api

# View pod logs
kubectl logs -n amazon-api -l app=amazon-api-users --tail=50
```

---

## Phase 5: Test Your Application (5 minutes)

### Step 13: Access Your Application

**Option A: Port Forward**
```bash
kubectl port-forward -n amazon-api svc/amazon-api-users-service 8081:8081
```

**Option B: Minikube Service**
```bash
minikube service amazon-api-users-service -n amazon-api --url
```

### Step 14: Test the Endpoints

```bash
# Test hello world endpoint
curl http://localhost:8081/users-api

# Expected response:
# {"helloWorldMsg":"Hello World!!!"}

# Test health check endpoint
curl http://localhost:8081/users-api/hello

# Expected response:
# OK
```

### Step 15: View Your Image on DockerHub

```bash
# Open DockerHub in browser
xdg-open "https://hub.docker.com/r/$DOCKERHUB_USERNAME/amazon-api-users/tags" 2>/dev/null

# Or visit manually:
echo "https://hub.docker.com/r/$DOCKERHUB_USERNAME/amazon-api-users/tags"
```

---

## 🎉 Success Checklist

- [ ] Git repository initialized and committed
- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] Minikube cluster running
- [ ] Jenkins container running and accessible
- [ ] Jenkins credentials configured
- [ ] Jenkins pipeline job created
- [ ] First build completed successfully
- [ ] Docker image pushed to DockerHub
- [ ] Application deployed to Kubernetes
- [ ] Pods are running (`kubectl get pods -n amazon-api`)
- [ ] Application responds to HTTP requests
- [ ] Can see Docker image on DockerHub

---

## 🔄 Making Changes (Your Daily Workflow)

After initial setup, your workflow is:

```bash
# 1. Make code changes
cd amazon-api-users/src/main/java/...
# Edit files...

# 2. Commit and push
git add .
git commit -m "Add new feature"
git push origin master

# 3. Jenkins automatically detects changes and builds
# (Within 1-5 minutes depending on poll schedule)

# 4. Check Jenkins UI for build status
# http://localhost:8080

# 5. If build succeeds, new version is deployed automatically!
```

---

## 🚨 Common Issues & Solutions

### Issue: Jenkins can't checkout from GitHub
**Solution:**
```bash
# Verify git is accessible from Jenkins
docker exec -it amazon-api-jenkins git --version

# Check credentials
# Go to Jenkins → Manage Jenkins → Credentials
```

### Issue: Docker build fails in Jenkins
**Solution:**
```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock

# Verify Docker works in Jenkins
docker exec -it amazon-api-jenkins docker info
```

### Issue: Kubernetes deployment fails
**Solution:**
```bash
# Check kubectl access
docker exec -it amazon-api-jenkins kubectl get nodes

# Verify minikube is running
minikube status

# Check if ~/.kube is mounted
docker compose down
docker compose up -d
```

### Issue: Image push to DockerHub fails
**Solution:**
```bash
# Verify credentials in Jenkins
docker exec -it amazon-api-jenkins env | grep DOCKER

# Test Docker login manually
docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_TOKEN
```

### Issue: Warning about docker-compose.yml version attribute
**Solution:**
```bash
# The 'version' attribute in docker-compose.yml is now obsolete
# This is just a warning and won't affect functionality
# To remove the warning, edit docker-compose.yml and delete the first line:
# version: "3.8"
```

### Issue: Pod crashes or CrashLoopBackOff
**Solution:**
```bash
# Check pod logs
kubectl logs -n amazon-api <pod-name>

# Describe pod for events
kubectl describe pod -n amazon-api <pod-name>

# Common issue: Wrong image tag
kubectl get deployment -n amazon-api -o yaml | grep image:
```

---

## 📊 Monitoring Your Pipeline

```bash
# Watch Jenkins builds
# http://localhost:8080/job/amazon-api-users-pipeline/

# Watch Kubernetes resources
watch kubectl get all -n amazon-api

# Stream pod logs
kubectl logs -n amazon-api -l app=amazon-api-users -f

# View recent deployments
kubectl rollout history deployment/amazon-api-users-deployment -n amazon-api
```

---

## 🎯 Next Steps After Successful Setup

1. **Set up GitHub Webhooks** (instead of polling):
   - GitHub repo → Settings → Webhooks
   - Payload URL: `http://your-jenkins-url/github-webhook/`
   - Content type: `application/json`
   - Events: `Just the push event`

2. **Add More Tests**:
   - Unit tests
   - Integration tests
   - Test coverage reporting

3. **Improve Monitoring**:
   - Add Prometheus/Grafana
   - Set up alerts
   - Log aggregation

4. **Production Readiness**:
   - Migrate to Vault (see `VAULT_MIGRATION.md`)
   - Add staging environment
   - Implement blue-green deployment

---

## 📞 Need Help?

Check these files:
- **QUICKSTART.md** - Quick reference
- **README.md** - Complete documentation
- **VAULT_MIGRATION.md** - Production security setup

**Verify your setup anytime:**
```bash
./verify-setup.sh
```
