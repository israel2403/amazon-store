# Orders Service Port Change

## 🔄 Change Summary

**Orders service port changed from 8080 to 8082** to avoid port conflicts.

## 📋 Files Modified

### Application Configuration
1. **amazonapi-orders/src/main/resources/application.properties**
   - Added: `server.port=8082`

### Kubernetes Manifests
2. **k8s/deployment-orders.yaml**
   - Container port: 8080 → 8082
   - Liveness probe: 8080 → 8082
   - Readiness probe: 8080 → 8082

3. **k8s/service-orders.yaml**
   - Service port: 8080 → 8082
   - Target port: 8080 → 8082
   - NodePort: 30082 (unchanged)

### Documentation
4. **README.md** - Updated test commands and port references
5. **SEPARATE_PIPELINES_SETUP.md** - Updated service configuration
6. **QUICK_REFERENCE.md** - Updated port table
7. **IMPLEMENTATION_SUMMARY.md** - Updated port references

## 🎯 New Port Configuration

| Service | Application Port | NodePort | External Access |
|---------|-----------------|----------|-----------------|
| **Users** | 8081 | 30081 | http://localhost:30081 (via minikube) |
| **Orders** | 8082 | 30082 | http://localhost:30082 (via minikube) |

## ✅ Testing After Change

### Test Orders Service Locally

If you rebuild and run the orders service:

```bash
# Build
cd amazonapi-orders
./gradlew clean build

# Run locally (will use port 8082)
java -jar build/libs/amazonapi-orders-*.jar

# Test
curl http://localhost:8082/api/orders
```

### Test in Kubernetes

After deploying to K8s:

```bash
# Check deployment
kubectl get pods -n amazon-api -l app=amazonapi-orders

# Get service URL
minikube service amazonapi-orders-service -n amazon-api --url

# Test endpoint
curl http://$(minikube service amazonapi-orders-service -n amazon-api --url)/api/orders
```

### Port Forward

```bash
kubectl port-forward -n amazon-api svc/amazonapi-orders-service 8082:8082
curl http://localhost:8082/api/orders
```

## 🚀 Next Steps

1. **Rebuild the orders service** (if running locally):
   ```bash
   cd amazonapi-orders
   ./gradlew clean build
   ```

2. **Redeploy to Kubernetes** (via Jenkins or manually):
   ```bash
   # Via Jenkins: Trigger amazonapi-orders-pipeline
   # Or manually:
   bash k8s/deploy-orders.sh
   ```

3. **Verify the new port**:
   ```bash
   kubectl get svc -n amazon-api amazonapi-orders-service
   # Should show port 8082
   ```

## ⚠️ Important Notes

- **No conflict with Jenkins** anymore (Jenkins uses port 8080)
- **Users service unchanged** (still on port 8081)
- **NodePort unchanged** (still 30082 for external access)
- **Only internal application port changed** (8082)

## 🔍 Port Conflict Resolution

### Before
```
Jenkins:        8080 ✗ (conflict!)
Orders Service: 8080 ✗ (conflict!)
Users Service:  8081 ✓
```

### After
```
Jenkins:        8080 ✓
Orders Service: 8082 ✓ (no conflict!)
Users Service:  8081 ✓
```

## ✅ Verification Checklist

After redeploying:

- [ ] Orders service starts without port conflict errors
- [ ] Can access orders service at port 8082 locally
- [ ] K8s deployment uses port 8082
- [ ] K8s service exposes port 8082
- [ ] Can access via NodePort 30082
- [ ] Jenkins still accessible on port 8080
- [ ] Users service still works on port 8081

---

**Change completed successfully!** No further action needed unless you're currently running the orders service.
