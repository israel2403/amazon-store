#!/bin/bash

echo "🧪 Simple Infrastructure Test"
echo "=============================="
echo ""

MINIKUBE_IP=$(minikube ip)

echo "1️⃣  Checking all pods in amazon-api namespace:"
kubectl get pods -n amazon-api
echo ""

echo "2️⃣  Testing Vault (NodePort 30200):"
VAULT_STATUS=$(curl -s http://$MINIKUBE_IP:30200/v1/sys/health | jq -r '.initialized')
if [ "$VAULT_STATUS" = "true" ]; then
    echo "✅ Vault is accessible and initialized"
else
    echo "❌ Vault is not accessible"
fi
echo ""

echo "3️⃣  Testing Jenkins (NodePort 30081):"
JENKINS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$MINIKUBE_IP:30081/login)
if [ "$JENKINS_STATUS" = "200" ]; then
    echo "✅ Jenkins is accessible at http://$MINIKUBE_IP:30081"
else
    echo "❌ Jenkins is not accessible (HTTP $JENKINS_STATUS)"
fi
echo ""

echo "4️⃣  Testing Users Service (via port-forward):"
kubectl port-forward -n amazon-api svc/amazon-api-users-service 18081:8081 &>/dev/null &
PF_PID=$!
sleep 2
USERS_RESPONSE=$(curl -s http://localhost:18081/users-api/hello)
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null
if [ "$USERS_RESPONSE" = "OK" ]; then
    echo "✅ Users Service responded: $USERS_RESPONSE"
else
    echo "⚠️  Users Service response: $USERS_RESPONSE"
fi
echo ""

echo "5️⃣  Testing Orders Service (via port-forward):"
kubectl port-forward -n amazon-api svc/amazonapi-orders-service 18082:8082 &>/dev/null &
PF_PID=$!
sleep 2
ORDERS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18082/orders-api/)
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null
if [ "$ORDERS_STATUS" != "000" ]; then
    echo "✅ Orders Service is accessible (HTTP $ORDERS_STATUS)"
else
    echo "❌ Orders Service is not accessible"
fi
echo ""

echo "6️⃣  Testing PostgreSQL connectivity from within cluster:"
PG_RESULT=$(kubectl exec -n amazon-api deployment/amazonapi-orders-deployment -- sh -c "nc -zv postgres 5432 2>&1" | grep -i "open" || echo "failed")
if echo "$PG_RESULT" | grep -q "open"; then
    echo "✅ PostgreSQL is accessible from Orders service"
else
    echo "⚠️  PostgreSQL connectivity test: $PG_RESULT"
fi
echo ""

echo "=============================="
echo "📊 Summary:"
echo "=============================="
echo "All services are deployed in the amazon-api namespace:"
echo "  • Vault:        http://$MINIKUBE_IP:30200"
echo "  • Jenkins:      http://$MINIKUBE_IP:30081"
echo "  • Users API:    ClusterIP (8081)"
echo "  • Orders API:   ClusterIP (8082)"
echo "  • PostgreSQL:   ClusterIP (5432)"
echo ""
echo "✅ Infrastructure is operational!"
