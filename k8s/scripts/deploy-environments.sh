#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_info "kubectl is available"
}

# Function to deploy an environment
deploy_environment() {
    local ENV=$1
    local ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
    
    print_info "========================================="
    print_info "Deploying $ENV_UPPER Environment"
    print_info "========================================="
    
    # Deploy application and infrastructure
    print_info "Deploying applications and infrastructure to amazon-api-$ENV namespace..."
    kubectl apply -k "k8s/overlays/$ENV/"
    
    # Deploy Kong
    print_info "Deploying Kong API Gateway to kong-$ENV namespace..."
    kubectl apply -k "k8s/infrastructure/kong/overlays/$ENV/"
    
    print_info "$ENV_UPPER environment deployed successfully!"
    echo ""
}

# Function to verify deployment
verify_environment() {
    local ENV=$1
    local NAMESPACE="amazon-api-$ENV"
    local KONG_NAMESPACE="kong-$ENV"
    
    print_info "Verifying $ENV environment..."
    
    echo ""
    print_info "Application namespace ($NAMESPACE):"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    print_info "Kong namespace ($KONG_NAMESPACE):"
    kubectl get pods -n "$KONG_NAMESPACE"
    
    echo ""
    print_info "PVCs in $NAMESPACE:"
    kubectl get pvc -n "$NAMESPACE"
    
    echo ""
}

# Function to show access info
show_access_info() {
    print_info "========================================="
    print_info "Access Information"
    print_info "========================================="
    echo ""
    print_info "Development Environment:"
    echo "  - Kong Proxy: http://localhost:30081"
    echo "  - Host: dev.amazon-api.local"
    echo "  - Namespace: amazon-api-dev"
    echo "  - Kong Namespace: kong-dev"
    echo ""
    print_info "Production Environment:"
    echo "  - Kong Proxy: http://localhost:30080"
    echo "  - Host: api.amazon-store.com"
    echo "  - Namespace: amazon-api-prod"
    echo "  - Kong Namespace: kong-prod"
    echo ""
    print_info "Example API Calls:"
    echo "  # Dev"
    echo "  curl -H 'Host: dev.amazon-api.local' http://localhost:30081/users"
    echo ""
    echo "  # Prod"
    echo "  curl -H 'Host: api.amazon-store.com' http://localhost:30080/users"
    echo ""
}

# Main script
main() {
    local ENVIRONMENT="${1:-both}"
    
    print_info "Amazon Store - Environment Deployment Script"
    echo ""
    
    check_kubectl
    
    case "$ENVIRONMENT" in
        dev)
            deploy_environment "dev"
            verify_environment "dev"
            ;;
        prod)
            deploy_environment "prod"
            verify_environment "prod"
            ;;
        both)
            deploy_environment "dev"
            deploy_environment "prod"
            
            print_info "========================================="
            print_info "Verification"
            print_info "========================================="
            verify_environment "dev"
            verify_environment "prod"
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            echo "Usage: $0 [dev|prod|both]"
            echo "  dev  - Deploy only development environment"
            echo "  prod - Deploy only production environment"
            echo "  both - Deploy both environments (default)"
            exit 1
            ;;
    esac
    
    show_access_info
    
    print_info "========================================="
    print_info "Deployment Complete!"
    print_info "========================================="
}

# Run main function
main "$@"
