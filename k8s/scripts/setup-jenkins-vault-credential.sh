#!/bin/bash

# Add Vault token credential to Jenkins
# This script creates a Jenkins credential for accessing Vault

set -e

NAMESPACE="amazon-api"
JENKINS_POD=$(kubectl get pod -n $NAMESPACE -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
VAULT_TOKEN="dev-root-token"

echo "🔐 Adding Vault token credential to Jenkins..."

if [ -z "$JENKINS_POD" ]; then
  echo "❌ Error: Jenkins pod not found in namespace $NAMESPACE"
  exit 1
fi

echo "✅ Found Jenkins pod: $JENKINS_POD"

# Create Groovy script to add credential
cat > /tmp/add-vault-credential.groovy << 'EOF'
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import com.cloudbees.plugins.credentials.CredentialsScope

def jenkins = Jenkins.instance
def domain = Domain.global()
def store = jenkins.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// Create Vault token credential
def vaultToken = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "vault-token",
    "Vault Root Token for secret access",
    hudson.util.Secret.fromString("dev-root-token")
)

// Remove existing credential if it exists
def existingCreds = CredentialsProvider.lookupCredentials(
    com.cloudbees.plugins.credentials.Credentials.class,
    jenkins,
    null,
    null
)

existingCreds.each { cred ->
    if (cred.id == "vault-token") {
        store.removeCredentials(domain, cred)
        println("Removed existing vault-token credential")
    }
}

// Add new credential
store.addCredentials(domain, vaultToken)
jenkins.save()

println("✅ Vault token credential added successfully!")
EOF

# Copy script to Jenkins pod and execute
kubectl cp /tmp/add-vault-credential.groovy $NAMESPACE/$JENKINS_POD:/tmp/add-vault-credential.groovy

echo "📝 Executing Groovy script in Jenkins..."
kubectl exec -n $NAMESPACE $JENKINS_POD -- \
  java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ \
  -auth admin:admin123 \
  groovy = < /tmp/add-vault-credential.groovy

# Clean up
rm -f /tmp/add-vault-credential.groovy

echo ""
echo "✅ Jenkins Vault credential setup complete!"
echo ""
echo "📋 Credential details:"
echo "  ID: vault-token"
echo "  Type: Secret text"
echo "  Description: Vault Root Token for secret access"
echo ""
echo "🔗 Jenkins can now access Vault at:"
echo "   http://vault.amazon-api.svc.cluster.local:8200"
echo ""
