#!/bin/bash

################################################################################
# Script: check-operatorhub-nvidia.sh
# Description: Checks if OperatorHub is properly configured and NVIDIA GPU 
#              Operator is accessible
# Prerequisites: oc CLI must be installed and logged in to OpenShift cluster
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Check if oc command is available
if ! command -v oc &> /dev/null; then
    print_status "ERROR" "oc CLI is not installed or not in PATH"
    exit 1
fi

# Check if logged in to OpenShift
if ! oc whoami &> /dev/null; then
    print_status "ERROR" "Not logged in to OpenShift cluster. Please run 'oc login' first"
    exit 1
fi

print_header "OperatorHub and NVIDIA GPU Operator Verification"

# Get cluster info
CLUSTER_VERSION=$(oc get clusterversion -o jsonpath='{.items[0].status.desired.version}' 2>/dev/null || echo "unknown")
CURRENT_USER=$(oc whoami 2>/dev/null)
print_status "INFO" "Connected to OpenShift cluster version: $CLUSTER_VERSION"
print_status "INFO" "Current user: $CURRENT_USER"

echo ""
print_header "Step 1: Checking OperatorHub Status"

# Check if OperatorHub is available
if oc get operatorhub cluster &> /dev/null; then
    print_status "SUCCESS" "OperatorHub is available"
    
    # Check if OperatorHub is disabled
    DISABLED=$(oc get operatorhub cluster -o jsonpath='{.spec.disableAllDefaultSources}' 2>/dev/null)
    if [ "$DISABLED" == "true" ]; then
        print_status "WARNING" "All default sources are disabled in OperatorHub"
    else
        print_status "SUCCESS" "Default sources are enabled in OperatorHub"
    fi
else
    print_status "ERROR" "OperatorHub is not available"
    exit 1
fi

echo ""
print_header "Step 2: Checking Catalog Sources"

# Check if openshift-marketplace namespace exists
if oc get namespace openshift-marketplace &> /dev/null; then
    print_status "SUCCESS" "Namespace 'openshift-marketplace' exists"
else
    print_status "ERROR" "Namespace 'openshift-marketplace' does not exist"
    exit 1
fi

# List all catalog sources
CATALOG_SOURCES=$(oc get catalogsources -n openshift-marketplace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [ -z "$CATALOG_SOURCES" ]; then
    print_status "ERROR" "No catalog sources found in openshift-marketplace"
    exit 1
else
    print_status "SUCCESS" "Found catalog sources: $CATALOG_SOURCES"
fi

# Check specifically for certified-operators catalog source
if echo "$CATALOG_SOURCES" | grep -q "certified-operators"; then
    print_status "SUCCESS" "Catalog source 'certified-operators' is available"
    
    # Check the status of certified-operators
    CATALOG_STATUS=$(oc get catalogsource certified-operators -n openshift-marketplace -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null)
    if [ "$CATALOG_STATUS" == "READY" ]; then
        print_status "SUCCESS" "Catalog source 'certified-operators' is READY"
    else
        print_status "WARNING" "Catalog source 'certified-operators' status: $CATALOG_STATUS"
    fi
else
    print_status "ERROR" "Catalog source 'certified-operators' not found"
    exit 1
fi

echo ""
print_header "Step 3: Checking NVIDIA GPU Operator Availability"

# Check if gpu-operator-certified package is available
print_status "INFO" "Searching for NVIDIA GPU Operator package (this may take a moment)..."

PACKAGE_CHECK=$(oc get packagemanifests -n openshift-marketplace 2>/dev/null | grep -i "gpu-operator-certified" || echo "")

if [ -n "$PACKAGE_CHECK" ]; then
    print_status "SUCCESS" "NVIDIA GPU Operator package 'gpu-operator-certified' is available"
    
    # Get package details
    PACKAGE_NAME=$(echo "$PACKAGE_CHECK" | awk '{print $1}')
    DEFAULT_CHANNEL=$(oc get packagemanifest "$PACKAGE_NAME" -n openshift-marketplace -o jsonpath='{.status.defaultChannel}' 2>/dev/null)
    AVAILABLE_CHANNELS=$(oc get packagemanifest "$PACKAGE_NAME" -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null)
    CATALOG_SOURCE=$(oc get packagemanifest "$PACKAGE_NAME" -n openshift-marketplace -o jsonpath='{.status.catalogSource}' 2>/dev/null)
    LATEST_CSV=$(oc get packagemanifest "$PACKAGE_NAME" -n openshift-marketplace -o jsonpath="{.status.channels[?(@.name=='$DEFAULT_CHANNEL')].currentCSV}" 2>/dev/null)
    
    echo ""
    print_status "INFO" "Package Name: $PACKAGE_NAME"
    print_status "INFO" "Default Channel: $DEFAULT_CHANNEL"
    print_status "INFO" "Available Channels: $AVAILABLE_CHANNELS"
    print_status "INFO" "Catalog Source: $CATALOG_SOURCE"
    print_status "INFO" "Latest CSV: $LATEST_CSV"
else
    print_status "ERROR" "NVIDIA GPU Operator package 'gpu-operator-certified' not found"
    print_status "INFO" "Available GPU-related packages:"
    oc get packagemanifests -n openshift-marketplace 2>/dev/null | grep -i gpu || echo "  None found"
    exit 1
fi

echo ""
print_header "Step 4: Checking Existing Installation"

# Check if nvidia-gpu-operator namespace exists
if oc get namespace nvidia-gpu-operator &> /dev/null; then
    print_status "WARNING" "Namespace 'nvidia-gpu-operator' already exists"
    
    # Check if subscription exists
    if oc get subscription gpu-operator-certified -n nvidia-gpu-operator &> /dev/null; then
        print_status "WARNING" "NVIDIA GPU Operator subscription already exists"
        
        # Get subscription status
        SUB_STATE=$(oc get subscription gpu-operator-certified -n nvidia-gpu-operator -o jsonpath='{.status.state}' 2>/dev/null)
        INSTALLED_CSV=$(oc get subscription gpu-operator-certified -n nvidia-gpu-operator -o jsonpath='{.status.installedCSV}' 2>/dev/null)
        
        print_status "INFO" "Subscription State: $SUB_STATE"
        print_status "INFO" "Installed CSV: $INSTALLED_CSV"
    else
        print_status "INFO" "No NVIDIA GPU Operator subscription found"
    fi
    
    # Check if ClusterPolicy exists
    if oc get clusterpolicy gpu-cluster-policy &> /dev/null 2>&1; then
        print_status "WARNING" "ClusterPolicy 'gpu-cluster-policy' already exists"
    else
        print_status "INFO" "No ClusterPolicy found"
    fi
else
    print_status "INFO" "Namespace 'nvidia-gpu-operator' does not exist (fresh installation possible)"
fi

echo ""
print_header "Verification Summary"

echo -e "${GREEN}✓ All prerequisite checks passed!${NC}"
echo ""
echo "You can proceed with installing the NVIDIA GPU Operator using:"
echo "  ${YELLOW}oc apply -f openshift/nvidia-gpu-operator-with-timeslicing.yaml${NC}"
echo ""

