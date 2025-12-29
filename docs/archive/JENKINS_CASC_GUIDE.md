# Jenkins Configuration as Code (JCasC) Guide

## Overview

Your Jenkins instance is now configured using **Configuration as Code (JCasC)**. This means:
- ✅ **Pipelines are created automatically** when Jenkins starts
- ✅ No manual job creation needed
- ✅ Jobs are defined in code (version controlled)
- ✅ Consistent setup across environments

## What Was Configured

### Automatic Pipeline Creation

When Jenkins starts, it **automatically creates** two multibranch pipelines:

1. **amazon-api-users** - Users microservice pipeline
2. **amazonapi-orders** - Orders microservice pipeline

Both pipelines:
- Monitor your GitHub repository
- Track branches: `master`, `main`, `develop`, `feature/*`
- Use the Jenkinsfile in each service directory
- Auto-discover and build new branches

## Pipeline Behavior

### Branch-Based Deployment

| Branch | Builds | Tests | Pushes Docker | Deploys To |
|--------|--------|-------|---------------|------------|
| `develop` | ✅ | ✅ | ✅ | **Development** (dev profile) |
| `master`/`main` | ✅ | ✅ | ✅ | **Production** (production profile) |
| `feature/*` | ✅ | ✅ | ❌ | ❌ None |

### Deployment Details

**Development Branch (`develop`)**:
```bash
→ kubectl apply -k k8s/overlays/dev/
→ Services use: development Spring profile
→ ConfigMap: 1 Kafka broker, DEBUG logs, dev secrets
```

**Production Branch (`master`/`main`)**:
```bash
→ kubectl apply -k k8s/overlays/prod/
→ Services use: production Spring profile
→ ConfigMap: 3 Kafka brokers, INFO logs, Vault secrets
```

## Accessing Jenkins

### 1. Get Jenkins URL

```bash
# Port-forward to access Jenkins
kubectl port-forward -n amazon-api svc/jenkins 8080:8080

# Access in browser
open http://localhost:8080
```

### 2. Login Credentials

```bash
# Get admin username
kubectl get secret -n amazon-api jenkins-secrets -o jsonpath='{.data.admin-user}' | base64 -d

# Get admin password
kubectl get secret -n amazon-api jenkins-secrets -o jsonpath='{.data.admin-password}' | base64 -d
```

Default credentials (if not changed):
- Username: `admin`
- Password: `admin123`

### 3. View Auto-Created Pipelines

Once logged in, you'll see:
- **amazon-api-users** pipeline (already configured)
- **amazonapi-orders** pipeline (already configured)

Click on any pipeline to:
- See all discovered branches
- Trigger builds manually
- View build history
- Check console output

## Jenkins Configuration Structure

### JCasC Configuration File

Location: `k8s/infrastructure/jenkins/jenkins-configmap.yaml`

```yaml
jenkins:
  systemMessage: "Amazon Store API - Jenkins CI/CD"
  numExecutors: 2
  securityRealm:
    local:
      users:
        - id: ${JENKINS_ADMIN_USER}
          password: ${JENKINS_ADMIN_PASSWORD}

credentials:
  system:
    domainCredentials:
      - credentials:
          - vaultTokenCredential:
              id: "vault-root-token"
              token: ${VAULT_ROOT_TOKEN}

jobs:
  - script: >
      multibranchPipelineJob('amazon-api-users') {
        branchSources {
          git {
            remote('https://github.com/israel2403/amazon-store.git')
            includes('master main develop feature/*')
          }
        }
        configure {
          scriptPath('amazon-api-users/Jenkinsfile')
        }
      }
```

### Pipeline Files

Each service has its own Jenkinsfile:
- `amazon-api-users/Jenkinsfile` - Users service pipeline
- `amazonapi-orders/Jenkinsfile` - Orders service pipeline

## Pipeline Workflow

### 1. Code Push Triggers Build

```
Developer pushes to GitHub
    ↓
Jenkins detects change (webhooks or polling)
    ↓
Pipeline starts automatically
```

### 2. Build Stages

```
Stage 1: Load Vault Secrets
  ├─ DOCKERHUB_USERNAME
  ├─ DOCKERHUB_TOKEN
  └─ POSTGRES credentials (orders only)

Stage 2: Build & Test
  ├─ Users: mvn clean package
  └─ Orders: ./gradlew clean build

Stage 3: Docker Build & Push (if master/main/develop)
  ├─ Build image with build number tag
  ├─ Tag as :latest
  └─ Push to DockerHub

Stage 4: Deploy to Development (if develop branch)
  ├─ kubectl apply -k k8s/overlays/dev/
  └─ Restart deployment with new image

Stage 5: Deploy to Production (if master/main branch)
  ├─ kubectl apply -k k8s/overlays/prod/
  └─ Restart deployment with new image
```

### 3. Deployment with Spring Profiles

When Jenkins deploys:

**Development branch** → `kubectl apply -k k8s/overlays/dev/`
```yaml
ConfigMap sets:
  SPRING_PROFILES_ACTIVE: "development"
  KAFKA_BROKERS: "kafka-0..." (1 broker)
  LOG_LEVEL: "debug"

Result:
  → Services use development profile
  → DEBUG logging
  → Small connection pool (5-10)
  → Dev database credentials
```

**Production branch** → `kubectl apply -k k8s/overlays/prod/`
```yaml
ConfigMap sets:
  SPRING_PROFILES_ACTIVE: "production"
  KAFKA_BROKERS: "kafka-0,kafka-1,kafka-2..." (3 brokers)
  LOG_LEVEL: "info"

Result:
  → Services use production profile
  → INFO/WARN logging
  → Large connection pool (10-50)
  → Vault-managed credentials
```

## Spring Profiles Impact on Jenkins

✅ **No breaking changes** to Jenkins pipelines!

The Spring profile changes work seamlessly with Jenkins because:

1. **ConfigMaps already existed** - We just added `SPRING_PROFILES_ACTIVE`
2. **Deployments already inject ConfigMaps** - No new mechanism needed
3. **Environment variables work the same** - Springs reads from env vars
4. **Kustomize overlays handle everything** - Jenkins just deploys with kustomize

### What Jenkins Does

```bash
# Jenkins runs this (same as before):
kubectl apply -k k8s/overlays/dev/

# Kustomize automatically:
# 1. Merges base + dev overlay
# 2. Creates ConfigMap with SPRING_PROFILES_ACTIVE=development
# 3. Injects into pods
# 4. Spring Boot reads profile and configures itself
```

## Adding a New Service Pipeline

To add a new service (e.g., `notifications`):

### 1. Update JCasC ConfigMap

Edit `k8s/infrastructure/jenkins/jenkins-configmap.yaml`:

```yaml
jobs:
  # Existing jobs...
  
  - script: >
      multibranchPipelineJob('notifications-service') {
        displayName('Notifications Service')
        description('Pipeline for Notifications microservice')
        branchSources {
          git {
            id('notifications-repo')
            remote('https://github.com/israel2403/amazon-store.git')
            includes('master main develop feature/*')
          }
        }
        orphanedItemStrategy {
          discardOldItems {
            numToKeep(10)
          }
        }
        configure {
          it / factory(class: 'org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory') {
            owner(class: 'org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject', plugin: 'workflow-multibranch')
            scriptPath('notifications-service/Jenkinsfile')
          }
        }
      }
```

### 2. Create Jenkinsfile

Create `notifications-service/Jenkinsfile` (copy from users/orders and adapt).

### 3. Redeploy Jenkins

```bash
kubectl apply -k k8s/overlays/dev/
kubectl rollout restart -n amazon-api deployment/jenkins
```

New pipeline appears automatically!

## Modifying Pipelines

### Option 1: Edit ConfigMap (For structure changes)

Edit `k8s/infrastructure/jenkins/jenkins-configmap.yaml`:
```bash
kubectl apply -f k8s/infrastructure/jenkins/jenkins-configmap.yaml
kubectl rollout restart -n amazon-api deployment/jenkins
```

### Option 2: Edit Jenkinsfile (For pipeline logic)

Edit service Jenkinsfile directly:
- `amazon-api-users/Jenkinsfile`
- `amazonapi-orders/Jenkinsfile`

Push to GitHub. Jenkins will use the new Jenkinsfile on next build.

## Troubleshooting

### Pipelines Not Appearing

```bash
# Check Jenkins logs
kubectl logs -n amazon-api deployment/jenkins -f

# Look for JCasC loading messages
# Should see: "Configuration as Code plugin initialization"

# Verify ConfigMap is mounted
kubectl describe pod -n amazon-api -l app=jenkins | grep casc.yaml
```

### Pipeline Fails to Deploy

```bash
# Check if kubectl works inside Jenkins
kubectl exec -n amazon-api deployment/jenkins -- kubectl get pods -n amazon-api

# Verify service account has permissions
kubectl describe sa -n amazon-api jenkins

# Check RBAC
kubectl describe clusterrolebinding jenkins-admin
```

### Vault Secrets Not Loading

```bash
# Verify Vault token in Jenkins
kubectl get secret -n amazon-api jenkins-secrets -o yaml

# Test Vault connection from Jenkins pod
kubectl exec -n amazon-api deployment/jenkins -- \
  curl -H "X-Vault-Token: \$VAULT_ROOT_TOKEN" \
  http://vault.amazon-api.svc.cluster.local:8200/v1/kv/amazon-api/dockerhub
```

### Branch Not Building

```bash
# Check branch discovery settings in Jenkins UI
# Dashboard → Job → Configure → Branch Sources

# Verify branch name matches includes pattern
# Pattern: master main develop feature/*
```

## Best Practices

### 1. Use Multibranch Pipelines
✅ Auto-discovers branches
✅ Builds PRs automatically
✅ Cleans up old branches

### 2. Branch Strategy
- `feature/*` → Build + test only
- `develop` → Build + test + deploy to dev
- `master`/`main` → Build + test + deploy to prod

### 3. ConfigMap Management
- Keep JCasC config in version control
- Document pipeline changes in commits
- Test changes in dev before prod

### 4. Secrets Management
- Never put secrets in Jenkinsfile
- Use Vault for credentials
- Use Kubernetes Secrets as fallback

## Configuration Files Reference

```
k8s/infrastructure/jenkins/
├── jenkins-configmap.yaml         ← JCasC configuration
├── jenkins-deployment.yaml        ← Jenkins deployment
├── jenkins-rbac.yaml             ← Permissions
├── jenkins-pvc.yaml              ← Persistent storage
└── jenkins-service.yaml          ← Service exposure

amazon-api-users/
└── Jenkinsfile                   ← Users pipeline

amazonapi-orders/
└── Jenkinsfile                   ← Orders pipeline
```

## Summary

### Before (Manual Setup)
1. Log into Jenkins UI
2. Click "New Item"
3. Configure job manually
4. Set up GitHub repo
5. Configure build triggers
6. Set up deployment steps

### After (JCasC) ✅
1. Deploy Jenkins: `kubectl apply -k k8s/overlays/dev/`
2. **Pipelines are already there!**
3. Push code → Builds start automatically
4. Branch-based deployment to dev/prod

### Key Benefits
- ✅ **Zero manual configuration** - Pipelines created automatically
- ✅ **Infrastructure as Code** - Everything version controlled
- ✅ **Consistent environments** - Same setup every time
- ✅ **Easy to replicate** - Deploy Jenkins anywhere with same config
- ✅ **Self-documenting** - Configuration is the documentation

🎉 **Open Jenkins GUI → Pipelines are already configured and ready to use!**
