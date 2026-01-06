#!/bin/bash
set -e

echo "=== Integration Test Runner ==="
echo ""

# Check if port forwards are needed
echo "Checking prerequisites..."

# Check Vault connectivity
if ! curl -s http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
    echo "❌ Vault is not accessible at localhost:8200"
    echo "   Run: kubectl port-forward -n amazon-api svc/vault 8200:8200 &"
    exit 1
fi
echo "✅ Vault is accessible"

# Check MySQL connectivity
if ! nc -z localhost 3306 2>/dev/null; then
    echo "❌ MySQL is not accessible at localhost:3306"
    echo "   Run: kubectl port-forward -n amazon-api-dev svc/mysql 3306:3306 &"
    exit 1
fi
echo "✅ MySQL is accessible"

# Check if test database exists and create if needed
echo ""
echo "Setting up test database..."
POD_NAME=$(kubectl get pods -n amazon-api-dev -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
    echo "❌ Could not find MySQL pod in amazon-api-dev namespace"
    exit 1
fi

kubectl exec -n amazon-api-dev "$POD_NAME" -- mysql -u root -prootpassword123 -e "
    CREATE DATABASE IF NOT EXISTS amazon_users_test;
    GRANT ALL PRIVILEGES ON amazon_users_test.* TO 'mysql'@'%';
    FLUSH PRIVILEGES;
" 2>/dev/null || {
    echo "⚠️  Warning: Could not create test database (may already exist)"
}
echo "✅ Test database ready"

# Run tests
echo ""
echo "Running integration tests..."
echo ""

VAULT_ADDR=http://localhost:8200 mvn test -Dtest=CucumberIntegrationTest

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Integration tests passed!"
else
    echo ""
    echo "❌ Integration tests failed!"
fi

exit $EXIT_CODE
