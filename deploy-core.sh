#!/bin/bash

# Function to print in color
print_header() {
    echo -e "\n\e[1;34m############################### $1 ###############################\e[0m"
}

print_success() {
    echo -e "\e[1;32m$1\e[0m"
}

print_error() {
    echo -e "\e[1;31mERROR: $1\e[0m"
}

print_subheader() {
    echo -e "\e[1;36m--- $1 ---\e[0m"
}

# Set the namespace for free5gc
NAMESPACE="free5gc"

DEPLOYMENT_OPTION="free5gc"

print_header "Preparing cluster for 5G network deployment"

print_subheader "Checking if namespace '$NAMESPACE' exists"
kubectl get namespace $NAMESPACE 2>/dev/null || {
    print_error "Namespace '$NAMESPACE' not found. Creating it now..."
    kubectl create namespace $NAMESPACE
    print_success "Namespace '$NAMESPACE' created."
}

print_header "Adding Persistent Storage (Core Deployment [1/4])"
print_subheader "Applying MongoDB configurations"
kubectl apply -k mongodb -n $NAMESPACE
print_success "MongoDB configurations applied."

# Function to wait for a pod to be ready based on its label
wait_for_pod_ready() {
    local label_key=$1
    local label_value=$2
    echo "Waiting for pod with label $label_key=$label_value to be ready in namespace $NAMESPACE..."

    while [ "$(kubectl get pods -n "$NAMESPACE" -l="$label_key=$label_value" -o jsonpath='{.items[*].status.containerStatuses[0].ready}')" != "true" ]; do
        sleep 5
        echo "Waiting for pod $label_value to be ready..."
    done
    print_success "Pod $label_value is ready."
}

# Wait for MongoDB pod to be ready
wait_for_pod_ready "app.kubernetes.io/name" "mongodb"

# Apply 5G network configurations
print_header "Applying 5G Network Configuration (Core Deployment [2/4])"
print_subheader "Applying OVS-CNI NADs"
kubectl apply -k networks5g -n $NAMESPACE
print_success "OVS-CNI NADs applied."

# Function to check Network Attachment Definition (NAD)
check_nad() {
    local network_name=$1
    echo "Checking NAD '$network_name' in namespace '$NAMESPACE'..."

    kubectl get net-attach-def -n "$NAMESPACE" | grep "$network_name" > /dev/null
    if [ $? -ne 0 ]; then
        print_error "NAD '$network_name' not found in '$NAMESPACE'. Please check the 'networks5g' subdirectory."
        exit 1
    fi
    print_success "NAD '$network_name' found in $NAMESPACE."
}

print_subheader "Checking required NADs"
check_nad "n2network"
check_nad "n3network"
check_nad "n4network"

print_header "Deploying free5gc core (Core Deployment [3/4])"
kubectl apply -k $DEPLOYMENT_OPTION -n $NAMESPACE
print_success "free5gc deployed."

print_subheader "Waiting for Core pods to be ready"
wait_for_pod_ready "nf" "nrf"
wait_for_pod_ready "nf" "amf"
wait_for_pod_ready "nf" "udr"
wait_for_pod_ready "nf" "nssf"
print_success "Core pods ready."

#print_header "Preparing core for adding subscribers (Core Deployment [4/4])"
#print_subheader "Installing Python dependencies"
#pip3 install -r requirements.txt
#print_success "Python dependencies installed."


print_subheader "Deploying free5gc Web UI"
kubectl apply -k free5gc-webui -n $NAMESPACE
wait_for_pod_ready "nf" "webui"
print_success "free5gc web UI deployed."

print_subheader "Setting Up MongoDB Admin Account"
python3 mongo-tools/add-admin-account.py
print_success "MongoDB admin account created successfully."

# Final message for the user
print_header "Deployment Complete"
echo -e "\e[1;33mfree5gc core deployment is complete and ready to use. Please follow these next steps:\e[0m"
echo "1. Check the core logs for AMF, SMF, and UPF to ensure the core is functioning correctly."
echo -e "2. Access the web UI at \e[1mhttp://localhost:30505\e[0m and log in with the user \e[1m'admin'\e[0m and password \e[1m'free5gc'\e[0m to add subscribers."
