# External Kafka Integration

## Overview
The Kubernetes services now use external Kafka clusters running on Vagrant VMs instead of in-cluster Kafka.

## Kafka Cluster Configuration

### Development Cluster
- **Bootstrap Servers:** `192.168.50.11:9092,192.168.50.12:9092,192.168.50.13:9092`
- **Cluster ID:** `Nv1oNOfsSziPm5aDjpRTxg`

| Broker | IP Address | Client Port | Controller Port | Hostname |
|--------|------------|-------------|-----------------|----------|
| Broker 1 | 192.168.50.11 | 9092 | 9093 | kafka-dev-1 |
| Broker 2 | 192.168.50.12 | 9092 | 9093 | kafka-dev-2 |
| Broker 3 | 192.168.50.13 | 9092 | 9093 | kafka-dev-3 |

### Production Cluster
- **Bootstrap Servers:** `192.168.50.21:9092,192.168.50.22:9092,192.168.50.23:9092`
- **Cluster ID:** `9ZiwT0fbRfyUUidryAyUZg`

| Broker | IP Address | Client Port | Controller Port | Hostname |
|--------|------------|-------------|-----------------|----------|
| Broker 1 | 192.168.50.21 | 9092 | 9093 | kafka-prod-1 |
| Broker 2 | 192.168.50.22 | 9092 | 9093 | kafka-prod-2 |
| Broker 3 | 192.168.50.23 | 9092 | 9093 | kafka-prod-3 |

## Starting the Kafka VMs

Make sure your Vagrant VMs are running before deploying services:

```bash
# Start all Kafka VMs (from your Vagrant directory)
vagrant up

# Or start specific clusters
vagrant up kafka-dev-1 kafka-dev-2 kafka-dev-3
vagrant up kafka-prod-1 kafka-prod-2 kafka-prod-3
```

## Verify Connectivity

### From Host Machine
```bash
# Test connection to dev cluster
nc -zv 192.168.50.11 9092
nc -zv 192.168.50.12 9092
nc -zv 192.168.50.13 9092

# Test connection to prod cluster
nc -zv 192.168.50.21 9092
nc -zv 192.168.50.22 9092
nc -zv 192.168.50.23 9092
```

### From Kubernetes Pods
```bash
# Test from a pod in dev namespace
kubectl run -it --rm debug --image=busybox --restart=Never -n amazon-api-dev -- \
  sh -c "nc -zv 192.168.50.11 9092"

# Test from a pod in prod namespace
kubectl run -it --rm debug --image=busybox --restart=Never -n amazon-api-prod -- \
  sh -c "nc -zv 192.168.50.21 9092"
```

## Creating Topics

### Development Topics
```bash
vagrant ssh kafka-dev-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic order.created \
  --bootstrap-server 192.168.50.11:9092,192.168.50.12:9092,192.168.50.13:9092 \
  --partitions 3 --replication-factor 3"

vagrant ssh kafka-dev-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic order.updated \
  --bootstrap-server 192.168.50.11:9092,192.168.50.12:9092,192.168.50.13:9092 \
  --partitions 3 --replication-factor 3"

vagrant ssh kafka-dev-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic user.created \
  --bootstrap-server 192.168.50.11:9092,192.168.50.12:9092,192.168.50.13:9092 \
  --partitions 3 --replication-factor 3"

vagrant ssh kafka-dev-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic notification.email \
  --bootstrap-server 192.168.50.11:9092,192.168.50.12:9092,192.168.50.13:9092 \
  --partitions 3 --replication-factor 3"
```

### Production Topics
```bash
vagrant ssh kafka-prod-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic order.created \
  --bootstrap-server 192.168.50.21:9092,192.168.50.22:9092,192.168.50.23:9092 \
  --partitions 3 --replication-factor 3"

vagrant ssh kafka-prod-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic order.updated \
  --bootstrap-server 192.168.50.21:9092,192.168.50.22:9092,192.168.50.23:9092 \
  --partitions 3 --replication-factor 3"

vagrant ssh kafka-prod-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic user.created \
  --bootstrap-server 192.168.50.21:9092,192.168.50.22:9092,192.168.50.23:9092 \
  --partitions 3 --replication-factor 3"

vagrant ssh kafka-prod-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --create --topic notification.email \
  --bootstrap-server 192.168.50.21:9092,192.168.50.22:9092,192.168.50.23:9092 \
  --partitions 3 --replication-factor 3"
```

## List Topics
```bash
# Dev
vagrant ssh kafka-dev-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --list --bootstrap-server 192.168.50.11:9092"

# Prod
vagrant ssh kafka-prod-1 -c "/opt/kafka/kafka_2.13-3.6.1/bin/kafka-topics.sh \
  --list --bootstrap-server 192.168.50.21:9092"
```

## Kubernetes Configuration

The following resources have been configured:

### ConfigMaps
- `k8s/overlays/dev/configmap.yaml` - Updated with dev Kafka bootstrap servers
- `k8s/overlays/prod/configmap.yaml` - Updated with prod Kafka bootstrap servers

### External Endpoints
- `k8s/overlays/dev/kafka-external-endpoints.yaml` - Service and Endpoints for dev Kafka cluster
- `k8s/overlays/prod/kafka-external-endpoints.yaml` - Service and Endpoints for prod Kafka cluster

These create headless services that map to the external Kafka broker IPs.

## Deploying Services

After starting the Kafka VMs:

```bash
# Deploy dev environment
kubectl apply -k k8s/overlays/dev/

# Deploy prod environment
kubectl apply -k k8s/overlays/prod/

# Restart notification services to pick up new config
kubectl rollout restart deployment/notifications-service -n amazon-api-dev
kubectl rollout restart deployment/notifications-service -n amazon-api-prod
```

## Troubleshooting

### Services Can't Connect to Kafka

1. **Verify VMs are running:**
   ```bash
   vagrant status
   ```

2. **Check network connectivity from host:**
   ```bash
   ping 192.168.50.11
   ping 192.168.50.21
   ```

3. **Check Kafka is listening:**
   ```bash
   vagrant ssh kafka-dev-1 -c "ss -tlnp | grep 9092"
   ```

4. **Check pod logs:**
   ```bash
   kubectl logs -n amazon-api-prod deployment/notifications-service
   ```

### Network Routing Issues

If pods can't reach the Kafka VMs, you may need to:

1. **Configure host routing** (if Minikube is on a different network)
2. **Use NodePort services** to expose Kafka through the host
3. **Set up port forwarding** from Minikube to host to Vagrant VMs

## Removed Resources

All in-cluster Kafka resources have been removed:
- Kafka StatefulSets
- Kafka Services (kafka, kafka-headless)
- Kafka PVCs
- Kafka infrastructure from kustomization files
- Kafka patches (kafka-dev-patch.yaml, kafka-prod-patch.yaml, kafka-topics-*-patch.yaml)
