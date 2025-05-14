#!/bin/bash

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up recurring job notifications...${NC}"

# Get required inputs
if [ $# -lt 4 ]; then
    echo -e "${RED}Usage: $0 <email|sms> <recipient> \"<job_title>\" \"<job_location>\" [schedule_expression]${NC}"
    echo -e "Example: $0 email user@example.com \"Software Engineer\" \"Remote\" \"rate(1 day)\""
    exit 1
fi

NOTIFICATION_TYPE=$1
RECIPIENT=$2
JOB_TITLE=$3
JOB_LOCATION=$4
SCHEDULE_EXPRESSION=${5:-"rate(1 day)"}

# Validate notification type
if [[ "$NOTIFICATION_TYPE" != "email" && "$NOTIFICATION_TYPE" != "sms" ]]; then
    echo -e "${RED}Error: Notification type must be 'email' or 'sms'${NC}"
    exit 1
fi

# Validate recipient
if [[ "$NOTIFICATION_TYPE" == "email" && ! "$RECIPIENT" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid email address${NC}"
    exit 1
fi

if [[ "$NOTIFICATION_TYPE" == "sms" && ! "$RECIPIENT" =~ ^\+[0-9]{10,15}$ ]]; then
    echo -e "${RED}Error: Invalid phone number format. Use international format with + (e.g., +12345678901)${NC}"
    exit 1
fi

# Get AWS region from Terraform output
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-2")
echo -e "Using AWS region: ${AWS_REGION}"

# Get API URL from Terraform output
API_URL=$(terraform output -raw api_url 2>/dev/null)
if [[ -z "$API_URL" ]]; then
    echo -e "${RED}Error: Could not retrieve API URL from terraform output. Make sure you're in the project directory and terraform has been applied.${NC}"
    exit 1
fi

# Get Cognito info from Terraform output
COGNITO_CLIENT_ID=$(terraform output -raw cognito_app_client_id 2>/dev/null)
USER_POOL_ID=$(terraform output -raw user_pool_id 2>/dev/null)

if [[ -z "$COGNITO_CLIENT_ID" || -z "$USER_POOL_ID" ]]; then
    echo -e "${RED}Error: Could not retrieve Cognito information from terraform output.${NC}"
    exit 1
fi

# Create unique IDs for the resources
RULE_NAME="JobNotification-$(date +%s)"
TARGET_ID="JobTarget-$(date +%s)"
ROLE_NAME="EventBridgeJobNotificationRole-$(date +%s)"

echo -e "${YELLOW}Creating IAM role for EventBridge...${NC}"

# Create trust policy document
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json \
    --region "$AWS_REGION"

# Create policy document
cat > policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "execute-api:Invoke"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "InvokeAPIGateway" \
    --policy-document file://policy.json \
    --region "$AWS_REGION"

# Wait for role to propagate
echo -e "${YELLOW}Waiting for IAM role to propagate...${NC}"
sleep 10

# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text --region "$AWS_REGION")

echo -e "${YELLOW}Creating EventBridge rule...${NC}"

# Create EventBridge rule
aws events put-rule \
    --name "$RULE_NAME" \
    --schedule-expression "$SCHEDULE_EXPRESSION" \
    --state ENABLED \
    --description "Scheduled rule for Indeed job notifications - $JOB_TITLE in $JOB_LOCATION" \
    --region "$AWS_REGION"

# Create the input template for the target
cat > input-template.json << EOF
{
  "body": "{\"type\":\"$NOTIFICATION_TYPE\",\"recipient\":\"$RECIPIENT\",\"job_search\":true,\"job_title\":\"$JOB_TITLE\",\"job_location\":\"$JOB_LOCATION\"}"
}
EOF

# Get API ID from the URL
API_ID=$(echo "$API_URL" | sed -E 's|https://([^.]+)\..*|\1|')

# Create EventBridge target
aws events put-targets \
    --rule "$RULE_NAME" \
    --targets "Id"="$TARGET_ID","Arn"="arn:aws:execute-api:$AWS_REGION:$(aws sts get-caller-identity --query 'Account' --output text):$API_ID/prod/POST/send","RoleArn"="$ROLE_ARN","Input"="$(cat input-template.json | jq -c .)" \
    --region "$AWS_REGION"

# Clean up temp files
rm -f trust-policy.json policy.json input-template.json

echo -e "${GREEN}Successfully set up recurring job notification!${NC}"
echo -e "Job Title: ${JOB_TITLE}"
echo -e "Location: ${JOB_LOCATION}"
echo -e "Recipient: ${RECIPIENT} (${NOTIFICATION_TYPE})"
echo -e "Schedule: ${SCHEDULE_EXPRESSION}"
echo -e "Rule Name: ${RULE_NAME}"

cat << EOF
${YELLOW}
NOTE: To test the notification immediately, you can run:

aws events test-event-pattern --event-pattern '{"source":["aws.events"]}' --event '{"source":["aws.events"],"detail-type":["Scheduled Event"],"resources":["arn:aws:events:$AWS_REGION:$(aws sts get-caller-identity --query 'Account' --output text):rule/$RULE_NAME"]}' --region $AWS_REGION
${NC}
EOF

echo -e "${GREEN}Done!${NC}" 