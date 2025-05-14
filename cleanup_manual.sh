#!/bin/bash

# Script to manually cleanup resources that might not be properly destroyed by Terraform
# Use this as a last resort if terraform destroy doesn't clean up everything

set -e

echo "🚨 WARNING: This will manually delete resources from your AWS account 🚨"
echo "This is a brute force approach and should only be used if terraform destroy fails."
echo ""
echo "This action cannot be undone. All data will be permanently deleted."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Manual cleanup canceled."
    exit 0
fi

# Set the AWS region
AWS_REGION=${AWS_REGION:-"us-east-2"}
RESOURCE_PREFIX=${RESOURCE_PREFIX:-"notification"}

echo "Using AWS region: $AWS_REGION"
echo "Resource prefix: $RESOURCE_PREFIX"
echo ""

# Function to delete resources with error handling
delete_resources() {
    resource_type=$1
    find_command=$2
    delete_command=$3
    
    echo "Finding $resource_type..."
    resources=$(eval "$find_command")
    
    if [[ -z "$resources" ]]; then
        echo "No $resource_type found."
        return
    fi
    
    echo "Found $resource_type to delete:"
    echo "$resources"
    echo ""
    
    # Split the resources into an array
    readarray -t resource_array <<< "$resources"
    
    for resource in "${resource_array[@]}"; do
        if [[ -z "$resource" ]]; then
            continue
        fi
        
        echo "Deleting $resource_type: $resource"
        eval "$delete_command \"$resource\"" || echo "Failed to delete $resource, continuing..."
    done
    
    echo "Completed $resource_type cleanup."
    echo ""
}

echo "Starting manual cleanup..."

# 1. Delete Lambda functions
echo "Cleaning up Lambda functions..."
delete_resources "Lambda functions" \
    "aws lambda list-functions --region $AWS_REGION --query \"Functions[?contains(FunctionName, '$RESOURCE_PREFIX')].FunctionName\" --output text" \
    "aws lambda delete-function --region $AWS_REGION --function-name"

# 2. Delete SQS queues
echo "Cleaning up SQS queues..."
delete_resources "SQS queues" \
    "aws sqs list-queues --region $AWS_REGION --queue-name-prefix $RESOURCE_PREFIX --query 'QueueUrls[]' --output text" \
    "aws sqs delete-queue --region $AWS_REGION --queue-url"

# 3. Delete DynamoDB tables
echo "Cleaning up DynamoDB tables..."
delete_resources "DynamoDB tables" \
    "aws dynamodb list-tables --region $AWS_REGION --query \"TableNames[?contains(@, '$RESOURCE_PREFIX')]\" --output text" \
    "aws dynamodb delete-table --region $AWS_REGION --table-name"

# 4. Delete Cognito User Pools
echo "Cleaning up Cognito User Pools..."
# First find the user pool IDs
USER_POOLS=$(aws cognito-idp list-user-pools --region $AWS_REGION --max-results 60 --query "UserPools[?contains(Name, '$RESOURCE_PREFIX')].[Id, Name]" --output text)
if [[ ! -z "$USER_POOLS" ]]; then
    echo "Found User Pools:"
    echo "$USER_POOLS"
    echo ""
    
    # Split the user pools into an array
    readarray -t user_pool_array <<< "$USER_POOLS"
    
    for pool_line in "${user_pool_array[@]}"; do
        if [[ -z "$pool_line" ]]; then
            continue
        fi
        
        # Extract the pool ID (first field)
        pool_id=$(echo "$pool_line" | awk '{print $1}')
        pool_name=$(echo "$pool_line" | awk '{print $2}')
        
        if [[ ! -z "$pool_id" ]]; then
            echo "Deleting Cognito User Pool: $pool_name ($pool_id)"
            aws cognito-idp delete-user-pool --region $AWS_REGION --user-pool-id "$pool_id" || echo "Failed to delete User Pool $pool_id, continuing..."
        fi
    done
else
    echo "No Cognito User Pools found."
fi
echo ""

# 5. Delete IAM roles and policies
echo "Cleaning up IAM roles..."
ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, '$RESOURCE_PREFIX')].RoleName" --output text)
if [[ ! -z "$ROLES" ]]; then
    echo "Found IAM roles:"
    echo "$ROLES"
    echo ""
    
    # Split the roles into an array
    readarray -t role_array <<< "$ROLES"
    
    for role in "${role_array[@]}"; do
        if [[ -z "$role" ]]; then
            continue
        fi
        
        # First, detach all policies
        echo "Detaching policies from role: $role"
        POLICIES=$(aws iam list-attached-role-policies --role-name "$role" --query "AttachedPolicies[].PolicyArn" --output text)
        
        for policy in $POLICIES; do
            echo "  Detaching policy: $policy"
            aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" || echo "Failed to detach policy $policy, continuing..."
        done
        
        # Delete role
        echo "Deleting IAM role: $role"
        aws iam delete-role --role-name "$role" || echo "Failed to delete role $role, continuing..."
    done
else
    echo "No IAM roles found."
fi
echo ""

echo "Cleaning up IAM policies..."
POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, '$RESOURCE_PREFIX')].[PolicyName, Arn]" --output text)
if [[ ! -z "$POLICIES" ]]; then
    echo "Found IAM policies:"
    echo "$POLICIES"
    echo ""
    
    # Split the policies into an array
    readarray -t policy_array <<< "$POLICIES"
    
    for policy_line in "${policy_array[@]}"; do
        if [[ -z "$policy_line" ]]; then
            continue
        fi
        
        # Extract the policy ARN (second field)
        policy_name=$(echo "$policy_line" | awk '{print $1}')
        policy_arn=$(echo "$policy_line" | awk '{print $2}')
        
        if [[ ! -z "$policy_arn" ]]; then
            echo "Deleting IAM policy: $policy_name ($policy_arn)"
            aws iam delete-policy --policy-arn "$policy_arn" || echo "Failed to delete policy $policy_arn, continuing..."
        fi
    done
else
    echo "No IAM policies found."
fi
echo ""

# 6. Delete API Gateway endpoints
echo "Cleaning up API Gateway..."
API_IDS=$(aws apigateway get-rest-apis --region $AWS_REGION --query "items[?contains(name, '$RESOURCE_PREFIX')].id" --output text)
if [[ ! -z "$API_IDS" ]]; then
    echo "Found API Gateway APIs:"
    echo "$API_IDS"
    echo ""
    
    # Split the API IDs into an array
    readarray -t api_array <<< "$API_IDS"
    
    for api_id in "${api_array[@]}"; do
        if [[ -z "$api_id" ]]; then
            continue
        fi
        
        echo "Deleting API Gateway API: $api_id"
        aws apigateway delete-rest-api --region $AWS_REGION --rest-api-id "$api_id" || echo "Failed to delete API Gateway $api_id, continuing..."
    done
else
    echo "No API Gateway APIs found."
fi
echo ""

echo "✅ Manual cleanup completed."
echo "Note: There might still be some resources that were not deleted."
echo "Check your AWS Management Console to verify all resources are removed." 