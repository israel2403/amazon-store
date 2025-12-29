#!/bin/bash
# Setup Kafka Port Forwarding using Vagrant SSH
# This script creates SSH tunnels from host to Vagrant VMs

set -e

HOST_IP="192.168.1.79"
VAGRANT_DIR="${VAGRANT_DIR:-/home/isra/Projects/VMs}"

# Port mappings
declare -A DEV_FORWARDS=(
    ["9092"]="kafka-dev-1:192.168.50.11:9092"
    ["9093"]="kafka-dev-2:192.168.50.12:9092"
    ["9094"]="kafka-dev-3:192.168.50.13:9092"
)

declare -A PROD_FORWARDS=(
    ["9095"]="kafka-prod-1:192.168.50.21:9092"
    ["9096"]="kafka-prod-2:192.168.50.22:9092"
    ["9097"]="kafka-prod-3:192.168.50.23:9092"
)

setup_forward() {
    local host_port=$1
    local vm_name=$2
    local vm_ip=$3
    local vm_port=$4
    
    echo "Setting up forward: ${HOST_IP}:${host_port} -> ${vm_name} (${vm_ip}:${vm_port})"
    
    # Kill existing forward on this port
    pkill -f "ssh.*${host_port}:${vm_ip}:${vm_port}" 2>/dev/null || true
    
    # Create SSH tunnel through Vagrant
    cd "$VAGRANT_DIR" && \
    vagrant ssh ${vm_name} -- -f -N \
        -L ${HOST_IP}:${host_port}:${vm_ip}:${vm_port} \
        2>/dev/null &
}

echo "Starting Kafka port forwards..."
echo "================================"

# Setup DEV forwards
for port in "${!DEV_FORWARDS[@]}"; do
    IFS=':' read -r vm_name vm_ip vm_port <<< "${DEV_FORWARDS[$port]}"
    setup_forward "$port" "$vm_name" "$vm_ip" "$vm_port"
done

# Setup PROD forwards
for port in "${!PROD_FORWARDS[@]}"; do
    IFS=':' read -r vm_name vm_ip vm_port <<< "${PROD_FORWARDS[$port]}"
    setup_forward "$port" "$vm_name" "$vm_ip" "$vm_port"
done

sleep 2
echo ""
echo "Port forward status:"
echo "===================="
for port in 9092 9093 9094 9095 9096 9097; do
    if ss -tln | grep -q "${HOST_IP}:${port} "; then
        echo "✓ Port ${port} is forwarded"
    else
        echo "✗ Port ${port} is NOT forwarded"
    fi
done

echo ""
echo "To stop forwards: pkill -f 'ssh.*vagrant.*LocalForward'"
