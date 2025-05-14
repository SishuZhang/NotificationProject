#!/bin/bash

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting serverless notification system deployment...${NC}"

# Check for required tools
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
    exit 1
fi

# Make sure we're in the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR"

# Package Lambda functions
echo -e "${YELLOW}Packaging Lambda functions...${NC}"

# Clean up existing zip files
rm -f lambda.zip worker_lambda.zip

# Package the API lambda
echo "Packaging API Lambda function..."
zip -j lambda.zip lambda.py

# Package the worker lambda
echo "Packaging Worker Lambda function..."
zip -j worker_lambda.zip worker_lambda.py

# Verify the packages
echo "Lambda packages created:"
ls -la *.zip

# Initialize Terraform if needed
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "${YELLOW}Planning deployment...${NC}"
terraform plan -out=tfplan

# Confirm before proceeding
read -p "Do you want to proceed with the deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
fi

# Apply Terraform plan
echo -e "${YELLOW}Applying Terraform plan...${NC}"
terraform apply tfplan

# Output important information
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Serverless Notification System Information:${NC}"
echo -e "API URL: $(terraform output -raw api_url)"
echo -e "Cognito User Pool ID: $(terraform output -raw user_pool_id)"
echo -e "Cognito App Client ID: $(terraform output -raw cognito_app_client_id)"
echo -e "Cognito Domain: $(terraform output -raw cognito_domain)"
echo -e "Hosted UI URL: $(terraform output -raw hosted_ui_url)"

echo -e "${GREEN}Deployment completed successfully!${NC}" 