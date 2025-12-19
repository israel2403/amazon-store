# Kafka Cluster - Quick Reference

## Deploy

```bash
cd k8s/scripts
./deploy-kafka.sh
```

## Check Status

```bash
kubectl get pods -n amazon-api | grep -E "kafka|zookeeper"
```

## Connection String

```
kafka-0.kafka-headless.amazon-api.svc.cluster.local:9092,kafka-1.kafka-headless.amazon-api.svc.cluster.local:9092,kafka-2.kafka-headless.amazon-api.svc.cluster.local:9092
```

## Common Commands

### List topics
```bash
kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --list
```

### Create topic
```bash
kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --create \
  --topic my.new.topic --partitions 3 --replication-factor 3
```

### Describe topic
```bash
kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --describe --topic order.created
```

### Produce message
```bash
kubectl exec -it kafka-0 -n amazon-api -- kafka-console-producer --bootstrap-server localhost:9092 --topic order.created
```

### Consume messages
```bash
kubectl exec -it kafka-0 -n amazon-api -- kafka-console-consumer --bootstrap-server localhost:9092 --topic order.created --from-beginning
```

### List consumer groups
```bash
kubectl exec kafka-0 -n amazon-api -- kafka-consumer-groups --bootstrap-server localhost:9092 --list
```

### Scale brokers
```bash
kubectl scale sts kafka -n amazon-api --replicas=5
```

## Configuration

- **Brokers**: 3
- **Replication Factor**: 3
- **Min ISR**: 2
- **Default Partitions**: 3

## Pre-configured Topics

| Topic | Partitions | Replication | Retention |
|-------|------------|-------------|-----------|
| order.created | 3 | 3 | 7 days |
| order.updated | 3 | 3 | 7 days |
| user.created | 3 | 3 | 7 days |
| notification.email | 3 | 3 | 3 days |

## Full Documentation

See [k8s/docs/KAFKA_SETUP.md](../../docs/KAFKA_SETUP.md) for complete guide.
