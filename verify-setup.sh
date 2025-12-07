#!/usr/bin/env bash
# Setup verification script for Amazon Store API project

set -e

echo "🔍 Verifying Amazon Store API Setup..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track issues
ISSUES=0

# Check Java
echo -n "Checking Java 21... "
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -eq 21 ]; then
        echo -e "${GREEN}✓${NC} Found Java $JAVA_VERSION"
    else
        echo -e "${YELLOW}⚠${NC} Found Java $JAVA_VERSION (Java 21 recommended)"
        ((ISSUES++))
    fi
else
    echo -e "${RED}✗${NC} Java not found"
    ((ISSUES++))
fi

# Check Maven
echo -n "Checking Maven... "
if command -v mvn &> /dev/null; then
    MVN_VERSION=$(mvn -v 2>&1 | head -n1 | awk '{print $3}')
    echo -e "${GREEN}✓${NC} Found Maven $MVN_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Maven not found (will use ./mvnw wrapper)"
fi

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,$//')
    echo -e "${GREEN}✓${NC} Found Docker $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker ps &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker daemon is running"
    else
        echo -e "  ${RED}✗${NC} Docker daemon is not running"
        ((ISSUES++))
    fi
else
    echo -e "${RED}✗${NC} Docker not found"
    ((ISSUES++))
fi

# Check kubectl
echo -n "Checking kubectl... "
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} Found kubectl $KUBECTL_VERSION"
else
    echo -e "${RED}✗${NC} kubectl not found"
    ((ISSUES++))
fi

# Check Minikube
echo -n "Checking Minikube... "
if command -v minikube &> /dev/null; then
    MINIKUBE_VERSION=$(minikube version --short 2>/dev/null)
    echo -e "${GREEN}✓${NC} Found Minikube $MINIKUBE_VERSION"
    
    # Check if Minikube is running
    if minikube status &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Minikube cluster is running"
    else
        echo -e "  ${YELLOW}⚠${NC} Minikube cluster is not running (run 'minikube start')"
    fi
else
    echo -e "${RED}✗${NC} Minikube not found"
    ((ISSUES++))
fi

# Check .env file
echo -n "Checking .env file... "
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} Found .env file"
    
    # Check if variables are set (not just placeholders)
    if grep -q "your_.*_here" .env 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} .env contains placeholder values - update with real credentials"
    fi
else
    echo -e "${YELLOW}⚠${NC} .env file not found (copy from .env.example)"
fi

# Check project structure
echo -n "Checking project structure... "
REQUIRED_DIRS=("amazon-api-users" "jenkins" "k8s")
MISSING_DIRS=()

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓${NC} All required directories present"
else
    echo -e "${RED}✗${NC} Missing directories: ${MISSING_DIRS[*]}"
    ((ISSUES++))
fi

# Check if application compiles
echo -n "Checking if Spring Boot app compiles... "
cd amazon-api-users
if ./mvnw compile -q &> /dev/null; then
    echo -e "${GREEN}✓${NC} Application compiles successfully"
else
    echo -e "${RED}✗${NC} Application failed to compile"
    ((ISSUES++))
fi
cd ..

echo ""
echo "═══════════════════════════════════════════════"

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Setup verification complete! All checks passed.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Ensure .env has real credentials (not placeholders)"
    echo "  2. Start Jenkins: docker-compose up -d"
    echo "  3. Start Minikube: minikube start"
    echo "  4. Access Jenkins: http://localhost:8080"
else
    echo -e "${YELLOW}⚠ Setup verification found $ISSUES issue(s).${NC}"
    echo "Please resolve the issues above before proceeding."
fi

echo "═══════════════════════════════════════════════"
