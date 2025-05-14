#!/bin/bash

# This script helps import existing AWS resources into Terraform state
# to avoid conflicts when resources already exist

set -e

# Set default AWS region
AWS_REGION=${AWS_REGION:-"us-east-2"}

echo "Generating Terraform import commands for existing resources..."

# Check if IAM role already exists
IAM_ROLE_NAME="lambda_execution_role"
if aws iam get-role --role-name $IAM_ROLE_NAME --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_iam_role.lambda_role $IAM_ROLE_NAME"
fi

# Check if DynamoDB table already exists
DYNAMODB_TABLE="notification_status"
if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_dynamodb_table.notification_status $DYNAMODB_TABLE"
fi

# Check if Lambda functions already exist
LAMBDA_API="notification_api_lambda"
if aws lambda get-function --function-name $LAMBDA_API --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_lambda_function.notification_api_lambda $LAMBDA_API"
fi

LAMBDA_EMAIL="email_worker_lambda"
if aws lambda get-function --function-name $LAMBDA_EMAIL --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_lambda_function.email_worker_lambda $LAMBDA_EMAIL"
fi

LAMBDA_SMS="sms_worker_lambda"
if aws lambda get-function --function-name $LAMBDA_SMS --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_lambda_function.sms_worker_lambda $LAMBDA_SMS"
fi

echo "Done. Run the commands above to import existing resources into Terraform state."
echo "Or consider using the -var suffix=random_string to create new resources with different names." 