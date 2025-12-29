# Spring Profiles Configuration Guide

## Overview

Both **users** and **orders** services now have environment-specific Spring profiles that automatically configure the application based on the deployment environment.

## Available Profiles

### 1. **development** (Dev Environment in Kubernetes)
- DEBUG logging for all application code
- Smaller connection pool (5-10 connections)
- All management endpoints exposed
- Flyway baseline-on-migrate enabled
- PostgreSQL at `postgres.amazon-api.svc.cluster.local:5432`

### 2. **production** (Prod Environment in Kubernetes)
- INFO/WARN logging
- Large connection pool (10-50 connections)
- Limited management endpoints
- Flyway validation enabled
- PostgreSQL at `postgres.amazon-api.svc.cluster.local:5432`

### 3. **local** (Local Development on Your Machine)
- DEBUG logging
- Smaller connection pool
- PostgreSQL at `localhost:5432`
- Perfect for running services outside Kubernetes

## How It Works

### In Kubernetes (Automatic)

When you deploy to Kubernetes, the profile is **automatically set** by the ConfigMap:

```yaml
# Dev ConfigMap
SPRING_PROFILES_ACTIVE: "development"

# Prod ConfigMap
SPRING_PROFILES_ACTIVE: "production"
```

The deployment injects this into your pods:

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: SPRING_PROFILES_ACTIVE
```

**Deploy dev**: Services automatically use `development` profile
```bash
kubectl apply -k k8s/overlays/dev/
```

**Deploy prod**: Services automatically use `production` profile
```bash
kubectl apply -k k8s/overlays/prod/
```

### Running Locally (Manual)

When running services on your local machine (outside Kubernetes):

#### Option 1: Set environment variable
```bash
# Linux/Mac
export SPRING_PROFILES_ACTIVE=local
./mvnw spring-boot:run

# Windows
set SPRING_PROFILES_ACTIVE=local
mvnw.cmd spring-boot:run
```

#### Option 2: Pass as JVM argument
```bash
./mvnw spring-boot:run -Dspring-boot.run.arguments=--spring.profiles.active=local
```

#### Option 3: In IntelliJ/Eclipse
Add to Run Configuration:
```
VM options: -Dspring.profiles.active=local
```

## Configuration Differences

### Orders Service

| Setting | Development | Production | Local |
|---------|-------------|------------|-------|
| **Database URL** | postgres.amazon-api.svc.cluster.local | postgres.amazon-api.svc.cluster.local | localhost |
| **Pool Size** | 5-10 | 10-50 | 5-10 |
| **Logging Level** | DEBUG | INFO/WARN | DEBUG |
| **Flyway Baseline** | ✅ Enabled | ❌ Disabled | ✅ Enabled |
| **Flyway Validation** | ❌ Disabled | ✅ Enabled | ❌ Disabled |
| **Management Endpoints** | All exposed | Limited | All exposed |

### Users Service

| Setting | Development | Production | Local |
|---------|-------------|------------|-------|
| **Database URL** | postgres.amazon-api.svc.cluster.local | postgres.amazon-api.svc.cluster.local | localhost |
| **Database Name** | amazon_users | amazon_users | amazon_users |
| **Pool Size** | 5-10 | 10-50 | 5-10 |
| **Logging Level** | DEBUG | INFO/WARN | DEBUG |
| **Management Endpoints** | All exposed | Limited | All exposed |

## Example: application.yml Structure

```yaml
# Default configuration (fallback)
spring:
  application:
    name: amazonapi-orders
  r2dbc:
    url: ${SPRING_R2DBC_URL:r2dbc:postgresql://localhost:5432/amazon_orders}
    username: ${POSTGRES_USER:postgres}
    password: ${POSTGRES_PASSWORD:postgres}

server:
  port: 8082

---
# Development Profile
spring:
  config:
    activate:
      on-profile: development
  
  r2dbc:
    pool:
      initial-size: 5
      max-size: 10

logging:
  level:
    root: DEBUG

---
# Production Profile
spring:
  config:
    activate:
      on-profile: production
  
  r2dbc:
    pool:
      initial-size: 10
      max-size: 50

logging:
  level:
    root: INFO
```

## Verifying Active Profile

### Check in Logs
When the service starts, it will log:
```
The following profiles are active: development
```

### Via Management Endpoint (Dev only)
```bash
curl http://localhost:8082/actuator/env | jq '.activeProfiles'
```

### Inside Kubernetes Pod
```bash
kubectl exec -n amazon-api deployment/amazonapi-orders-deployment -- env | grep SPRING_PROFILES_ACTIVE
```

## Environment Variables Still Work!

Even with profiles, environment variables **override** the profile values:

```yaml
# In development profile:
spring:
  r2dbc:
    password: ${POSTGRES_PASSWORD:devpassword123}
```

If `POSTGRES_PASSWORD` environment variable is set, it will be used instead of `devpassword123`.

This means:
- ConfigMap provides non-sensitive config (DB_HOST, DB_PORT)
- Secrets provide sensitive config (POSTGRES_PASSWORD)
- Profile provides defaults and environment-specific settings

## Testing Different Profiles

### Test Development Profile
```bash
cd amazonapi-orders
SPRING_PROFILES_ACTIVE=development ./mvnw spring-boot:run
```

### Test Production Profile
```bash
cd amazonapi-orders
SPRING_PROFILES_ACTIVE=production \
POSTGRES_PASSWORD=test123 \
./mvnw spring-boot:run
```

### Test Local Profile
```bash
cd amazonapi-orders
SPRING_PROFILES_ACTIVE=local ./mvnw spring-boot:run
```

## Adding a New Profile

To add a new profile (e.g., `staging`):

1. **Add to application.yml**:
```yaml
---
# Staging Profile
spring:
  config:
    activate:
      on-profile: staging
  
  r2dbc:
    url: ${SPRING_R2DBC_URL:r2dbc:postgresql://postgres-staging:5432/amazon_orders}
    pool:
      initial-size: 8
      max-size: 30

logging:
  level:
    root: INFO
```

2. **Create ConfigMap** in `k8s/overlays/staging/configmap.yaml`:
```yaml
data:
  SPRING_PROFILES_ACTIVE: "staging"
  DB_HOST: "postgres-staging.amazon-api.svc.cluster.local"
  # ... other configs
```

3. **Deploy**:
```bash
kubectl apply -k k8s/overlays/staging/
```

## Troubleshooting

### Profile not loading
```bash
# Check environment variable is set
kubectl exec -n amazon-api deployment/amazonapi-orders-deployment -- env | grep SPRING_PROFILES_ACTIVE

# If missing, verify ConfigMap
kubectl get configmap -n amazon-api app-config -o yaml | grep SPRING_PROFILES_ACTIVE

# Restart deployment to pick up changes
kubectl rollout restart -n amazon-api deployment/amazonapi-orders-deployment
```

### Wrong database connection
```bash
# Check active profile in logs
kubectl logs -n amazon-api deployment/amazonapi-orders-deployment | grep "profiles are active"

# Verify environment variables
kubectl exec -n amazon-api deployment/amazonapi-orders-deployment -- env | grep -E "(SPRING_|DB_|POSTGRES_)"
```

### Local connection fails
Make sure PostgreSQL is running locally:
```bash
docker run -d \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=amazon_orders \
  -p 5432:5432 \
  postgres:16-alpine
```

## Best Practices

1. ✅ **Never hardcode passwords** in application.yml - use `${POSTGRES_PASSWORD}` placeholders
2. ✅ **Use `local` profile** for development on your machine
3. ✅ **Let Kubernetes set the profile** - don't hardcode in Dockerfile
4. ✅ **Test each profile** before deploying
5. ✅ **Keep profile-specific configs minimal** - most should come from environment variables

## Summary

| Environment | Profile | Set By | Database |
|-------------|---------|--------|----------|
| **Dev K8s** | development | ConfigMap | postgres.amazon-api... |
| **Prod K8s** | production | ConfigMap | postgres.amazon-api... |
| **Local Machine** | local | You manually | localhost |
| **CI/CD** | production | Pipeline env var | Depends on pipeline |

🎯 **Key Point**: When deployed to Kubernetes, services automatically get the right profile based on the overlay you deploy (dev vs prod). No manual intervention needed!
