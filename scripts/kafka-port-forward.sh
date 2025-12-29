#!/bin/bash
# Kafka Port Forwarding Script
# Forwards Kafka ports from host to Vagrant VMs so Kubernetes can access them

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Port mapping:
# Dev cluster: host ports 9092-9094 -> VMs 192.168.50.11-13:9092
# Prod cluster: host ports 9095-9097 -> VMs 192.168.50.21-23:9092

HOST_IP="192.168.1.79"

DEV_PORTS=(9092 9093 9094)
DEV_IPS=(192.168.50.11 192.168.50.12 192.168.50.13)

PROD_PORTS=(9095 9096 9097)
PROD_IPS=(192.168.50.21 192.168.50.22 192.168.50.23)

stop_forwards() {
    echo -e "${YELLOW}Stopping existing port forwards...${NC}"
    pkill -f "socat.*TCP-LISTEN" 2>/dev/null || true
    sleep 1
}

start_dev_forwards() {
    echo -e "${GREEN}Starting DEV Kafka port forwards (using socat)...${NC}"
    
    for i in {0..2}; do
        HOST_PORT=${DEV_PORTS[$i]}
        VM_IP=${DEV_IPS[$i]}
        VM_NAME="kafka-dev-$((i+1))"
        
        echo "Forwarding ${HOST_IP}:${HOST_PORT} -> ${VM_IP}:9092"
        
        # Use socat for TCP forwarding
        socat TCP-LISTEN:${HOST_PORT},bind=${HOST_IP},fork,reuseaddr \
            TCP:${VM_IP}:9092 &
        
        sleep 0.2
    done
}

start_prod_forwards() {
    echo -e "${GREEN}Starting PROD Kafka port forwards (using socat)...${NC}"
    
    for i in {0..2}; do
        HOST_PORT=${PROD_PORTS[$i]}
        VM_IP=${PROD_IPS[$i]}
        VM_NAME="kafka-prod-$((i+1))"
        
        echo "Forwarding ${HOST_IP}:${HOST_PORT} -> ${VM_IP}:9092"
        
        # Use socat for TCP forwarding
        socat TCP-LISTEN:${HOST_PORT},bind=${HOST_IP},fork,reuseaddr \
            TCP:${VM_IP}:9092 &
        
        sleep 0.2
    done
}

check_status() {
    echo -e "${YELLOW}Checking port forward status...${NC}"
    
    for port in ${DEV_PORTS[@]} ${PROD_PORTS[@]}; do
        if ss -tln | grep -q ":${port} "; then
            echo -e "${GREEN}✓${NC} Port ${port} is forwarded"
        else
            echo -e "${RED}✗${NC} Port ${port} is NOT forwarded"
        fi
    done
}

case "$1" in
    start)
        stop_forwards
        start_dev_forwards
        start_prod_forwards
        echo ""
        check_status
        ;;
    stop)
        stop_forwards
        echo -e "${GREEN}All port forwards stopped${NC}"
        ;;
    status)
        check_status
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Port Mapping:"
        echo "  Dev:  localhost:9092-9094 -> kafka-dev-1,2,3:9092"
        echo "  Prod: localhost:9095-9097 -> kafka-prod-1,2,3:9092"
        exit 1
        ;;
esac

exit 0
