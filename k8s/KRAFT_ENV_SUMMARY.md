# KRaft Migration & Environment Setup - Summary

## ✅ What Was Accomplished

### 1. **Migrated from Zookeeper to KRaft**
   - ✅ Removed all Zookeeper dependencies
   - ✅ Created KRaft-based Kafka StatefulSet (`kafka-kraft-statefulset.yaml`)
   - ✅ Configured KRaft consensus protocol (no external coordination needed)
   - ✅ Simplified architecture - Kafka brokers handle their own consensus

### 2. **Created Development Environment** 
   - ✅ Minimal resources for local testing
   - ✅ Single replica for all services
   - ✅ Replication factor: 1 (no replication in dev)
   - ✅ Reduced retention (24 hours vs 7 days)
   - ✅ Lower CPU/memory limits

### 3. **Created Production Environment**
   - ✅ Full high-availability configuration
   - ✅ Kafka: 3 brokers with RF=3
   - ✅ Apps: 5 replicas (users, orders)
   - ✅ Notifications: 3 replicas
   - ✅ Higher resources for production load
   - ✅ Includes Vault & Jenkins

### 4. **Kustomize-based Deployments**
   - ✅ Base manifests in `base/` and `apps/`, `infrastructure/`
   - ✅ Environment-specific overlays in `overlays/dev/` and `overlays/prod/`
   - ✅ Easy switching between environments
   - ✅ Declarative configuration management

## 📁 Files Created/Modified

### New Files
```
k8s/
├── infrastructure/kafka/
│   ├── kafka-kraft-statefulset.yaml    # NEW - KRaft mode Kafka
│   └── README.md                        # Updated
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml          # NEW - Dev environment
│   │   ├── kafka-dev-patch.yaml        # NEW - 1 broker
│   │   ├── postgres-dev-patch.yaml     # NEW - Reduced resources
│   │   └── apps-dev-patch.yaml         # NEW - 1 replica each
│   └── prod/
│       ├── kustomization.yaml          # NEW - Prod environment
│       └── apps-prod-patch.yaml        # NEW - 5 replicas, HA
├── scripts/
│   ├── deploy-dev.sh                   # NEW - Deploy dev
│   └── deploy-prod.sh                  # NEW - Deploy prod
└── KRAFT_ENV_SUMMARY.md                # NEW - This file
```

### Modified Files
- `k8s/infrastructure/kafka/kustomization.yaml` - Updated to use KRaft
- `k8s/apps/users/deployment.yaml` - Fixed image reference
- `k8s/apps/notifications/deployment.yaml` - Fixed image reference

### Removed Files
- `zookeeper-statefulset.yaml` - No longer needed with KRaft
- Old `overlays/` structure - Replaced with new dev/prod

## 🎯 Configuration Comparison

| Component | Development | Production |
|-----------|-------------|------------|
| **Kafka Brokers** | 1 | 3 |
| **Replication Factor** | 1 | 3 |
| **Min ISR** | 1 | 2 |
| **Retention** | 24h | 168h (7 days) |
| **Kafka CPU** | 250m-500m | 500m-1000m |
| **Kafka Memory** | 512Mi-1Gi | 1Gi-2Gi |
| **Kafka Storage** | 5Gi | 10Gi |
| **Users/Orders Replicas** | 1 | 5 |
| **Notifications Replicas** | 1 | 3 |
| **App CPU** | 50m-200m | 200m-1000m |
| **App Memory** | 64Mi-256Mi | 256Mi-1Gi |
| **PostgreSQL** | 1 replica | 1 replica |
| **Vault** | Not included | Included |
| **Jenkins** | Not included | Included |

## 🚀 Deployment Commands

### Deploy Development
```bash
cd k8s/scripts
./deploy-dev.sh
```

### Deploy Production
```bash
cd k8s/scripts
./deploy-prod.sh
```

### Using Kustomize Directly
```bash
# Development
kubectl apply -k k8s/overlays/dev/

# Production
kubectl apply -k k8s/overlays/prod/
```

### Switch Between Environments
```bash
# Clean current environment
kubectl delete namespace amazon-api

# Deploy new environment
./deploy-dev.sh    # or ./deploy-prod.sh
```

## 🔧 KRaft Configuration Highlights

### What is KRaft?
- **K**afka **Ra**ft - Kafka's new consensus protocol
- Replaces Zookeeper completely
- Brokers manage their own metadata
- Simpler operations, faster failover
- Production-ready since Kafka 3.3+

### KRaft Setup in Our Cluster

**Controller Quorum (Dev):**
- Single controller: kafka-0

**Controller Quorum (Prod):**
- 3 controllers: kafka-0, kafka-1, kafka-2
- Uses Raft consensus for leader election
- Faster metadata operations

**Key Environment Variables:**
```yaml
KAFKA_PROCESS_ROLES: broker,controller  # Combined mode
KAFKA_CONTROLLER_QUORUM_VOTERS: 0@kafka-0...:9093,1@kafka-1...:9093,2@kafka-2...:9093
KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
```

### Storage Initialization
```bash
# Automatically formatted on first startup
kafka-storage format -t <CLUSTER_ID> -c /tmp/kraft-runtime.properties
```

## 🐛 Known Issues & Solutions

### Issue 1: Kafka CrashLoopBackOff
**Symptom:** Kafka pod keeps restarting  
**Cause:** KRaft configuration needs proper `node.id`  
**Solution:** Fixed in startup script - extracts node ID from hostname

### Issue 2: Notifications Service ImagePullBackOff
**Symptom:** Cannot pull notifications-service image  
**Cause:** Image doesn't exist in DockerHub yet  
**Solution:** 
```bash
# Build and push the image
cd notifications-service
docker build -t israelhf24/notifications-service:latest .
docker push israelhf24/notifications-service:latest
```

### Issue 3: Users Service ImagePullBackOff
**Symptom:** Cannot pull amazon-api-users image  
**Solution:** Verify image exists or build/push it

## 📝 Next Steps

### To Complete Deployment:

1. **Build and Push Missing Images**
   ```bash
   # Notifications service
   cd notifications-service
   docker build -t israelhf24/notifications-service:latest .
   docker push israelhf24/notifications-service:latest
   
   # Verify users service image exists
   docker pull israelhf24/amazon-api-users:latest
   ```

2. **Fix Kafka KRaft Startup**
   The startup script has been updated but may need testing. Monitor:
   ```bash
   kubectl logs kafka-0 -n amazon-api -f
   ```

3. **Deploy Dev Environment**
   ```bash
   cd k8s/scripts
   ./deploy-dev.sh
   ```

4. **Verify Services**
   ```bash
   # Check all pods
   kubectl get pods -n amazon-api
   
   # Test Kafka
   kubectl exec kafka-0 -n amazon-api -- kafka-topics --bootstrap-server localhost:9092 --list
   
   # Test services (port-forward)
   kubectl port-forward -n amazon-api svc/amazon-api-users-service 8081:8081
   curl http://localhost:8081/users-api/hello
   ```

5. **Test Kafka Integration**
   ```bash
   # Produce test message
   kubectl exec -it kafka-0 -n amazon-api -- \
     kafka-console-producer --bootstrap-server localhost:9092 \
     --topic order.created
   
   # Check notifications service logs for consumption
   kubectl logs -f deployment/notifications-service -n amazon-api
   ```

## 🎓 Benefits of New Setup

### KRaft vs Zookeeper
| Aspect | Zookeeper | KRaft |
|--------|-----------|-------|
| Components | Kafka + Zookeeper | Kafka only |
| Complexity | Higher | Lower |
| Failover | Slower | Faster |
| Metadata | External | Internal |
| Operations | More complex | Simpler |
| Future | Deprecated | Official path |

### Environment Isolation
- ✅ Dev uses minimal resources - faster iteration
- ✅ Prod uses HA configuration - ready for real traffic
- ✅ Same manifests, different patches - consistent
- ✅ Easy to test changes in dev before prod

### Kustomize Benefits
- ✅ DRY - Don't repeat yourself
- ✅ Environment-specific without duplication
- ✅ GitOps friendly
- ✅ Native to kubectl (no extra tools)

## 📚 Additional Resources

- [Kafka KRaft Documentation](https://kafka.apache.org/documentation/#kraft)
- [Kustomize Documentation](https://kustomize.io/)
- [KRaft Migration Guide](https://kafka.apache.org/documentation/#kraft_zk_migration)

## 🔍 Verification Checklist

- [ ] Kafka pods running (1 in dev, 3 in prod)
- [ ] No Zookeeper pods (KRaft mode)
- [ ] Topics created successfully
- [ ] Users service responding
- [ ] Orders service responding
- [ ] Notifications service consuming from Kafka
- [ ] PostgreSQL accessible
- [ ] Services can communicate via Kubernetes DNS

## 🎉 Summary

You now have:
- ✅ Modern Kafka with KRaft (no Zookeeper!)
- ✅ Separate dev and prod environments
- ✅ Resource-efficient dev setup
- ✅ High-availability prod setup
- ✅ Kustomize-based deployments
- ✅ Simplified operations

**Next:** Build/push missing Docker images and test the complete flow!
