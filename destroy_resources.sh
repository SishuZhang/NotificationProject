#!/bin/bash

# Script to destroy all AWS resources created by Terraform
# This will remove everything from your AWS account that was created by this project

set -e

echo "🚨 WARNING: This will destroy ALL resources created by Terraform in this project 🚨"
echo "Resources to be destroyed include:"
echo "  - Lambda functions"
echo "  - API Gateway"
echo "  - SQS queues"
echo "  - DynamoDB tables"
echo "  - Cognito User Pool"
echo "  - IAM roles and policies"
echo "  - CloudWatch alarms and logs"
echo ""
echo "This action cannot be undone. All data will be permanently deleted."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Destruction canceled."
    exit 0
fi

echo ""
echo "Starting terraform destroy..."

# Run terraform destroy
terraform destroy -auto-approve

echo ""
echo "✅ All resources have been destroyed."

# Check for any leftover resources that might not have been properly tracked by Terraform
echo ""
echo "Checking for any leftover resources..."

# Region for resource check
AWS_REGION=${AWS_REGION:-"us-east-2"}

# Function to check if any resources exist with prefix
check_resources() {
    resource_type=$1
    command=$2
    
    echo "Checking for $resource_type..."
    result=$(eval "$command")
    
    if [[ ! -z "$result" ]]; then
        echo "⚠️ Found leftover $resource_type:"
        echo "$result"
        echo "You may need to delete these manually."
    else
        echo "✅ No leftover $resource_type found."
    fi
}

# Check for Lambda functions
check_resources "Lambda functions" "aws lambda list-functions --region $AWS_REGION --query \"Functions[?starts_with(FunctionName, 'notification_') || starts_with(FunctionName, 'email_worker_') || starts_with(FunctionName, 'sms_worker_')].FunctionName\" --output text"

# Check for SQS queues
check_resources "SQS queues" "aws sqs list-queues --region $AWS_REGION --queue-name-prefix email --query 'QueueUrls' --output text"

# Check for DynamoDB tables
check_resources "DynamoDB tables" "aws dynamodb list-tables --region $AWS_REGION --query \"TableNames[?starts_with(@, 'notification_')]\" --output text"

# Check for Cognito User Pools
check_resources "Cognito User Pools" "aws cognito-idp list-user-pools --region $AWS_REGION --max-results 60 --query \"UserPools[?starts_with(Name, 'notification-')].Name\" --output text"

echo ""
echo "Resource cleanup complete." 