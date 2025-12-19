#!/bin/bash

echo "🧪 Testing Amazon Store Infrastructure"
echo "======================================="
echo ""

MINIKUBE_IP=$(minikube ip)
FAILED_TESTS=0
PASSED_TESTS=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_passed() {
    echo -e "${GREEN}✅ PASSED${NC}: $1"
    ((PASSED_TESTS++))
}

test_failed() {
    echo -e "${RED}❌ FAILED${NC}: $1"
    ((FAILED_TESTS++))
}

test_warning() {
    echo -e "${YELLOW}⚠️  WARNING${NC}: $1"
}

echo "📋 Test 1: Check Kubernetes Namespaces"
echo "---------------------------------------"
if kubectl get namespace amazon-api &>/dev/null; then
    test_passed "amazon-api namespace exists"
else
    test_failed "amazon-api namespace does not exist"
fi

if kubectl get namespace kong &>/dev/null; then
    test_passed "kong namespace exists"
else
    test_warning "kong namespace does not exist"
fi
echo ""

echo "📋 Test 2: Check Pods Status in amazon-api namespace"
echo "-----------------------------------------------------"
PODS_STATUS=$(kubectl get pods -n amazon-api --no-headers 2>/dev/null)

if echo "$PODS_STATUS" | grep -q "vault"; then
    if echo "$PODS_STATUS" | grep "vault" | grep -q "Running"; then
        test_passed "Vault pod is running"
    else
        test_failed "Vault pod is not running"
    fi
else
    test_failed "Vault pod not found"
fi

if echo "$PODS_STATUS" | grep -q "jenkins"; then
    if echo "$PODS_STATUS" | grep "jenkins" | grep -q "Running"; then
        test_passed "Jenkins pod is running"
    else
        test_failed "Jenkins pod is not running"
    fi
else
    test_failed "Jenkins pod not found"
fi

if echo "$PODS_STATUS" | grep -q "postgres"; then
    if echo "$PODS_STATUS" | grep "postgres" | grep -q "Running"; then
        test_passed "PostgreSQL pod is running"
    else
        test_failed "PostgreSQL pod is not running"
    fi
else
    test_failed "PostgreSQL pod not found"
fi

if echo "$PODS_STATUS" | grep -q "amazon-api-users"; then
    if echo "$PODS_STATUS" | grep "amazon-api-users" | grep -q "Running"; then
        test_passed "Users service pod is running"
    else
        test_failed "Users service pod is not running"
    fi
else
    test_failed "Users service pod not found"
fi

if echo "$PODS_STATUS" | grep -q "amazonapi-orders"; then
    if echo "$PODS_STATUS" | grep "amazonapi-orders" | grep -q "Running"; then
        test_passed "Orders service pod is running"
    else
        test_failed "Orders service pod is not running"
    fi
else
    test_failed "Orders service pod not found"
fi
echo ""

echo "📋 Test 3: Check Services in amazon-api namespace"
echo "--------------------------------------------------"
SERVICES=$(kubectl get svc -n amazon-api --no-headers 2>/dev/null)

if echo "$SERVICES" | grep -q "vault"; then
    test_passed "Vault service exists"
else
    test_failed "Vault service not found"
fi

if echo "$SERVICES" | grep -q "jenkins"; then
    test_passed "Jenkins service exists"
else
    test_failed "Jenkins service not found"
fi

if echo "$SERVICES" | grep -q "postgres"; then
    test_passed "PostgreSQL service exists"
else
    test_failed "PostgreSQL service not found"
fi

if echo "$SERVICES" | grep -q "amazon-api-users-service"; then
    test_passed "Users service exists"
else
    test_failed "Users service not found"
fi

if echo "$SERVICES" | grep -q "amazonapi-orders-service"; then
    test_passed "Orders service exists"
else
    test_failed "Orders service not found"
fi
echo ""

echo "📋 Test 4: Test Internal Service Communication"
echo "-----------------------------------------------"

# Test PostgreSQL connectivity from within cluster
echo "Testing PostgreSQL connectivity..."
PG_TEST=$(kubectl run postgres-test --rm -i --restart=Never --image=postgres:16-alpine -n amazon-api -- psql -h postgres -U postgres -d amazon_orders -c "SELECT 1;" 2>&1 || true)
if echo "$PG_TEST" | grep -q "1 row"; then
    test_passed "PostgreSQL is accessible from within cluster"
else
    test_failed "PostgreSQL is not accessible from within cluster"
fi
echo ""

echo "📋 Test 5: Test HTTP Endpoints (Direct to Services)"
echo "-----------------------------------------------------"

# Test Vault
echo "Testing Vault..."
VAULT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$MINIKUBE_IP:30200/v1/sys/health || echo "000")
if [ "$VAULT_RESPONSE" = "200" ] || [ "$VAULT_RESPONSE" = "429" ]; then
    test_passed "Vault is accessible at http://$MINIKUBE_IP:30200 (HTTP $VAULT_RESPONSE)"
else
    test_failed "Vault is not accessible (HTTP $VAULT_RESPONSE)"
fi

# Test Jenkins
echo "Testing Jenkins..."
JENKINS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$MINIKUBE_IP:30081/login 2>/dev/null || echo "000")
if [ "$JENKINS_RESPONSE" = "200" ]; then
    test_passed "Jenkins is accessible at http://$MINIKUBE_IP:30081 (HTTP $JENKINS_RESPONSE)"
else
    test_warning "Jenkins endpoint returned HTTP $JENKINS_RESPONSE"
fi

# Test Users Service (via port-forward temporarily)
echo "Testing Users Service..."
kubectl port-forward -n amazon-api svc/amazon-api-users-service 8081:8081 &>/dev/null &
PF_PID=$!
sleep 2
USERS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/users-api/hello 2>/dev/null || echo "000")
kill $PF_PID 2>/dev/null || true
if [ "$USERS_RESPONSE" = "200" ]; then
    test_passed "Users service is accessible (HTTP $USERS_RESPONSE)"
else
    test_failed "Users service is not accessible (HTTP $USERS_RESPONSE)"
fi

# Test Orders Service (via port-forward temporarily)
echo "Testing Orders Service..."
kubectl port-forward -n amazon-api svc/amazonapi-orders-service 8082:8082 &>/dev/null &
PF_PID=$!
sleep 2
ORDERS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/orders-api/hello 2>/dev/null || echo "000")
kill $PF_PID 2>/dev/null || true
if [ "$ORDERS_RESPONSE" = "200" ]; then
    test_passed "Orders service is accessible (HTTP $ORDERS_RESPONSE)"
else
    test_failed "Orders service is not accessible (HTTP $ORDERS_RESPONSE)"
fi
echo ""

echo "📋 Test 6: Test Kong API Gateway (if deployed)"
echo "-----------------------------------------------"
if kubectl get namespace kong &>/dev/null; then
    KONG_PODS=$(kubectl get pods -n kong --no-headers 2>/dev/null | grep "Running" | wc -l)
    if [ "$KONG_PODS" -gt 0 ]; then
        test_passed "Kong pods are running ($KONG_PODS pods)"
        
        # Test Kong proxy
        KONG_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$MINIKUBE_IP:30080/ 2>/dev/null || echo "000")
        if [ "$KONG_RESPONSE" != "000" ]; then
            test_passed "Kong proxy is accessible (HTTP $KONG_RESPONSE)"
        else
            test_failed "Kong proxy is not accessible"
        fi
    else
        test_warning "Kong is deployed but pods are not running"
    fi
else
    test_warning "Kong namespace not found - skipping Kong tests"
fi
echo ""

echo "📋 Test 7: Test via Kong Gateway (End-to-End)"
echo "----------------------------------------------"
if kubectl get namespace kong &>/dev/null && kubectl get ingress -n amazon-api &>/dev/null 2>&1; then
    # Test Users API via Kong
    echo "Testing Users API via Kong..."
    USERS_KONG=$(curl -s -o /dev/null -w "%{http_code}" http://$MINIKUBE_IP:30080/users-api/hello 2>/dev/null || echo "000")
    if [ "$USERS_KONG" = "200" ]; then
        test_passed "Users API accessible via Kong (HTTP $USERS_KONG)"
    else
        test_warning "Users API not accessible via Kong (HTTP $USERS_KONG)"
    fi
    
    # Test Orders API via Kong
    echo "Testing Orders API via Kong..."
    ORDERS_KONG=$(curl -s -o /dev/null -w "%{http_code}" http://$MINIKUBE_IP:30080/orders-api/hello 2>/dev/null || echo "000")
    if [ "$ORDERS_KONG" = "200" ]; then
        test_passed "Orders API accessible via Kong (HTTP $ORDERS_KONG)"
    else
        test_warning "Orders API not accessible via Kong (HTTP $ORDERS_KONG)"
    fi
else
    test_warning "Kong ingress not configured - skipping end-to-end tests"
fi
echo ""

echo "======================================="
echo "📊 Test Summary"
echo "======================================="
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ All critical tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Check the output above.${NC}"
    exit 1
fi
