# Kubernetes Configuration

This directory contains all Kubernetes manifests for the Amazon Store API project.

## 📁 Directory Structure

```
k8s/
├── base/                      # Shared/foundational resources
│   ├── namespace/            # Namespace definitions
│   │   └── namespace.yaml
│   └── postgres/             # PostgreSQL database
│       ├── postgres-pvc.yaml
│       ├── postgres-deployment.yaml
│       └── postgres-service.yaml
│
├── apps/                      # Application microservices
│   ├── users/                # Users microservice
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── orders/               # Orders microservice
│       ├── deployment.yaml
│       └── service.yaml
│
├── infrastructure/            # Infrastructure services
│   ├── vault/                # HashiCorp Vault
│   │   ├── vault-namespace.yaml
│   │   ├── vault-configmap.yaml
│   │   ├── vault-pvc.yaml
│   │   ├── vault-deployment.yaml
│   │   └── vault-service.yaml
│   ├── jenkins/              # Jenkins CI/CD
│   │   ├── jenkins-configmap.yaml
│   │   ├── jenkins-pvc.yaml
│   │   ├── jenkins-rbac.yaml
│   │   ├── jenkins-deployment.yaml
│   │   └── jenkins-service.yaml
│   └── kong/                 # Kong API Gateway
│       ├── kong-namespace.yaml
│       ├── kong-crds.yaml
│       ├── kong-rbac.yaml
│       ├── kong-deployment.yaml
│       └── kong-ingress.yaml
│
├── scripts/                   # Deployment and utility scripts
│   ├── deploy-all.sh         # Deploy entire infrastructure
│   ├── deploy-vault.sh       # Deploy Vault
│   ├── deploy-jenkins.sh     # Deploy Jenkins
│   ├── deploy-kong.sh        # Deploy Kong
│   ├── deploy-users.sh       # Deploy Users service
│   ├── deploy-orders.sh      # Deploy Orders service
│   ├── simple-test.sh        # Quick health check
│   └── test-all.sh           # Comprehensive tests
│
└── docs/                      # Documentation
    ├── CI_CD_SETUP.md        # CI/CD infrastructure guide
    ├── DEPLOYMENT_SUMMARY.md # Deployment overview
    └── KONG_SETUP.md         # Kong configuration guide
```

## 🚀 Quick Start

### Deploy Everything
```bash
cd k8s/scripts
./deploy-all.sh
```

### Deploy Individual Components
```bash
# Infrastructure
./deploy-vault.sh
./deploy-jenkins.sh
./deploy-kong.sh

# Applications
./deploy-users.sh
./deploy-orders.sh
```

### Test Deployment
```bash
./simple-test.sh
```

## 📦 Namespaces

- **amazon-api**: Main namespace for all application services
  - Users Service
  - Orders Service
  - PostgreSQL
  - Vault
  - Jenkins

- **kong**: Separate namespace for Kong API Gateway

## 🔧 Manual Deployment

### Using kubectl

Deploy a specific component:
```bash
# Deploy namespace
kubectl apply -f base/namespace/

# Deploy PostgreSQL
kubectl apply -f base/postgres/

# Deploy applications
kubectl apply -f apps/users/
kubectl apply -f apps/orders/

# Deploy infrastructure
kubectl apply -f infrastructure/vault/
kubectl apply -f infrastructure/jenkins/
kubectl apply -f infrastructure/kong/
```

### Using kustomize (recommended for production)

```bash
# Deploy all applications
kubectl apply -k overlays/production/

# Or for development
kubectl apply -k overlays/development/
```

## 📝 Configuration

All environment-specific configurations should be managed through:
- ConfigMaps (non-sensitive configuration)
- Secrets (sensitive data)
- Kustomize overlays (environment-specific variations)

## 🔍 Monitoring

Check status of all resources:
```bash
kubectl get all -n amazon-api
```

View logs:
```bash
kubectl logs -n amazon-api deployment/<deployment-name>
```

## 📚 Documentation

Detailed documentation is available in the `docs/` directory:
- [CI/CD Setup Guide](docs/CI_CD_SETUP.md)
- [Deployment Summary](docs/DEPLOYMENT_SUMMARY.md)
- [Kong Setup Guide](docs/KONG_SETUP.md)

## 🏗️ Adding New Services

1. Create a new directory under `apps/` or `infrastructure/`
2. Add your Kubernetes manifests (deployment, service, configmap, etc.)
3. Create a deployment script in `scripts/`
4. Update this README

## 🔐 Security Notes

- Never commit sensitive data to version control
- Use Kubernetes Secrets for sensitive configuration
- Consider using Vault for dynamic secrets management
- Review RBAC policies regularly
