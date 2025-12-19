# Kafka Cluster Setup on Kubernetes

## Overview

This Kafka cluster is designed for production-grade event streaming with high availability and flexibility for future growth.

## Architecture

### Components
- **Zookeeper**: 3-node ensemble for cluster coordination
- **Kafka**: 3 broker cluster for high availability
- **Topics**: Pre-configured with proper replication and partitioning

### Key Features
✅ **High Availability**: 3 replicas for both Zookeeper and Kafka  
✅ **Fault Tolerance**: Survives 1 node failure without data loss  
✅ **Scalable**: Easy to add more topics and partitions  
✅ **Persistent Storage**: Uses PersistentVolumeClaims  
✅ **Auto-configured**: Topics created automatically on deployment  

## Cluster Specifications

### Kafka Brokers
- **Replicas**: 3 brokers (kafka-0, kafka-1, kafka-2)
- **Replication Factor**: 3 (all data replicated to all brokers)
- **Min In-Sync Replicas**: 2 (ensures durability)
- **Default Partitions**: 3 per topic
- **Storage**: 10Gi per broker
- **Resources**:
  - Request: 500m CPU, 1Gi RAM
  - Limit: 1000m CPU, 2Gi RAM

### Zookeeper
- **Replicas**: 3 nodes (zookeeper-0, zookeeper-1, zookeeper-2)
- **Storage**: 5Gi data + 5Gi logs per node
- **Resources**:
  - Request: 200m CPU, 512Mi RAM
  - Limit: 500m CPU, 1Gi RAM

## Pre-configured Topics

| Topic Name | Partitions | Replication | Retention | Use Case |
|------------|------------|-------------|-----------|----------|
| `order.created` | 3 | 3 | 7 days | Order creation events |
| `order.updated` | 3 | 3 | 7 days | Order updates |
| `user.created` | 3 | 3 | 7 days | User registration events |
| `notification.email` | 3 | 3 | 3 days | Email notifications queue |

## Deployment

### Quick Deploy
```bash
cd k8s/scripts
./deploy-kafka.sh
```

### Manual Deployment
```bash
# 1. Deploy Zookeeper
kubectl apply -f k8s/infrastructure/kafka/zookeeper-statefulset.yaml

# 2. Wait for Zookeeper
kubectl wait --for=condition=ready pod -l app=zookeeper -n amazon-api --timeout=180s

# 3. Deploy Kafka
kubectl apply -f k8s/infrastructure/kafka/kafka-statefulset.yaml

# 4. Wait for Kafka
kubectl wait --for=condition=ready pod -l app=kafka -n amazon-api --timeout=300s

# 5. Create topics
kubectl apply -f k8s/infrastructure/kafka/kafka-topics-job.yaml
```

### Using Kustomize
```bash
kubectl apply -k k8s/infrastructure/kafka/
```

## Connection Details

### From Within Kubernetes Cluster

**Individual Brokers:**
```
kafka-0.kafka-headless.amazon-api.svc.cluster.local:9092
kafka-1.kafka-headless.amazon-api.svc.cluster.local:9092
kafka-2.kafka-headless.amazon-api.svc.cluster.local:9092
```

**Service (load-balanced):**
```
kafka.amazon-api.svc.cluster.local:9092
```

### Recommended Connection String
For applications in the cluster (like notifications-service):
```
kafka-0.kafka-headless.amazon-api.svc.cluster.local:9092,kafka-1.kafka-headless.amazon-api.svc.cluster.local:9092,kafka-2.kafka-headless.amazon-api.svc.cluster.local:9092
```

This ensures the client can connect to any available broker.

## Managing Topics

### List Topics
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-topics --bootstrap-server localhost:9092 --list
```

### Describe Topic
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-topics --bootstrap-server localhost:9092 --describe --topic order.created
```

### Create New Topic
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-topics --bootstrap-server localhost:9092 --create \
  --topic your.new.topic \
  --partitions 3 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config min.insync.replicas=2
```

### Add Partitions to Existing Topic
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-topics --bootstrap-server localhost:9092 --alter \
  --topic order.created \
  --partitions 6
```

### Delete Topic
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-topics --bootstrap-server localhost:9092 --delete \
  --topic topic.to.delete
```

## Testing Kafka

### Produce Test Message
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-console-producer --bootstrap-server localhost:9092 \
  --topic order.created
```

Then type messages (one per line) and press Ctrl+D when done.

### Consume Messages
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic order.created \
  --from-beginning
```

### Check Consumer Groups
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 --list
```

### Describe Consumer Group
```bash
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
  --describe --group notifications-service-group
```

## Monitoring

### Check Cluster Status
```bash
# All Kafka pods
kubectl get pods -n amazon-api -l app=kafka

# All Zookeeper pods
kubectl get pods -n amazon-api -l app=zookeeper

# Services
kubectl get svc -n amazon-api | grep -E "kafka|zookeeper"
```

### View Logs
```bash
# Kafka broker logs
kubectl logs -n amazon-api kafka-0 -f

# Zookeeper logs
kubectl logs -n amazon-api zookeeper-0 -f
```

### Check Resource Usage
```bash
kubectl top pods -n amazon-api -l app=kafka
kubectl top pods -n amazon-api -l app=zookeeper
```

## Scaling

### Add More Kafka Brokers
```bash
kubectl scale statefulset kafka -n amazon-api --replicas=5
```

**Note**: After scaling, you may want to reassign partitions to balance load.

### Add More Zookeeper Nodes
Zookeeper should always have an odd number of nodes (3, 5, 7).

```bash
kubectl scale statefulset zookeeper -n amazon-api --replicas=5
```

## Notifications Service Integration

The notifications-service automatically connects to Kafka with:

```env
KAFKA_BROKERS=kafka-0.kafka-headless:9092,kafka-1.kafka-headless:9092,kafka-2.kafka-headless:9092
KAFKA_CLIENT_ID=notifications-service
KAFKA_GROUP_ID=notifications-service-group
KAFKA_TOPIC_ORDER_CREATED=order.created
```

Consumer configuration in code:
```typescript
const kafka = new Kafka({
  clientId: env.KAFKA_CLIENT_ID,
  brokers: kafkaBrokers,
  logLevel: logLevel.NOTHING
});
```

## Configuration Details

### Replication & Durability
- **Replication Factor**: 3 - Every message is stored on 3 brokers
- **Min ISR**: 2 - Writes succeed only if 2 replicas acknowledge
- **Ensures**: No data loss even if 1 broker fails

### Retention Policies
- **Order topics**: 7 days (604800000 ms)
- **Notification topics**: 3 days (259200000 ms)
- **Configurable** per topic via config changes

### Performance Tuning
Current settings optimize for:
- **Durability** over speed (min.insync.replicas=2)
- **Balanced throughput** (3 partitions per topic)
- **Reasonable retention** (7 days for events)

## Adding New Topics

### Option 1: Update Job (Recommended)
Edit `kafka-topics-job.yaml` and add:
```yaml
kafka-topics --bootstrap-server $KAFKA_BROKERS --create --if-not-exists \
  --topic your.new.topic --partitions 3 --replication-factor 3 \
  --config retention.ms=604800000 --config min.insync.replicas=2
```

Then redeploy the job:
```bash
kubectl delete job kafka-topics-init -n amazon-api
kubectl apply -f k8s/infrastructure/kafka/kafka-topics-job.yaml
```

### Option 2: Manual Creation
Use `kubectl exec` as shown in "Managing Topics" section above.

### Option 3: Auto-create
Kafka is configured with `auto.create.topics.enable=true`, so topics are created automatically when first used. However, this creates them with default settings (3 partitions, replication factor 3).

## Troubleshooting

### Kafka Pods Not Starting
```bash
# Check pod status
kubectl describe pod kafka-0 -n amazon-api

# Check logs
kubectl logs kafka-0 -n amazon-api
```

Common issues:
- Zookeeper not ready yet (wait for Zookeeper first)
- Insufficient resources
- PVC provisioning issues

### Connection Issues
```bash
# Test from within cluster
kubectl run kafka-test --rm -it --image=confluentinc/cp-kafka:7.5.0 \
  -n amazon-api -- bash

# Inside the pod:
kafka-topics --bootstrap-server kafka:9092 --list
```

### Broker Not in ISR
```bash
# Check topic health
kubectl exec -it kafka-0 -n amazon-api -- \
  kafka-topics --bootstrap-server localhost:9092 \
  --describe --under-replicated-partitions
```

### Zookeeper Issues
```bash
# Check Zookeeper status
kubectl exec -it zookeeper-0 -n amazon-api -- \
  bash -c 'echo ruok | nc localhost 2181'

# Should respond with: imok
```

## Best Practices

1. **Always use all broker addresses** in connection strings
2. **Set proper consumer group IDs** for each application
3. **Monitor consumer lag** regularly
4. **Test topic creation** in dev before production
5. **Backup topic configs** before making changes
6. **Use idempotent producers** when possible
7. **Implement proper error handling** in consumers

## Future Enhancements

- [ ] Add Kafka Manager/UI (AKHQ or Kafdrop)
- [ ] Implement Kafka Schema Registry
- [ ] Add Prometheus exporters for metrics
- [ ] Configure SSL/TLS encryption
- [ ] Implement SASL authentication
- [ ] Add rack awareness for AZ distribution
- [ ] Implement topic quotas

## Quick Reference

```bash
# Deploy Kafka
cd k8s/scripts && ./deploy-kafka.sh

# Check status
kubectl get pods -n amazon-api | grep kafka

# List topics
kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --list

# Scale brokers
kubectl scale sts kafka -n amazon-api --replicas=5

# View logs
kubectl logs -f kafka-0 -n amazon-api
```
