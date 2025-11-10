#!/bin/bash

# EC2 Instance Management Script
# This script manages EC2 instances by:
# 1. Listing instances in a given region
# 2. Checking their instance type
# 3. Converting to g6.8xlarge if needed
# 4. Restarting the instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET_INSTANCE_TYPE="g6.8xlarge" # "g6.8xlarge" | "g4dn.xlarge"
LIST_INSTANCES=false
INTERACTIVE_MODE=false
INITIAL_ARG_COUNT=$#

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

# Function to prompt for input
prompt_input() {
    local prompt_text=$1
    local default_value=$2
    local is_secret=$3
    local user_input
    
    # Redirect prompt to stderr so it displays (not captured by command substitution)
    if [ -n "$default_value" ]; then
        echo -n "$prompt_text [$default_value]: " >&2
    else
        echo -n "$prompt_text: " >&2
    fi
    
    if [ "$is_secret" = "true" ]; then
        # Hide input for secrets
        read -s user_input
        echo "" >&2  # New line after hidden input
    else
        read -r user_input
    fi
    
    # Use default if no input provided
    if [ -z "$user_input" ] && [ -n "$default_value" ]; then
        echo "$default_value"
    else
        echo "$user_input"
    fi
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt_text=$1
    local default_value=$2
    local user_input
    
    # Redirect prompt to stderr so it displays (not captured by command substitution)
    if [ "$default_value" = "y" ]; then
        echo -n "$prompt_text [Y/n]: " >&2
    elif [ "$default_value" = "n" ]; then
        echo -n "$prompt_text [y/N]: " >&2
    else
        echo -n "$prompt_text [y/n]: " >&2
    fi
    
    read -r user_input
    user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$user_input" ] && [ -n "$default_value" ]; then
        echo "$default_value"
    else
        echo "$user_input"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

EC2 Instance Management Script

OPTIONS:
    --region REGION                AWS region (required, e.g., us-east-2)
    --instance-id ID               EC2 Instance ID (required unless --list-instances or --interactive)
    --access-key-id KEY            AWS Access Key ID
    --secret-access-key SECRET     AWS Secret Access Key
    --target-type TYPE             Target instance type (default: g6.8xlarge)
    --list-instances               List all instances in the region and exit
    --interactive                  Interactive mode - choose instance from a list
    -h, --help                     Display this help message

EXAMPLES:
    # Fully interactive mode (EASIEST - just run with no arguments!)
    $0
    
    # Interactive mode with some parameters pre-filled
    $0 --region us-east-2 --interactive

    # List all instances in a region
    $0 --region us-east-2 --list-instances

    # Convert specific instance to g6.8xlarge
    $0 --region us-east-2 --instance-id i-1234567890abcdef0

    # Use environment variables for credentials (script will still prompt for missing params)
    export AWS_ACCESS_KEY_ID=your_key
    export AWS_SECRET_ACCESS_KEY=your_secret
    $0

NOTE:
    - If you run the script without any arguments, it will interactively prompt you for all required information.
    - You can provide some parameters via command line and the script will prompt for any missing ones.
    - AWS credentials can be provided via command line, environment variables, or interactive prompts.

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        --instance-id)
            INSTANCE_ID="$2"
            shift 2
            ;;
        --access-key-id)
            AWS_ACCESS_KEY_ID="$2"
            shift 2
            ;;
        --secret-access-key)
            AWS_SECRET_ACCESS_KEY="$2"
            shift 2
            ;;
        --target-type)
            TARGET_INSTANCE_TYPE="$2"
            shift 2
            ;;
        --list-instances)
            LIST_INSTANCES=true
            shift
            ;;
        --interactive)
            INTERACTIVE_MODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Function to interactively collect parameters
collect_parameters_interactively() {
    print_header "EC2 Instance Management - Configuration"
    
    echo "Let's gather the required information to manage your EC2 instance."
    echo ""
    
    # Prompt for region if not provided
    if [ -z "$REGION" ]; then
        echo "Common AWS regions:"
        echo "  - us-east-2 (Ohio) [default]"
        echo "  - us-east-1 (N. Virginia)"
        echo "  - us-west-2 (Oregon)"
        echo "  - eu-west-1 (Ireland)"
        echo "  - ap-southeast-1 (Singapore)"
        echo ""
        REGION=$(prompt_input "Enter AWS region" "ap-southeast-1")
    fi
    
    # Prompt for AWS credentials if not set
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        echo ""
        AWS_ACCESS_KEY_ID=$(prompt_input "Enter AWS Access Key ID")
    fi
    
    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        AWS_SECRET_ACCESS_KEY=$(prompt_input "Enter AWS Secret Access Key" "" "true")
    fi
    
    # Export credentials
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    
    # Prompt for target instance type if using default
    if [ "$TARGET_INSTANCE_TYPE" = "g6.8xlarge" ]; then
        echo ""
        local change_type=$(prompt_yes_no "Use default target instance type (g6.8xlarge)?" "y")
        if [ "$change_type" = "n" ] || [ "$change_type" = "no" ]; then
            TARGET_INSTANCE_TYPE=$(prompt_input "Enter target instance type" "g6.8xlarge")
        fi
    fi
    
    # Ask if user wants to use interactive mode or provide instance ID
    if [ -z "$INSTANCE_ID" ] && [ "$INTERACTIVE_MODE" != true ]; then
        echo ""
        local use_interactive=$(prompt_yes_no "Do you want to select an instance from a list?" "y")
        if [ "$use_interactive" = "y" ] || [ "$use_interactive" = "yes" ]; then
            INTERACTIVE_MODE=true
        else
            echo ""
            INSTANCE_ID=$(prompt_input "Enter EC2 Instance ID (e.g., i-1234567890abcdef0)")
        fi
    fi
    
    echo ""
}

# If no arguments provided at all, run in fully interactive mode
if [ "$INITIAL_ARG_COUNT" -eq 0 ]; then
    collect_parameters_interactively
else
    # Validate required parameters for non-interactive usage
    if [ -z "$REGION" ] && [ "$LIST_INSTANCES" != true ]; then
        collect_parameters_interactively
    fi
    
    # Export AWS credentials if provided
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        export AWS_ACCESS_KEY_ID
    fi
    
    if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        export AWS_SECRET_ACCESS_KEY
    fi
    
    # Prompt for credentials if not set and not in environment
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            echo ""
            AWS_ACCESS_KEY_ID=$(prompt_input "Enter AWS Access Key ID")
            export AWS_ACCESS_KEY_ID
        fi
        
        if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            AWS_SECRET_ACCESS_KEY=$(prompt_input "Enter AWS Secret Access Key" "" "true")
            export AWS_SECRET_ACCESS_KEY
        fi
    fi
fi

# Test AWS credentials
print_info "Testing AWS credentials..."
AWS_TEST_OUTPUT=$(aws ec2 describe-regions --region "$REGION" 2>&1)
if [ $? -ne 0 ]; then
    print_error "Failed to authenticate with AWS. Please check your credentials."
    print_error "Debug Info:"
    print_error "  Region: $REGION"
    print_error "  AWS CLI Output: $AWS_TEST_OUTPUT"
    exit 1
fi
print_success "AWS credentials validated successfully"

print_info "Connected to AWS Region: $REGION"

# Function to list all instances
list_instances() {
    print_header "Listing EC2 Instances in $REGION"
    
    INSTANCES=$(aws ec2 describe-instances \
        --region "$REGION" \
        --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType,State.Name]' \
        --output text 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to list instances in region $REGION"
        print_error "Debug Info:"
        print_error "  AWS CLI Output: $INSTANCES"
        return 1
    fi
    
    if [ -z "$INSTANCES" ]; then
        print_warn "No instances found in region $REGION"
        return
    fi
    
    printf "%-20s %-30s %-20s %-15s\n" "Instance ID" "Name" "Instance Type" "State"
    echo "--------------------------------------------------------------------------------"
    
    while IFS=$'\t' read -r instance_id name instance_type state; do
        if [ -z "$name" ]; then
            name="N/A"
        fi
        printf "%-20s %-30s %-20s %-15s\n" "$instance_id" "$name" "$instance_type" "$state"
    done <<< "$INSTANCES"
}

# Function to interactively select an instance
select_instance_interactive() {
    print_header "Select EC2 Instance in $REGION"
    
    # Get instances
    INSTANCES=$(aws ec2 describe-instances \
        --region "$REGION" \
        --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType,State.Name]' \
        --output text 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to retrieve instances from region $REGION"
        print_error "Debug Info:"
        print_error "  AWS CLI Output: $INSTANCES"
        return 1
    fi
    
    if [ -z "$INSTANCES" ]; then
        print_error "No instances found in region $REGION"
        return 1
    fi
    
    # Store instances in array
    declare -a instance_ids
    declare -a instance_names
    declare -a instance_types
    declare -a instance_states
    local index=0
    
    while IFS=$'\t' read -r instance_id name instance_type state; do
        if [ -z "$name" ]; then
            name="N/A"
        fi
        instance_ids[$index]=$instance_id
        instance_names[$index]=$name
        instance_types[$index]=$instance_type
        instance_states[$index]=$state
        ((index++))
    done <<< "$INSTANCES"
    
    # Display instances with numbers
    echo "Available EC2 Instances:"
    echo ""
    printf "%3s  %-20s %-30s %-20s %-15s\n" "#" "Instance ID" "Name" "Instance Type" "State"
    echo "---------------------------------------------------------------------------------------------"
    
    for i in "${!instance_ids[@]}"; do
        local num=$((i + 1))
        printf "%3d) %-20s %-30s %-20s %-15s\n" \
            "$num" \
            "${instance_ids[$i]}" \
            "${instance_names[$i]}" \
            "${instance_types[$i]}" \
            "${instance_states[$i]}"
    done
    
    echo ""
    echo "---------------------------------------------------------------------------------------------"
    
    # Prompt user to select
    local total_instances=${#instance_ids[@]}
    local selected_num
    
    while true; do
        echo -n "Enter the number of the instance to convert (1-$total_instances, or 'q' to quit): " >&2
        read -r selected_num
        
        # Check if user wants to quit
        if [ "$selected_num" = "q" ] || [ "$selected_num" = "Q" ]; then
            print_warn "Operation cancelled by user"
            return 1
        fi
        
        # Validate input is a number
        if ! [[ "$selected_num" =~ ^[0-9]+$ ]]; then
            print_error "Please enter a valid number"
            continue
        fi
        
        # Validate range
        if [ "$selected_num" -lt 1 ] || [ "$selected_num" -gt "$total_instances" ]; then
            print_error "Please enter a number between 1 and $total_instances"
            continue
        fi
        
        # Valid selection
        break
    done
    
    # Get selected instance (arrays are 0-indexed)
    local selected_index=$((selected_num - 1))
    SELECTED_INSTANCE_ID="${instance_ids[$selected_index]}"
    SELECTED_INSTANCE_NAME="${instance_names[$selected_index]}"
    SELECTED_INSTANCE_TYPE="${instance_types[$selected_index]}"
    SELECTED_INSTANCE_STATE="${instance_states[$selected_index]}"
    
    echo ""
    print_success "Selected instance: $SELECTED_INSTANCE_ID ($SELECTED_INSTANCE_NAME)"
    echo ""
    
    return 0
}

# Function to get instance information
get_instance_info() {
    local instance_id=$1
    
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0]' \
        --output json 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Instance $instance_id not found or you don't have permission to access it"
        print_error "Debug Info:"
        print_error "  Region: $REGION"
        print_error "  Instance ID: $instance_id"
        print_error "  AWS CLI Output: $INSTANCE_INFO"
        return 1
    fi
    
    return 0
}

# Function to get instance type
get_instance_type() {
    local instance_id=$1
    echo "$INSTANCE_INFO" | jq -r '.InstanceType'
}

# Function to get instance state
get_instance_state() {
    local instance_id=$1
    echo "$INSTANCE_INFO" | jq -r '.State.Name'
}

# Function to get instance name
get_instance_name() {
    local instance_id=$1
    local name=$(echo "$INSTANCE_INFO" | jq -r '.Tags[]? | select(.Key=="Name") | .Value')
    if [ -z "$name" ]; then
        echo "N/A"
    else
        echo "$name"
    fi
}

# Function to check if instance type is available in region
check_instance_type_availability() {
    local instance_type=$1
    
    print_info "Checking if instance type '$instance_type' is available in region $REGION..."
    
    INSTANCE_TYPE_CHECK=$(aws ec2 describe-instance-type-offerings \
        --region "$REGION" \
        --filters "Name=instance-type,Values=$instance_type" \
        --query 'InstanceTypeOfferings[0].InstanceType' \
        --output text 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to check instance type availability"
        print_error "Debug Info:"
        print_error "  Region: $REGION"
        print_error "  Instance Type: $instance_type"
        print_error "  AWS CLI Output: $INSTANCE_TYPE_CHECK"
        return 1
    fi
    
    if [ "$INSTANCE_TYPE_CHECK" == "None" ] || [ -z "$INSTANCE_TYPE_CHECK" ]; then
        print_error "Instance type '$instance_type' is NOT available in region $REGION"
        print_error "Debug Info:"
        print_error "  You can check available instance types with:"
        print_error "  aws ec2 describe-instance-type-offerings --region $REGION --filters \"Name=instance-type,Values=g6.*\" --query 'InstanceTypeOfferings[*].InstanceType' --output table"
        return 1
    fi
    
    print_success "Instance type '$instance_type' is available in region $REGION"
    return 0
}

# Function to stop instance
stop_instance() {
    local instance_id=$1
    
    print_info "Stopping instance $instance_id..."
    
    STOP_OUTPUT=$(aws ec2 stop-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" \
        --output json 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to stop instance"
        print_error "Debug Info:"
        print_error "  Region: $REGION"
        print_error "  Instance ID: $instance_id"
        print_error "  AWS CLI Output: $STOP_OUTPUT"
        return 1
    fi
    
    print_info "Waiting for instance to stop..."
    WAIT_OUTPUT=$(aws ec2 wait instance-stopped \
        --region "$REGION" \
        --instance-ids "$instance_id" 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Timeout waiting for instance to stop"
        print_error "Debug Info:"
        print_error "  AWS CLI Output: $WAIT_OUTPUT"
        return 1
    fi
    
    print_success "Instance stopped successfully"
    return 0
}

# Function to modify instance type
modify_instance_type() {
    local instance_id=$1
    local new_type=$2
    local aws_output

    print_info "Modifying instance type to $new_type..."
    aws_output=$(aws ec2 modify-instance-attribute \
                --region "$REGION" \
                --instance-id "$instance_id" \
                --instance-type "{\"Value\": \"$new_type\"}" 2>&1)

    # Check the exit code of the aws command
    if [[ $? -ne 0 ]]; then
        print_error "Failed to modify instance type for $instance_id."
        print_error "Debug Info:"
        print_error "  Region: $REGION"
        print_error "  Instance ID: $instance_id"
        print_error "  Target Type: $new_type"
        print_error "  AWS CLI Output: $aws_output"
        return 1
    fi
    
    print_success "Instance type modified to $new_type successfully"
    return 0
}

# Function to start instance
start_instance() {
    local instance_id=$1
    
    print_info "Starting instance $instance_id..."
    
    START_OUTPUT=$(aws ec2 start-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" \
        --output json 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to start instance"
        print_error "Debug Info:"
        print_error "  Region: $REGION"
        print_error "  Instance ID: $instance_id"
        print_error "  AWS CLI Output: $START_OUTPUT"
        return 1
    fi
    
    print_info "Waiting for instance to start..."
    WAIT_OUTPUT=$(aws ec2 wait instance-running \
        --region "$REGION" \
        --instance-ids "$instance_id" 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Timeout waiting for instance to start"
        print_error "Debug Info:"
        print_error "  AWS CLI Output: $WAIT_OUTPUT"
        return 1
    fi
    
    print_success "Instance started successfully"
    return 0
}

# Function to restart instance
restart_instance() {
    local instance_id=$1
    local current_state=$2
    
    if [ "$current_state" == "stopped" ]; then
        start_instance "$instance_id"
        return $?
    elif [ "$current_state" == "running" ]; then
        stop_instance "$instance_id" && \
        sleep 2 && \
        start_instance "$instance_id"
        return $?
    else
        print_error "Instance is in '$current_state' state. Cannot restart."
        return 1
    fi
}

# Function to process instance
process_instance() {
    local instance_id=$1
    local target_type=$2
    
    print_header "Processing Instance: $instance_id"
    
    # Get instance information
    if ! get_instance_info "$instance_id"; then
        return 1
    fi
    
    CURRENT_TYPE=$(get_instance_type "$instance_id")
    CURRENT_STATE=$(get_instance_state "$instance_id")
    INSTANCE_NAME=$(get_instance_name "$instance_id")
    
    echo "Instance Name:          $INSTANCE_NAME"
    echo "Current Instance Type:  $CURRENT_TYPE"
    echo "Current State:          $CURRENT_STATE"
    echo "Target Instance Type:   $target_type"
    echo ""
    
    # Check if conversion is needed
    if [ "$CURRENT_TYPE" == "$target_type" ]; then
        print_info "Instance is already $target_type. No conversion needed."
        echo ""
        print_info "Restarting instance..."
        
        if restart_instance "$instance_id" "$CURRENT_STATE"; then
            print_header "✓ Instance restarted successfully!"
            return 0
        else
            return 1
        fi
    else
        print_warn "Conversion needed: $CURRENT_TYPE -> $target_type"
        echo ""
        
        # Check if target instance type is available in the region BEFORE stopping
        if ! check_instance_type_availability "$target_type"; then
            print_error "Cannot proceed with conversion. Instance type not available."
            return 1
        fi
        echo ""
        
        # Stop instance if running
        if [ "$CURRENT_STATE" != "stopped" ]; then
            if ! stop_instance "$instance_id"; then
                return 1
            fi
        fi
        
        # Modify instance type
        if ! modify_instance_type "$instance_id" "$target_type"; then
            return 1
        fi
        
        # Start instance
        sleep 2
        if ! start_instance "$instance_id"; then
            return 1
        fi
        
        print_header "✓ Successfully converted instance to $target_type and started it!"
        return 0
    fi
}

# Main execution
if [ "$LIST_INSTANCES" == true ]; then
    list_instances
    exit 0
fi

# Interactive mode
if [ "$INTERACTIVE_MODE" == true ]; then
    if ! select_instance_interactive; then
        exit 1
    fi
    INSTANCE_ID="$SELECTED_INSTANCE_ID"
fi

# Check if instance ID is provided
if [ -z "$INSTANCE_ID" ]; then
    print_error "Instance ID is required. Use --instance-id, --interactive, or --list-instances"
    usage
fi

# Process the instance
if process_instance "$INSTANCE_ID" "$TARGET_INSTANCE_TYPE"; then
    echo ""
    print_success "Operation completed successfully!"
    echo ""
    print_info "Please wait up to 10 minutes for the OpenShift cluster to be up and running properly."
    exit 0
else
    echo ""
    print_error "Operation failed. Please check the error messages above."
    exit 1
fi

