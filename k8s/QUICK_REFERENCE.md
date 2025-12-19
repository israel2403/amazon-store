# Quick Reference Guide

## 📁 New Directory Structure

The k8s directory is now organized by component type:

### **base/** - Foundational resources
- `namespace/` - Main namespace definition
- `postgres/` - PostgreSQL database

### **apps/** - Application microservices  
- `users/` - Users service manifests
- `orders/` - Orders service manifests

### **infrastructure/** - Infrastructure services
- `vault/` - HashiCorp Vault for secrets
- `jenkins/` - CI/CD automation
- `kong/` - API Gateway (separate namespace)

### **overlays/** - Environment-specific configurations
- `development/` - Dev environment with reduced resources
- `production/` - Prod environment with HA and more resources

### **scripts/** - Deployment automation
All `.sh` scripts for deployment and testing

### **docs/** - Documentation
All `.md` documentation files

## 🚀 Common Commands

### Deploy with scripts (recommended for beginners)
```bash
cd k8s/scripts
./deploy-all.sh              # Deploy everything
./deploy-vault.sh            # Deploy Vault only
./simple-test.sh             # Run tests
```

### Deploy with kubectl (manual)
```bash
# Deploy individual components
kubectl apply -f apps/users/
kubectl apply -f infrastructure/vault/
kubectl apply -f base/postgres/
```

### Deploy with kustomize (recommended for production)
```bash
# Development environment
kubectl apply -k overlays/development/

# Production environment  
kubectl apply -k overlays/production/

# Specific component
kubectl apply -k apps/users/
kubectl apply -k infrastructure/jenkins/
```

## 📝 Adding New Components

### 1. Create directory structure
```bash
mkdir -p apps/new-service
# or
mkdir -p infrastructure/new-tool
```

### 2. Add manifests
```bash
# Create deployment.yaml, service.yaml, etc.
touch apps/new-service/{deployment,service,configmap}.yaml
```

### 3. Create kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: amazon-api

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
```

### 4. (Optional) Add deployment script
```bash
touch scripts/deploy-new-service.sh
chmod +x scripts/deploy-new-service.sh
```

### 5. Update overlays (if needed)
Add your new component to:
- `overlays/development/kustomization.yaml`
- `overlays/production/kustomization.yaml`

## 🎯 Deployment Patterns

### Pattern 1: Quick Deploy (Development)
Use scripts for quick iterations:
```bash
cd scripts
./deploy-vault.sh
./deploy-users.sh
```

### Pattern 2: Directory Deploy
Deploy entire directories:
```bash
kubectl apply -f apps/users/
kubectl apply -f infrastructure/vault/
```

### Pattern 3: Kustomize (Recommended)
Best for managing environments:
```bash
# Development
kubectl apply -k overlays/development/

# Production
kubectl apply -k overlays/production/
```

### Pattern 4: Selective Kustomize
Deploy specific components with kustomize:
```bash
kubectl apply -k apps/users/
kubectl apply -k base/postgres/
kubectl apply -k infrastructure/jenkins/
```

## 🔍 Finding Files

### By Component Type
- Applications: `apps/`
- Infrastructure: `infrastructure/`
- Database: `base/postgres/`
- Namespace: `base/namespace/`

### By File Type
- Deployments: `*/deployment.yaml`
- Services: `*/service.yaml`
- ConfigMaps: `*/*configmap.yaml`
- PVCs: `*/*pvc.yaml`
- Scripts: `scripts/*.sh`
- Docs: `docs/*.md`

### Search Examples
```bash
# Find all deployment files
find . -name "deployment.yaml"

# Find all kustomization files
find . -name "kustomization.yaml"

# Find vault-related files
find . -path "*/vault/*"

# List all scripts
ls scripts/
```

## 📊 Comparison: Old vs New

### Old Structure (flat)
```
k8s/
├── vault-deployment.yaml
├── vault-service.yaml
├── jenkins-deployment.yaml
├── jenkins-service.yaml
├── deployment.yaml          # Which app?
├── service.yaml             # Which service?
├── deploy-vault.sh
├── deploy-jenkins.sh
└── README.md
```
❌ Hard to find files  
❌ No organization  
❌ Doesn't scale well  

### New Structure (organized)
```
k8s/
├── infrastructure/
│   ├── vault/
│   │   ├── vault-deployment.yaml
│   │   └── vault-service.yaml
│   └── jenkins/
│       ├── jenkins-deployment.yaml
│       └── jenkins-service.yaml
├── apps/
│   ├── users/
│   └── orders/
├── scripts/
└── docs/
```
✅ Easy to find files  
✅ Logical organization  
✅ Scales well  
✅ Supports kustomize  

## 💡 Best Practices

1. **Use kustomize** for environment management
2. **Keep scripts** in `scripts/` directory
3. **Document** in `docs/` directory  
4. **Group by function** not by type
5. **Use kustomization.yaml** in each directory
6. **Test changes** in development overlay first

## 🆘 Need Help?

- Full guide: [README.md](README.md)
- CI/CD setup: [docs/CI_CD_SETUP.md](docs/CI_CD_SETUP.md)
- Deployment info: [docs/DEPLOYMENT_SUMMARY.md](docs/DEPLOYMENT_SUMMARY.md)
- Kong setup: [docs/KONG_SETUP.md](docs/KONG_SETUP.md)
