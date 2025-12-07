#!/usr/bin/env bash
# Generate .env file from shell environment variables

set -e

echo "🔧 Generating .env file from shell environment variables..."

# Check if environment variables are set
MISSING_VARS=()

if [ -z "$GITHUB_USERNAME" ]; then MISSING_VARS+=("GITHUB_USERNAME"); fi
if [ -z "$GITHUB_TOKEN" ]; then MISSING_VARS+=("GITHUB_TOKEN"); fi
if [ -z "$DOCKERHUB_USERNAME" ]; then MISSING_VARS+=("DOCKERHUB_USERNAME"); fi
if [ -z "$DOCKERHUB_TOKEN" ]; then MISSING_VARS+=("DOCKERHUB_TOKEN"); fi
if [ -z "$JENKINS_ADMIN_USER" ]; then MISSING_VARS+=("JENKINS_ADMIN_USER"); fi
if [ -z "$JENKINS_ADMIN_PASSWORD" ]; then MISSING_VARS+=("JENKINS_ADMIN_PASSWORD"); fi
if [ -z "$K8S_NAMESPACE" ]; then MISSING_VARS+=("K8S_NAMESPACE"); fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Error: Missing environment variables: ${MISSING_VARS[*]}"
    echo ""
    echo "Please ensure these variables are exported in your ~/.zshrc:"
    echo "  source ~/.zshrc"
    echo ""
    echo "Or open a new terminal to load the updated ~/.zshrc"
    exit 1
fi

# Generate .env file
cat > .env << EOF
# .env - Generated from shell environment variables
# Do NOT commit this file!

GITHUB_USERNAME=${GITHUB_USERNAME}
GITHUB_TOKEN=${GITHUB_TOKEN}

DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN}

JENKINS_ADMIN_USER=${JENKINS_ADMIN_USER}
JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD}

K8S_NAMESPACE=${K8S_NAMESPACE}
EOF

echo "✅ .env file generated successfully!"
echo ""
echo "⚠️  Security reminder:"
echo "  - .env file is excluded from git"
echo "  - Never commit credentials to version control"
echo "  - Consider migrating to HashiCorp Vault for production"
