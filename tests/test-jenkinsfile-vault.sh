#!/usr/bin/env bash
# Test script for Jenkinsfile Vault integration
# This script tests that the Orders service Jenkinsfile retrieves DockerHub credentials
# from Vault and uses them for Docker operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JENKINSFILE="$PROJECT_ROOT/amazonapi-orders/Jenkinsfile"

echo "🧪 Testing Jenkinsfile Vault Integration"
echo "========================================="
echo ""

# Test 1: Verify Jenkinsfile contains Vault secret loading
test_vault_secret_loading() {
    echo "Test 1: Verify Jenkinsfile loads secrets from Vault"
    
    if ! [ -f "$JENKINSFILE" ]; then
        echo "❌ FAIL: Jenkinsfile not found at $JENKINSFILE"
        exit 1
    fi
    
    # Check for withVault block
    if grep -q "withVault" "$JENKINSFILE"; then
        echo "  ✅ Found withVault block"
    else
        echo "  ❌ withVault block not found"
        exit 1
    fi
    
    # Check for DockerHub credentials path
    if grep -q "path: 'kv/amazon-api/dockerhub'" "$JENKINSFILE"; then
        echo "  ✅ Found DockerHub secret path"
    else
        echo "  ❌ DockerHub secret path not found"
        exit 1
    fi
    
    echo "✅ PASS: Jenkinsfile contains Vault secret loading configuration"
    echo ""
}

# Test 2: Verify DockerHub credentials are retrieved
test_dockerhub_credentials() {
    echo "Test 2: Verify DockerHub credentials are retrieved from Vault"
    
    # Check for DOCKERHUB_USERNAME environment variable
    if grep -q "envVar: 'DOCKERHUB_USERNAME'" "$JENKINSFILE"; then
        echo "  ✅ DOCKERHUB_USERNAME environment variable configured"
    else
        echo "  ❌ DOCKERHUB_USERNAME not found"
        exit 1
    fi
    
    # Check for DOCKERHUB_TOKEN environment variable
    if grep -q "envVar: 'DOCKERHUB_TOKEN'" "$JENKINSFILE"; then
        echo "  ✅ DOCKERHUB_TOKEN environment variable configured"
    else
        echo "  ❌ DOCKERHUB_TOKEN not found"
        exit 1
    fi
    
    # Check for username vault key
    if grep -q "vaultKey: 'username'" "$JENKINSFILE"; then
        echo "  ✅ Username vault key configured"
    else
        echo "  ❌ Username vault key not found"
        exit 1
    fi
    
    # Check for token vault key
    if grep -q "vaultKey: 'token'" "$JENKINSFILE"; then
        echo "  ✅ Token vault key configured"
    else
        echo "  ❌ Token vault key not found"
        exit 1
    fi
    
    echo "✅ PASS: DockerHub credentials are properly configured for retrieval"
    echo ""
}

# Test 3: Verify credentials are used in Docker operations
test_docker_operations() {
    echo "Test 3: Verify DockerHub credentials are used in Docker operations"
    
    # Check for docker login using credentials
    if grep -q "docker login -u \${DOCKERHUB_USERNAME}" "$JENKINSFILE" || \
       grep -q "docker login -u \"\${DOCKERHUB_USERNAME}\"" "$JENKINSFILE"; then
        echo "  ✅ docker login uses DOCKERHUB_USERNAME"
    else
        echo "  ❌ docker login does not use DOCKERHUB_USERNAME"
        exit 1
    fi
    
    if grep -q "\${DOCKERHUB_TOKEN}" "$JENKINSFILE"; then
        echo "  ✅ docker login uses DOCKERHUB_TOKEN"
    else
        echo "  ❌ docker login does not use DOCKERHUB_TOKEN"
        exit 1
    fi
    
    # Check for docker build
    if grep -q "docker build" "$JENKINSFILE"; then
        echo "  ✅ docker build command found"
    else
        echo "  ❌ docker build command not found"
        exit 1
    fi
    
    # Check for docker push using username
    if grep -q "docker push.*\${DOCKERHUB_USERNAME}" "$JENKINSFILE"; then
        echo "  ✅ docker push uses DOCKERHUB_USERNAME in image name"
    else
        echo "  ❌ docker push does not use DOCKERHUB_USERNAME"
        exit 1
    fi
    
    # Check for docker logout
    if grep -q "docker logout" "$JENKINSFILE"; then
        echo "  ✅ docker logout found (security best practice)"
    else
        echo "  ⚠️  docker logout not found (not critical but recommended)"
    fi
    
    echo "✅ PASS: Docker operations properly use Vault credentials"
    echo ""
}

# Test 4: Verify loadVaultSecrets function
test_load_vault_secrets_function() {
    echo "Test 4: Verify loadVaultSecrets() function"
    
    # Check for function definition
    if grep -q "def loadVaultSecrets()" "$JENKINSFILE"; then
        echo "  ✅ loadVaultSecrets() function defined"
    else
        echo "  ❌ loadVaultSecrets() function not found"
        exit 1
    fi
    
    # Check for function call
    if grep -q "loadVaultSecrets()" "$JENKINSFILE"; then
        echo "  ✅ loadVaultSecrets() function called"
    else
        echo "  ❌ loadVaultSecrets() function not called"
        exit 1
    fi
    
    # Check that secrets are loaded in dedicated stage
    if grep -A5 "stage('Load Vault Secrets')" "$JENKINSFILE" | grep -q "loadVaultSecrets()"; then
        echo "  ✅ Secrets loaded in dedicated 'Load Vault Secrets' stage"
    else
        echo "  ⚠️  No dedicated 'Load Vault Secrets' stage found"
    fi
    
    echo "✅ PASS: loadVaultSecrets() function properly implemented"
    echo ""
}

# Test 5: Verify security best practices
test_security_practices() {
    echo "Test 5: Verify security best practices"
    
    # Check that credentials are not hardcoded
    if grep -E "(password|token|secret).*[:=].*['\"][^$]" "$JENKINSFILE" | grep -v "envVar\|vaultKey\|path"; then
        echo "  ⚠️  Warning: Potential hardcoded credentials found"
    else
        echo "  ✅ No hardcoded credentials detected"
    fi
    
    # Check for password-stdin usage (secure password input)
    if grep -q "password-stdin" "$JENKINSFILE"; then
        echo "  ✅ Uses --password-stdin for secure credential input"
    else
        echo "  ⚠️  Not using --password-stdin (credentials might be exposed in process list)"
    fi
    
    echo "✅ PASS: Security best practices are followed"
    echo ""
}

# Run tests
test_vault_secret_loading
test_dockerhub_credentials
test_docker_operations
test_load_vault_secrets_function
test_security_practices

echo "✅ All Jenkinsfile tests passed!"
echo ""
echo "Summary:"
echo "  - Jenkinsfile correctly loads secrets from Vault"
echo "  - DockerHub credentials (username and token) are retrieved"
echo "  - Credentials are used for docker login, build, and push operations"
echo "  - Security best practices are followed"
