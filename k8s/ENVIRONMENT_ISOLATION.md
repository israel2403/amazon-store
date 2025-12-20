# Environment Isolation Architecture

This document describes the complete environment isolation architecture for the Amazon Store API platform.

## Overview

The infrastructure is now fully isolated between `dev` and `prod` environments using separate Kubernetes namespaces. Each environment has its own dedicated instances of all infrastructure components.

## Namespace Architecture

### Development Environment
- **Namespace**: `amazon-api-dev`
- **Kong Namespace**: `kong-dev`
- **Purpose**: Development, testing, and experimentation

### Production Environment
- **Namespace**: `amazon-api-prod`
- **Kong Namespace**: `kong-prod`
- **Purpose**: Production workloads

## Infrastructure Components

### Per-Environment Components

Each environment (dev/prod) has isolated instances of:

1. **PostgreSQL Database**
   - Separate database instance per environment
   - Independent data volumes (PVCs)
   - Environment-specific credentials (dev: K8s Secrets, prod: Vault)
   - DNS: `postgres.amazon-api-{env}.svc.cluster.local`

2. **Kafka Cluster**
   - Dev: Single broker (replicas=1, 5Gi storage)
   - Prod: HA cluster (replicas=3, 20Gi storage)
   - Separate volumes per environment
   - Environment-specific replication factors
   - DNS: `kafka-{n}.kafka-headless.amazon-api-{env}.svc.cluster.local`

3. **Application Services**
   - Users API
   - Orders API
   - Notifications Service
   - All configured with environment-specific resource limits

4. **Kong API Gateway**
   - Dev: `kong-dev` namespace (NodePort 30081/30444)
   - Prod: `kong-prod` namespace (NodePort 30080/30443)
   - Separate ingress controllers per environment

## Resource Configuration

### Development Environment
```
Applications: 1 replica, 50m CPU / 64Mi RAM
PostgreSQL: 1 replica, 100m CPU / 128Mi RAM, 5Gi storage
Kafka: 1 broker, 250m CPU / 512Mi RAM, 5Gi storage
Kong: 1 replica, reduced resources
```

### Production Environment
```
Applications: 3-5 replicas, 200m+ CPU / 256Mi+ RAM
PostgreSQL: 1 replica, 250m CPU / 256Mi RAM, 20Gi storage
Kafka: 3 brokers (HA), 500m CPU / 1Gi RAM, 20Gi storage
Kong: 3 replicas, production resources
```

## Secrets Management

### Development
- Uses Kubernetes native Secrets
- Located in `k8s/overlays/dev/secrets.yaml`
- Base64-encoded credentials
- Simple password-based authentication

### Production
- Uses HashiCorp Vault integration
- Dynamic secret injection
- Service accounts with Vault authentication
- Located in `k8s/overlays/prod/vault-auth.yaml`

## Network Isolation

### DNS Resolution
Services within each environment resolve using namespace-qualified DNS:
- **Dev**: `service-name.amazon-api-dev.svc.cluster.local`
- **Prod**: `service-name.amazon-api-prod.svc.cluster.local`

### Cross-Namespace Communication
By default, environments are isolated. However:
- Cross-namespace communication is possible if needed via fully-qualified DNS
- Network policies can be added for stricter isolation
- Kong gateways route external traffic to their respective environments

### External Access
- **Dev Kong**: `http://localhost:30081` (dev.amazon-api.local)
- **Prod Kong**: `http://localhost:30080` (api.amazon-store.com)

## Deployment

### Deploy Development Environment
```bash
kubectl apply -k k8s/overlays/dev/
kubectl apply -k k8s/infrastructure/kong/overlays/dev/
```

### Deploy Production Environment
```bash
kubectl apply -k k8s/overlays/prod/
kubectl apply -k k8s/infrastructure/kong/overlays/prod/
```

### Deploy Both Environments
```bash
# Deploy dev
kubectl apply -k k8s/overlays/dev/
kubectl apply -k k8s/infrastructure/kong/overlays/dev/

# Deploy prod
kubectl apply -k k8s/overlays/prod/
kubectl apply -k k8s/infrastructure/kong/overlays/prod/
```

## Verification

### Check Dev Environment
```bash
kubectl get all -n amazon-api-dev
kubectl get all -n kong-dev
kubectl get pvc -n amazon-api-dev
```

### Check Prod Environment
```bash
kubectl get all -n amazon-api-prod
kubectl get all -n kong-prod
kubectl get pvc -n amazon-api-prod
```

### Test Connectivity
```bash
# Dev environment
kubectl run -it --rm debug --image=busybox -n amazon-api-dev -- sh
  nslookup postgres.amazon-api-dev.svc.cluster.local
  nslookup kafka-0.kafka-headless.amazon-api-dev.svc.cluster.local

# Prod environment
kubectl run -it --rm debug --image=busybox -n amazon-api-prod -- sh
  nslookup postgres.amazon-api-prod.svc.cluster.local
  nslookup kafka-0.kafka-headless.amazon-api-prod.svc.cluster.local
```

## Configuration Changes

### Key Updates Made

1. **Base Infrastructure** (`k8s/base/` and `k8s/infrastructure/`)
   - Removed hardcoded `namespace: amazon-api` declarations
   - Now namespace is set by overlay kustomizations

2. **Dev Overlay** (`k8s/overlays/dev/`)
   - Added Kafka and PostgreSQL to kustomization bases
   - Created environment-specific patches for reduced resources
   - Updated ConfigMap with `amazon-api-dev` DNS names
   - Uses K8s Secrets for credentials

3. **Prod Overlay** (`k8s/overlays/prod/`)
   - Added Kafka and PostgreSQL to kustomization bases
   - Created HA configuration patches
   - Updated ConfigMap with `amazon-api-prod` DNS names
   - Uses Vault for secret management

4. **Kong Gateway**
   - Created separate Kong deployments in `kong-dev` and `kong-prod` namespaces
   - Different NodePort mappings to avoid conflicts
   - Environment-specific ingress configurations

## Benefits Achieved

✅ **Complete Isolation**: Dev and prod cannot interfere with each other
✅ **Independent Scaling**: Scale environments independently
✅ **Separate Data**: Each environment has its own databases and message queues
✅ **Simultaneous Access**: Access both environments concurrently
✅ **Volume Isolation**: Separate persistent volumes per environment
✅ **Secret Separation**: Dev uses K8s Secrets, Prod uses Vault
✅ **Cost Optimization**: Dev uses minimal resources, Prod uses HA configuration

## Migration Notes

If migrating from the previous shared infrastructure setup:

1. Backup any existing data from the shared `amazon-api` namespace
2. Deploy new environment-specific infrastructure
3. Migrate data to environment-specific databases
4. Update application configurations to use new DNS names
5. Test both environments thoroughly
6. Decommission old shared infrastructure

## Troubleshooting

### Pods can't connect to database
Check that the ConfigMap uses the correct namespace-qualified DNS:
```bash
kubectl get configmap app-config -n amazon-api-dev -o yaml
# Should show: postgres.amazon-api-dev.svc.cluster.local
```

### Kafka connection issues
Verify Kafka brokers are running and DNS is correct:
```bash
kubectl get pods -n amazon-api-dev -l app=kafka-kraft
kubectl logs -n amazon-api-dev kafka-0
```

### Cross-environment access not working
This is expected and by design. Each environment is isolated. If you need cross-environment communication, use fully-qualified DNS names.

## Future Enhancements

- Add NetworkPolicies for stricter isolation
- Implement RBAC per environment
- Add monitoring and alerting per environment
- Set up environment-specific CI/CD pipelines
- Configure separate backup strategies per environment
