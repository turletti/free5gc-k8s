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

NAMESPACE="free5gc"

print_header "Checking cluster for existing Core Deployment"
print_subheader "Checking if namespace '$NAMESPACE' exists"
kubectl get namespace $NAMESPACE 2>/dev/null
if [ $? -ne 0 ]; then
    print_error "Namespace '$NAMESPACE' not found. Exiting removal process."
    exit 1
fi

print_header "Removing persistent storage (Core Deployment [1/4])"
print_subheader "Deleting MongoDB configurations"
kubectl delete -k mongodb -n $NAMESPACE
print_success "MongoDB configurations deleted. Note that PV is not cleared automatically."

print_header "Deleting 5G Network Configuration (Core Deployment [2/4])"
kubectl delete -k networks5g -n $NAMESPACE
print_success "5G network configuration deleted."


print_header "Deleting free5gc (Core Deployment [3/4])"
kubectl delete --wait=true -k free5gc -n $NAMESPACE
print_success "free5gc deleted."


print_header "Deleting free5gc WebUI (Core Deployment [4/4])"
kubectl delete --wait=true -k free5gc-webui -n $NAMESPACE
print_success "free5gc webui deleted."

# Wait until all free5gc pods are deleted
print_subheader "Waiting for all free5gc pods to be deleted"
while [ "$(kubectl get pods -n "$NAMESPACE" -l="app=free5gc" -o jsonpath='{.items[*].metadata.name}')" != "" ]; do
    sleep 5
    echo "Waiting for all pods to be deleted in namespace $NAMESPACE..."
done
print_success "All free5gc pods deleted in namespace $NAMESPACE."

# Optionally, delete the namespace
# Uncomment the following lines if you want to delete the namespace
# print_header "Deleting namespace $NAMESPACE"
# kubectl delete namespace $NAMESPACE
# print_success "Namespace '$NAMESPACE' deleted."

# Final success message
print_header "Removal Complete"
print_success "free5gc core removed successfully."
