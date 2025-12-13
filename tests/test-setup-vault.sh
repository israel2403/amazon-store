#!/usr/bin/env bash
# Test script for setup-vault.sh
# This script tests that setup-vault.sh successfully populates Vault with all defined environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Testing setup-vault.sh"
echo "=========================="
echo ""

# Test 1: Verify .env file validation
test_env_file_validation() {
    echo "Test 1: Verify .env file validation"
    
    # Backup existing .env if it exists
    if [ -f "$PROJECT_ROOT/.env" ]; then
        mv "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup"
    fi
    
    # Run setup-vault.sh without .env file - should fail
    if bash "$PROJECT_ROOT/setup-vault.sh" 2>&1 | grep -q "Error: .env file not found"; then
        echo "✅ PASS: Script correctly detects missing .env file"
    else
        echo "❌ FAIL: Script did not detect missing .env file"
        # Restore backup
        [ -f "$PROJECT_ROOT/.env.backup" ] && mv "$PROJECT_ROOT/.env.backup" "$PROJECT_ROOT/.env"
        exit 1
    fi
    
    # Restore backup
    [ -f "$PROJECT_ROOT/.env.backup" ] && mv "$PROJECT_ROOT/.env.backup" "$PROJECT_ROOT/.env"
    echo ""
}

# Test 2: Verify required variables validation
test_required_variables_validation() {
    echo "Test 2: Verify required variables validation"
    
    # Create a temporary .env with missing variables
    cat > "$PROJECT_ROOT/.env.test" << 'EOF'
VAULT_ROOT_TOKEN=test-token
GITHUB_USERNAME=testuser
# Missing other required variables
EOF
    
    # Backup existing .env
    if [ -f "$PROJECT_ROOT/.env" ]; then
        mv "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup"
    fi
    mv "$PROJECT_ROOT/.env.test" "$PROJECT_ROOT/.env"
    
    # Run setup-vault.sh - should fail with missing variables
    if bash "$PROJECT_ROOT/setup-vault.sh" 2>&1 | grep -q "Missing required variables"; then
        echo "✅ PASS: Script correctly detects missing required variables"
    else
        echo "❌ FAIL: Script did not detect missing required variables"
        # Restore backup
        rm -f "$PROJECT_ROOT/.env"
        [ -f "$PROJECT_ROOT/.env.backup" ] && mv "$PROJECT_ROOT/.env.backup" "$PROJECT_ROOT/.env"
        exit 1
    fi
    
    # Restore backup
    rm -f "$PROJECT_ROOT/.env"
    [ -f "$PROJECT_ROOT/.env.backup" ] && mv "$PROJECT_ROOT/.env.backup" "$PROJECT_ROOT/.env"
    echo ""
}

# Test 3: Verify all required environment variables are passed to Vault
test_vault_environment_variables() {
    echo "Test 3: Verify all environment variables are populated in Vault"
    
    # Check if Vault container is running
    if ! docker ps | grep -q amazon-api-vault; then
        echo "⚠️  SKIP: Vault container is not running. Start it with: docker compose up -d vault"
        echo ""
        return 0
    fi
    
    # Check if .env file exists
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        echo "⚠️  SKIP: .env file does not exist. Create it from .env.example"
        echo ""
        return 0
    fi
    
    # Load environment variables
    source "$PROJECT_ROOT/.env"
    
    # Expected secrets in Vault
    REQUIRED_SECRETS=(
        "kv/amazon-api/dockerhub:username"
        "kv/amazon-api/dockerhub:token"
        "kv/amazon-api/github:username"
        "kv/amazon-api/github:token"
        "kv/amazon-api/jenkins:admin_user"
        "kv/amazon-api/jenkins:admin_password"
        "kv/amazon-api/postgres:database"
        "kv/amazon-api/postgres:username"
        "kv/amazon-api/postgres:password"
    )
    
    echo "Checking Vault secrets..."
    
    FAILED=0
    for secret_path in "${REQUIRED_SECRETS[@]}"; do
        IFS=':' read -r path key <<< "$secret_path"
        
        # Try to read the secret from Vault
        if docker exec -e VAULT_TOKEN="$VAULT_ROOT_TOKEN" amazon-api-vault \
            vault kv get -field="$key" "$path" &> /dev/null; then
            echo "  ✅ $path/$key exists"
        else
            echo "  ❌ $path/$key is missing"
            FAILED=1
        fi
    done
    
    if [ $FAILED -eq 0 ]; then
        echo "✅ PASS: All required secrets are populated in Vault"
    else
        echo "❌ FAIL: Some secrets are missing in Vault"
        exit 1
    fi
    
    echo ""
}

# Test 4: Verify setup-vault.sh script execution
test_vault_setup_execution() {
    echo "Test 4: Verify setup-vault.sh completes successfully"
    
    # Check if Vault container is running
    if ! docker ps | grep -q amazon-api-vault; then
        echo "⚠️  SKIP: Vault container is not running"
        echo ""
        return 0
    fi
    
    # Check if .env file exists
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        echo "⚠️  SKIP: .env file does not exist"
        echo ""
        return 0
    fi
    
    # Run setup-vault.sh and check for success message
    if bash "$PROJECT_ROOT/setup-vault.sh" 2>&1 | grep -q "Vault setup complete"; then
        echo "✅ PASS: setup-vault.sh executed successfully"
    else
        echo "❌ FAIL: setup-vault.sh did not complete successfully"
        exit 1
    fi
    
    echo ""
}

# Run tests
test_env_file_validation
test_required_variables_validation
test_vault_environment_variables
test_vault_setup_execution

echo "✅ All tests completed!"
echo ""
echo "Note: Some tests may have been skipped if Vault container is not running"
echo "      or .env file does not exist. To run all tests:"
echo "      1. Create .env from .env.example and fill in values"
echo "      2. Start Vault: docker compose up -d vault"
echo "      3. Run this test script again"
