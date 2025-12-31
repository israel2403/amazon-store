# MySQL Configuration for Amazon Users Service

MySQL database has been configured for the Users service with separate configurations for development and production environments.

## Architecture

```
amazon-users-service
         │
         ├─→ Dev: mysql.amazon-api-dev.svc.cluster.local:3306
         │         Database: amazon_users
         │         Resources: 100m CPU, 256Mi RAM
         │         Storage: 1Gi
         │
         └─→ Prod: mysql.amazon-api-prod.svc.cluster.local:3306
                   Database: amazon_users
                   Resources: 250m CPU, 512Mi RAM
                   Storage: 20Gi
```

## Files Created

### Base Configuration (k8s/base/mysql/)
- `mysql-deployment.yaml` - MySQL 8.0 deployment
- `mysql-service.yaml` - ClusterIP service on port 3306
- `mysql-pvc.yaml` - Persistent volume claim (1Gi default)

### Development Overlay (k8s/overlays/dev/)
- `mysql-dev-patch.yaml` - Lower resources for development
- Added to `kustomization.yaml` bases and patches
- Updated `secrets.yaml` with MySQL credentials
- Updated `configmap.yaml` with MySQL connection details

### Production Overlay (k8s/overlays/prod/)
- `mysql-prod-patch.yaml` - Higher resources and 20Gi storage
- Added to `kustomization.yaml` bases and patches
- Updated `configmap.yaml` with MySQL connection details

## Credentials

### Development (amazon-api-dev)
```
MYSQL_USER: mysql
MYSQL_PASSWORD: devpassword123
MYSQL_ROOT_PASSWORD: rootpassword123
Database: amazon_users
```

### Production (amazon-api-prod)
Credentials should be managed via Vault. Update Vault with:

```bash
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv put kv/amazon-api/mysql user=mysql password=YOUR_PROD_PASSWORD root_password=YOUR_ROOT_PASSWORD"
```

## Deployment

### Deploy to Development
```bash
kubectl apply -k k8s/overlays/dev/

# Check MySQL status
kubectl get pods -n amazon-api-dev -l app=mysql
kubectl logs -n amazon-api-dev -l app=mysql --tail=50

# Verify service
kubectl get svc -n amazon-api-dev mysql
```

### Deploy to Production
```bash
kubectl apply -k k8s/overlays/prod/

# Check MySQL status
kubectl get pods -n amazon-api-prod -l app=mysql
kubectl logs -n amazon-api-prod -l app=mysql --tail=50

# Verify service
kubectl get svc -n amazon-api-prod mysql
```

## Connection from Users Service

The users service will connect using these environment variables:

```yaml
env:
  - name: MYSQL_HOST
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: MYSQL_HOST
  - name: MYSQL_PORT
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: MYSQL_PORT
  - name: MYSQL_DATABASE
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: MYSQL_DATABASE
  - name: MYSQL_USER
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: MYSQL_USER
  - name: MYSQL_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: MYSQL_PASSWORD
```

### Spring Boot Configuration

Update `application-development.yml` and `application-production.yml`:

```yaml
spring:
  datasource:
    url: jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
    username: ${MYSQL_USER}
    password: ${MYSQL_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
  
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    database-platform: org.hibernate.dialect.MySQL8Dialect
  
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
```

Add Maven dependency to `pom.xml`:

```xml
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <scope>runtime</scope>
</dependency>
```

## Testing Connection

### From within the cluster
```bash
# Get MySQL pod name
MYSQL_POD=$(kubectl get pod -n amazon-api-dev -l app=mysql -o jsonpath='{.items[0].metadata.name}')

# Connect to MySQL
kubectl exec -it -n amazon-api-dev $MYSQL_POD -- mysql -u mysql -pdevpassword123 amazon_users

# Test queries
mysql> SHOW DATABASES;
mysql> USE amazon_users;
mysql> SHOW TABLES;
```

### Port-forward for local access
```bash
kubectl port-forward -n amazon-api-dev svc/mysql 3306:3306

# Connect from local machine
mysql -h 127.0.0.1 -u mysql -pdevpassword123 amazon_users
```

## Resource Configuration

### Development Environment
- CPU Request: 100m
- CPU Limit: 250m
- Memory Request: 256Mi
- Memory Limit: 512Mi
- Storage: 1Gi

### Production Environment
- CPU Request: 250m
- CPU Limit: 500m
- Memory Request: 512Mi
- Memory Limit: 1Gi
- Storage: 20Gi

## Health Checks

MySQL deployment includes:

**Liveness Probe:**
- Command: `mysqladmin ping -h localhost`
- Initial Delay: 30s
- Period: 10s
- Timeout: 5s

**Readiness Probe:**
- Command: `mysqladmin ping -h localhost`
- Initial Delay: 10s
- Period: 5s
- Timeout: 5s

## Troubleshooting

### MySQL pod not starting
```bash
kubectl describe pod -n amazon-api-dev <mysql-pod-name>
kubectl logs -n amazon-api-dev <mysql-pod-name>
```

### Connection refused
```bash
# Check if service is running
kubectl get svc -n amazon-api-dev mysql

# Check if pod is ready
kubectl get pods -n amazon-api-dev -l app=mysql

# Test from another pod
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -n amazon-api-dev -- mysql -h mysql.amazon-api-dev.svc.cluster.local -u mysql -pdevpassword123
```

### Check MySQL configuration
```bash
MYSQL_POD=$(kubectl get pod -n amazon-api-dev -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n amazon-api-dev $MYSQL_POD -- mysql -u root -prootpassword123 -e "SHOW VARIABLES LIKE '%version%';"
```

## Backup and Restore

### Backup
```bash
MYSQL_POD=$(kubectl get pod -n amazon-api-dev -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n amazon-api-dev $MYSQL_POD -- mysqldump -u root -prootpassword123 amazon_users > backup.sql
```

### Restore
```bash
MYSQL_POD=$(kubectl get pod -n amazon-api-dev -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -i -n amazon-api-dev $MYSQL_POD -- mysql -u root -prootpassword123 amazon_users < backup.sql
```

## Security Notes

- ⚠️ Development credentials are base64-encoded in secrets (not encrypted)
- 🔐 Production should use Vault for credential management
- 🔑 Change default passwords before deploying to production
- 🛡️ Consider enabling SSL/TLS for production MySQL connections
- 📋 Rotate passwords regularly (every 90 days)

## Migration from PostgreSQL

If migrating users data from PostgreSQL to MySQL:

1. Export data from PostgreSQL
2. Convert schema (PostgreSQL → MySQL syntax differences)
3. Import into MySQL
4. Update users-service configuration
5. Test thoroughly before switching

## Related Documentation

- [PostgreSQL Setup](../k8s/base/postgres/) - Similar setup for Orders service
- [Vault Documentation](../docs/VAULT.md) - Credential management
- [ConfigMap Guide](../k8s/ENV_CONFIG_GUIDE.md) - Environment configuration
