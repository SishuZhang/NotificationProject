#!/bin/bash

# This script helps import existing AWS resources into Terraform state
# to avoid conflicts when resources already exist

set -e

# Set default AWS region
AWS_REGION=${AWS_REGION:-"us-east-2"}
SUFFIX=${SUFFIX:-""}

echo "Generating Terraform import commands for existing resources..."

# Check if IAM role already exists
IAM_ROLE_NAME="lambda_execution_role${SUFFIX:+-$SUFFIX}"
if aws iam get-role --role-name $IAM_ROLE_NAME --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_iam_role.lambda_role $IAM_ROLE_NAME"
fi

# Check if IAM policy already exists
IAM_POLICY_NAME="lambda_notification_policy${SUFFIX:+-$SUFFIX}"
IAM_POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$IAM_POLICY_NAME'].Arn" --output text --region $AWS_REGION 2>/dev/null)
if [ ! -z "$IAM_POLICY_ARN" ]; then
  echo "terraform import aws_iam_policy.lambda_policy $IAM_POLICY_ARN"
fi

# Check if DynamoDB table already exists
DYNAMODB_TABLE="notification_status${SUFFIX:+-$SUFFIX}"
if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_dynamodb_table.notification_status $DYNAMODB_TABLE"
fi

# Check if Lambda functions already exist
LAMBDA_API="notification_api_lambda${SUFFIX:+-$SUFFIX}"
if aws lambda get-function --function-name $LAMBDA_API --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_lambda_function.notification_api_lambda $LAMBDA_API"
fi

LAMBDA_EMAIL="email_worker_lambda${SUFFIX:+-$SUFFIX}"
if aws lambda get-function --function-name $LAMBDA_EMAIL --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_lambda_function.email_worker_lambda $LAMBDA_EMAIL"
fi

LAMBDA_SMS="sms_worker_lambda${SUFFIX:+-$SUFFIX}"
if aws lambda get-function --function-name $LAMBDA_SMS --region $AWS_REGION 2>/dev/null; then
  echo "terraform import aws_lambda_function.sms_worker_lambda $LAMBDA_SMS"
fi

# Check if SQS queues already exist
EMAIL_QUEUE="email-queue${SUFFIX:+-$SUFFIX}"
EMAIL_QUEUE_URL=$(aws sqs get-queue-url --queue-name $EMAIL_QUEUE --query 'QueueUrl' --output text --region $AWS_REGION 2>/dev/null)
if [ ! -z "$EMAIL_QUEUE_URL" ]; then
  echo "terraform import aws_sqs_queue.email_queue $EMAIL_QUEUE_URL"
fi

SMS_QUEUE="sms-queue${SUFFIX:+-$SUFFIX}"
SMS_QUEUE_URL=$(aws sqs get-queue-url --queue-name $SMS_QUEUE --query 'QueueUrl' --output text --region $AWS_REGION 2>/dev/null)
if [ ! -z "$SMS_QUEUE_URL" ]; then
  echo "terraform import aws_sqs_queue.sms_queue $SMS_QUEUE_URL"
fi

echo "Done. Run the commands above to import existing resources into Terraform state."
echo "Or run with -var=\"resource_suffix=unique_value\" to create new resources with different names." 