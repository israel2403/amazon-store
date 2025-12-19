# Kong Ingress Controller Setup

This directory contains the Kubernetes configuration for Kong Ingress Controller, which replaces the previous Spring Cloud Gateway service.

## Architecture

**Kong Ingress Controller** provides:
- **API Gateway**: L7 routing and traffic management
- **Service Discovery**: Automatic discovery via Kubernetes DNS
- **Load Balancing**: K8s Service (L4) + Kong (L7) load balancing
- **High Availability**: Multiple pod replicas for backend services

## Components

### Kong Resources
- `kong-namespace.yaml` - Kong namespace
- `kong-deployment.yaml` - Kong Ingress Controller + Kong Proxy (DB-less mode)
- `kong-ingress.yaml` - Ingress routing rules

### Backend Services
- `service.yaml` - Users service (ClusterIP, port 8081)
- `service-orders.yaml` - Orders service (ClusterIP, port 8082)
- `deployment.yaml` - Users deployment (3 replicas)
- `deployment-orders.yaml` - Orders deployment (3 replicas)

## Deployment

### Quick Start
```bash
cd k8s
./deploy-kong.sh
```

### Manual Deployment
```bash
# 1. Deploy Kong
kubectl apply -f kong-namespace.yaml
kubectl apply -f kong-deployment.yaml

# 2. Wait for Kong to be ready
kubectl wait --namespace kong \
  --for=condition=ready pod \
  --selector=app=kong-ingress-controller \
  --timeout=120s

# 3. Deploy backend services
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment-orders.yaml
kubectl apply -f service-orders.yaml

# 4. Configure routing
kubectl apply -f kong-ingress.yaml
```

## Access Points

**Kong Proxy** (external access):
- HTTP: `http://localhost:30080`
- HTTPS: `https://localhost:30443`

**API Endpoints**:
- Users API: `http://localhost:30080/users-api`
- Orders API: `http://localhost:30080/api/orders`

## Routing Configuration

### Users Service
- **Path**: `/users-api`
- **Target**: `amazon-api-users-service:8081` (ClusterIP)
- **Endpoints**:
  - `GET /users-api` - Hello World
  - `GET /users-api/hello` - Health check

### Orders Service
- **Path**: `/api/orders`
- **Target**: `amazonapi-orders-service:8082` (ClusterIP)
- **Endpoints**:
  - `GET /api/orders` - List all orders
  - `GET /api/orders/{id}` - Get order by ID
  - `POST /api/orders` - Create order
  - `PUT /api/orders/{id}` - Update order
  - `DELETE /api/orders/{id}` - Delete order

## Service Discovery & Load Balancing

### Service Discovery
Kong automatically discovers backend services using **Kubernetes DNS**:
- Services are resolved within the `amazon-api` namespace
- DNS names: `amazon-api-users-service.amazon-api.svc.cluster.local`
- Kong Ingress Controller watches Kubernetes Service resources

### Load Balancing
**Two-tier load balancing**:

1. **Kubernetes Service (L4)**:
   - Distributes traffic across pod replicas
   - 3 replicas per service for high availability
   - ClusterIP provides internal load balancing

2. **Kong (L7)**:
   - Application-layer routing based on paths
   - Advanced load balancing algorithms available
   - Health checks and circuit breaking

## Monitoring

### Check Kong Status
```bash
# Kong pods
kubectl get pods -n kong

# Kong services
kubectl get svc -n kong

# Kong logs
kubectl logs -n kong -l app=kong-ingress-controller -c ingress-controller
kubectl logs -n kong -l app=kong-ingress-controller -c kong-proxy
```

### Check Backend Services
```bash
# Application pods
kubectl get pods -n amazon-api

# Services and endpoints
kubectl get svc -n amazon-api
kubectl get endpoints -n amazon-api

# Ingress status
kubectl get ingress -n amazon-api
kubectl describe ingress amazon-api-ingress -n amazon-api
```

### Test Endpoints
```bash
# Users API
curl http://localhost:30080/users-api
curl http://localhost:30080/users-api/hello

# Orders API
curl http://localhost:30080/api/orders
curl -X POST http://localhost:30080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": "123", "quantity": 1}'
```

## Configuration

### Kong Features
Kong provides additional features that can be configured:
- Rate limiting
- Authentication (JWT, OAuth2, API Keys)
- Request/response transformations
- CORS
- Caching
- Logging

To add Kong plugins, create `KongPlugin` CRDs and reference them in the Ingress annotations.

### Example: Rate Limiting
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limiting
  namespace: amazon-api
config:
  minute: 100
  policy: local
plugin: rate-limiting
---
# Add to Ingress annotations:
# konghq.com/plugins: rate-limiting
```

## Cleanup

```bash
# Remove Kong and all resources
kubectl delete -f kong-ingress.yaml
kubectl delete -f kong-deployment.yaml
kubectl delete namespace kong

# Remove backend services
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment-orders.yaml
kubectl delete -f service-orders.yaml
```

## Advantages Over Spring Cloud Gateway

1. **Kubernetes-Native**: No separate microservice to maintain
2. **Performance**: C-based proxy vs JVM-based gateway
3. **Resource Efficient**: Lower memory and CPU usage
4. **Built-in Features**: Extensive plugin ecosystem
5. **Service Discovery**: Automatic via K8s DNS
6. **Scalability**: Handles high traffic loads efficiently
7. **Industry Standard**: Widely adopted in cloud-native architectures

## Troubleshooting

### Kong pods not starting
```bash
kubectl describe pod -n kong -l app=kong-ingress-controller
kubectl logs -n kong -l app=kong-ingress-controller
```

### Ingress not routing traffic
```bash
# Check Ingress status
kubectl get ingress -n amazon-api
kubectl describe ingress amazon-api-ingress -n amazon-api

# Verify backend services are running
kubectl get pods -n amazon-api
kubectl get endpoints -n amazon-api
```

### 502/503 errors
- Verify backend services are healthy
- Check service selectors match pod labels
- Ensure pods are in Ready state
- Check application logs for errors

## References

- [Kong Ingress Controller Documentation](https://docs.konghq.com/kubernetes-ingress-controller/)
- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
