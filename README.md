# Amazon Store API - Hello World Spring Boot with CI/CD

A simple Spring Boot "Hello World" application demonstrating a complete DevOps CI/CD pipeline using Jenkins, Docker, and Kubernetes (Minikube).

## 📋 Prerequisites

- **Java 21** (for local development)
- **Maven 3.9+** (for local development)
- **Docker** (for building and running containers)
- **Minikube** (for local Kubernetes cluster)
- **kubectl** (for Kubernetes cluster management)
- **Docker Hub account** (for storing Docker images)
- **GitHub account** (for source code repository)

## 🏗️ Project Structure

```
.
├── amazon-api-users/          # Spring Boot application
│   ├── src/
│   │   └── main/
│   │       └── java/.../
│   │           ├── AmazonApiUsersApplication.java
│   │           └── controller/UsersController.java
│   ├── Dockerfile             # Multi-stage Docker build
│   └── pom.xml               # Maven dependencies
├── jenkins/                   # Jenkins configuration
│   ├── Dockerfile            # Jenkins with Docker, kubectl, Maven
│   └── casc.yaml            # Jenkins Configuration as Code
├── k8s/                      # Kubernetes manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── deploy.sh            # Deployment script
├── docker-compose.yml        # Jenkins container setup
├── Jenkinsfile              # CI/CD pipeline definition
└── .env.example             # Environment variables template
```

## 🚀 Quick Start

### 1. Setup Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your actual credentials
# IMPORTANT: Never commit the .env file!
nano .env
```

Fill in:
- `GITHUB_USERNAME` and `GITHUB_TOKEN` (with repo access)
- `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
- `JENKINS_ADMIN_PASSWORD` (choose a secure password)

### 2. Start Jenkins

```bash
# Build and start Jenkins container
docker-compose up -d

# Wait for Jenkins to start (may take 1-2 minutes)
docker logs -f amazon-api-jenkins
```

Access Jenkins at: `http://localhost:8080`
- Username: `admin`
- Password: (from your `.env` file)

### 3. Setup Minikube

```bash
# Start Minikube cluster
minikube start

# Verify cluster is running
kubectl cluster-info
```

### 4. Create Jenkins Pipeline Job

1. Go to Jenkins → New Item
2. Enter name: `amazon-api-users-pipeline`
3. Select "Pipeline" and click OK
4. Under "Pipeline" section:
   - Definition: "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: `https://github.com/YOUR_USERNAME/amazon-store`
   - Branch: `*/master`
   - Script Path: `Jenkinsfile`
5. Check "GitHub hook trigger for GITScm polling" (optional)
6. Save

### 5. Run the Pipeline

Click "Build Now" in Jenkins. The pipeline will:
1. ✅ Checkout code from Git
2. ✅ Build and test with Maven
3. ✅ Build Docker image
4. ✅ Push to Docker Hub
5. ✅ Deploy to Minikube

## 🧪 Testing the Application

### Test the API endpoint:

```bash
# Get Minikube service URL
minikube service amazon-api-users-service -n amazon-api --url

# Or use port-forward
kubectl port-forward -n amazon-api svc/amazon-api-users-service 8080:8080

# Test the hello world endpoint
curl http://localhost:8080/users-api

# Expected response:
# {"helloWorldMsg":"Hello World!!!"}

# Test health check endpoint
curl http://localhost:8080/users-api/hello

# Expected response:
# OK
```

## 🔧 Local Development

### Run without Docker:

```bash
cd amazon-api-users
./mvnw spring-boot:run
```

### Build JAR:

```bash
cd amazon-api-users
./mvnw clean package
java -jar target/amazon-api-users-0.0.1-SNAPSHOT.jar
```

### Run tests:

```bash
cd amazon-api-users
./mvnw test
```

## 🐳 Docker Operations

### Build image manually:

```bash
cd amazon-api-users
docker build -t amazon-api-users:local .
```

### Run container locally:

```bash
docker run -p 8080:8080 amazon-api-users:local
```

## ☸️ Kubernetes Operations

### Deploy manually:

```bash
# Apply all manifests
bash k8s/deploy.sh

# Or apply individually
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Check deployment status:

```bash
# View pods
kubectl get pods -n amazon-api

# View service
kubectl get svc -n amazon-api

# View deployment
kubectl get deployment -n amazon-api

# Check pod logs
kubectl logs -n amazon-api -l app=amazon-api-users
```

### Scale deployment:

```bash
kubectl scale deployment amazon-api-users-deployment -n amazon-api --replicas=5
```

### Delete deployment:

```bash
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/service.yaml
# Or delete entire namespace
kubectl delete namespace amazon-api
```

## 📝 API Endpoints

| Endpoint | Method | Description | Response |
|----------|--------|-------------|----------|
| `/users-api` | GET | Hello World message | `{"helloWorldMsg":"Hello World!!!"}` |
| `/users-api/hello` | GET | Health check | `OK` |

## 🔐 Security Notes

### Current Setup (Development)
- ⚠️ **NEVER commit `.env` file** - it contains sensitive credentials
- 🔒 Credentials are stored in `~/.zshrc` and loaded via `generate-env.sh`
- 🔑 Rotate your tokens regularly
- 🛡️ This is suitable for local development only

### Future: HashiCorp Vault Integration

For production, migrate to HashiCorp Vault:

**Why Vault?**
- ✅ Centralized secret management
- ✅ Dynamic secrets with automatic rotation
- ✅ Audit logging of secret access
- ✅ Encryption at rest and in transit
- ✅ Fine-grained access control

**Migration Plan:**
1. Deploy Vault in Docker alongside Jenkins
2. Store secrets in Vault:
   ```bash
   vault kv put secret/amazon-api/github username=xxx token=xxx
   vault kv put secret/amazon-api/dockerhub username=xxx token=xxx
   ```
3. Update Jenkins to use Vault plugin
4. Configure Vault authentication for Jenkins
5. Update Jenkinsfile to fetch secrets from Vault:
   ```groovy
   environment {
       DOCKERHUB_CREDS = vault(
           path: 'secret/amazon-api/dockerhub',
           engineVersion: 2
       )
   }
   ```

**Vault with Docker Example:**
```yaml
# Add to docker-compose.yml
vault:
  image: vault:latest
  container_name: vault
  ports:
    - "8200:8200"
  environment:
    VAULT_DEV_ROOT_TOKEN_ID: myroot
    VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
  cap_add:
    - IPC_LOCK
```

## 🛠️ Troubleshooting

### Jenkins can't connect to Docker:

```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock
```

### Jenkins can't deploy to Kubernetes:

```bash
# Ensure kubectl config is accessible
docker exec -it amazon-api-jenkins kubectl get nodes
```

### Pod is CrashLooping:

```bash
# Check pod logs
kubectl logs -n amazon-api <pod-name>

# Describe pod for events
kubectl describe pod -n amazon-api <pod-name>
```

### Image pull errors:

```bash
# Verify image exists in Docker Hub
docker pull <your-username>/amazon-api-users:latest
```

## 📚 Technologies Used

- **Java 21** - Programming language
- **Spring Boot 4.0.0** - Application framework
- **Maven** - Build tool
- **Docker** - Containerization
- **Jenkins** - CI/CD automation
- **Kubernetes (Minikube)** - Container orchestration
- **Lombok** - Java library for reducing boilerplate

## 🎯 Next Steps

- [ ] Add database integration
- [ ] Implement proper user management
- [ ] Add integration tests
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Add Helm charts
- [ ] Implement blue-green deployment
- [ ] Add API documentation (Swagger/OpenAPI)

## 📄 License

This is a demo project for learning purposes.

## 👤 Author

Your Name - DevOps Learning Project
