# Quick Start Guide

Get your Spring Boot Hello World app deployed with CI/CD in minutes!

## ✅ Prerequisites Check

```bash
# Run the verification script
./verify-setup.sh
```

If any issues are found, install the missing tools.

## 🚀 5-Minute Deployment

### 1. Generate Environment File (Already Done!)
```bash
# Your credentials are in ~/.zshrc
# .env file was already generated
cat .env  # Verify credentials are loaded
```

### 2. Start Jenkins
```bash
docker-compose up -d
docker logs -f amazon-api-jenkins  # Wait for "Jenkins is fully up and running"
```

**Access Jenkins**: http://localhost:8080
- Username: `admin`
- Password: (from your `.env` - check with `echo $JENKINS_ADMIN_PASSWORD`)

### 3. Start Minikube
```bash
minikube start
kubectl cluster-info  # Verify cluster is running
```

### 4. Test the App Locally (Optional)
```bash
cd amazon-api-users
./mvnw spring-boot:run
```

In another terminal:
```bash
curl http://localhost:8080/users-api
# Expected: {"helloWorldMsg":"Hello World!!!"}
```

### 5. Create Jenkins Pipeline

1. Go to Jenkins: http://localhost:8080
2. Click **"New Item"**
3. Enter name: `amazon-api-users-pipeline`
4. Select **"Pipeline"**, click **OK**
5. Scroll to **"Pipeline"** section:
   - **Definition**: "Pipeline script from SCM"
   - **SCM**: Git
   - **Repository URL**: `https://github.com/YOUR_USERNAME/amazon-store.git`
   - **Branch**: `*/master`
   - **Script Path**: `Jenkinsfile`
6. Click **Save**

### 6. Run the Pipeline

1. Click **"Build Now"**
2. Watch the pipeline execute:
   - ✅ Checkout code
   - ✅ Build & test with Maven
   - ✅ Build Docker image
   - ✅ Push to DockerHub
   - ✅ Deploy to Kubernetes

### 7. Test the Deployed App

```bash
# Get the service URL
minikube service amazon-api-users-service -n amazon-api --url

# Or use port-forward
kubectl port-forward -n amazon-api svc/amazon-api-users-service 8080:8080

# Test it
curl http://localhost:8080/users-api
# Expected: {"helloWorldMsg":"Hello World!!!"}

curl http://localhost:8080/users-api/hello
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
docker logs amazon-api-jenkins
# Check for errors
```

### Can't access Jenkins web UI
```bash
# Make sure port 8080 is free
sudo lsof -i :8080
```

### Minikube issues
```bash
minikube status
minikube delete  # If needed
minikube start
```

### Pipeline fails
```bash
# Check Jenkins logs
docker logs amazon-api-jenkins

# Verify credentials
docker exec -it amazon-api-jenkins env | grep DOCKER
```

### Pod not starting
```bash
kubectl describe pod -n amazon-api <pod-name>
kubectl logs -n amazon-api <pod-name>
```

## 📝 What's Next?

- [ ] Set up GitHub webhook for automatic builds
- [ ] Add integration tests
- [ ] Monitor with Prometheus/Grafana
- [ ] Migrate to HashiCorp Vault (see `VAULT_MIGRATION.md`)

## 📚 Documentation

- **README.md** - Complete documentation
- **CHANGES.md** - All fixes applied
- **VAULT_MIGRATION.md** - Production security setup
- **verify-setup.sh** - Environment verification

## 🔒 Security Reminders

- ⚠️ Never commit `.env` file
- 🔑 Rotate credentials every 90 days
- 📋 Review `VAULT_MIGRATION.md` for production
- 🛡️ Keep your `~/.zshrc` credentials secure

## 💡 Tips

**Regenerate .env file:**
```bash
./generate-env.sh
```

**Clean rebuild:**
```bash
docker-compose down
docker-compose up -d --build
```

**Reset Kubernetes:**
```bash
kubectl delete namespace amazon-api
bash k8s/deploy.sh
```

**View Jenkins initial admin password (if needed):**
```bash
docker exec amazon-api-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

**Need help?** Check the full documentation in `README.md`
