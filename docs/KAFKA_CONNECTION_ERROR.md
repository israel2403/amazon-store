# Kafka Connection Error - ENOTFOUND

## Problem

The notifications service was crashing with this error:

```
Error: getaddrinfo ENOTFOUND kafka-1.kafka-headless.amazon-api.svc.cluster.local
  code: 'ENOTFOUND',
  broker: 'kafka-1.kafka-headless.amazon-api.svc.cluster.local:9092',
```

## Root Cause

The `amazon-api` namespace (base namespace) had an outdated ConfigMap pointing to **in-cluster Kafka** servers that don't exist anymore:

```yaml
KAFKA_BROKERS: kafka-0.kafka-headless.amazon-api.svc.cluster.local:9092,kafka-1.kafka-headless.amazon-api.svc.cluster.local:9092,kafka-2.kafka-headless.amazon-api.svc.cluster.local:9092
```

The project was migrated to use **external Kafka clusters** running on Vagrant VMs:
- **Dev Kafka**: 192.168.1.77:9092-9094
- **Prod Kafka**: 192.168.1.77:9095-9097

However, only the `amazon-api-dev` and `amazon-api-prod` namespaces were updated. The base `amazon-api` namespace still had the old configuration.

## Solution

Update the ConfigMap in the `amazon-api` namespace to point to external Kafka:

```bash
# Update ConfigMap to use external Kafka (prod cluster)
kubectl patch configmap app-config -n amazon-api --type merge -p '{"data":{"KAFKA_BROKERS":"192.168.1.77:9095,192.168.1.77:9096,192.168.1.77:9097","KAFKA_CLIENT_ID":"amazon-store-base"}}'

# Restart notifications service to pick up changes
kubectl rollout restart -n amazon-api deployment/notifications-service

# Wait for deployment to complete
kubectl rollout status -n amazon-api deployment/notifications-service --timeout=2m

# Verify it's working
kubectl logs -n amazon-api -l app=notifications-service --tail=20
```

## Verification

After applying the fix, the logs should show:
```
Starting notifications-service in production mode
Log level: info
notifications-service listening on port 3000
```

And Kafka connections should go to `192.168.1.77` instead of `kafka-*.kafka-headless.amazon-api.svc.cluster.local`.

You may see warnings like:
```
[Runner] The group is rebalancing, re-joining
```

This is **normal** - it's Kafka consumer group coordination, not an error.

## Long-term Solution

Consider consolidating namespaces to avoid confusion:

### Option 1: Keep only dev and prod namespaces
```bash
# Delete the base namespace
kubectl delete namespace amazon-api

# Use only:
# - amazon-api-dev (development environment)
# - amazon-api-prod (production environment)
```

### Option 2: Keep base namespace for shared infrastructure
Use `amazon-api` namespace only for:
- Jenkins
- Vault
- PostgreSQL (if shared)

Deploy microservices only to `amazon-api-dev` and `amazon-api-prod`.

## Related Documentation

- [k8s/KAFKA_EXTERNAL_SETUP.md](../k8s/KAFKA_EXTERNAL_SETUP.md) - External Kafka configuration
- [k8s/KAFKA_INTEGRATION_COMPLETE.md](../k8s/KAFKA_INTEGRATION_COMPLETE.md) - Kafka integration details
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting guide

## Kafka Configuration Reference

| Namespace | Environment | Kafka Brokers | Client ID |
|-----------|-------------|---------------|-----------|
| `amazon-api` | Base/Prod | 192.168.1.77:9095-9097 | amazon-store-base |
| `amazon-api-dev` | Development | 192.168.1.77:9092-9094 | amazon-store-dev |
| `amazon-api-prod` | Production | 192.168.1.77:9095-9097 | amazon-store-prod |

All Kafka clusters run on Vagrant VMs with port forwarding to host machine at 192.168.1.77.

## Prevention

When adding new services or namespaces, always ensure:
1. ConfigMap has correct external Kafka broker addresses
2. No references to `kafka-*.kafka-headless.amazon-api.svc.cluster.local`
3. Test connection with `kubectl logs` after deployment
4. Verify in Kafka that consumer group appears

## Troubleshooting Commands

```bash
# Check current ConfigMap
kubectl get configmap app-config -n amazon-api -o yaml | grep KAFKA

# Check all pods in namespace
kubectl get pods -n amazon-api

# Check specific pod logs
kubectl logs -n amazon-api <pod-name> --tail=50

# Follow logs in real-time
kubectl logs -n amazon-api -l app=notifications-service -f

# Check if pod can reach external Kafka
kubectl exec -n amazon-api <pod-name> -- nc -zv 192.168.1.77 9095
```
