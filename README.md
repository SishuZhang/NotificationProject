# Serverless Job Notification System

A robust serverless notification platform built on AWS that delivers personalized job alerts from Indeed to users via email and SMS. The system uses modern serverless technologies for reliability, cost-efficiency, and scalability.

![Serverless Architecture](https://miro.medium.com/max/1400/1*KIQZxqnKYYPaKv9PxR7cKg.png)

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
  - [Design Principles](#design-principles)
  - [Component Breakdown](#component-breakdown)
  - [Notification Flow](#notification-flow)
- [Technical Implementation](#technical-implementation)
  - [AWS Services](#aws-services)
  - [Infrastructure as Code](#infrastructure-as-code)
  - [CI/CD Pipeline](#cicd-pipeline)
- [Setting Up the Project](#setting-up-the-project)
  - [Prerequisites](#prerequisites)
  - [Deployment Options](#deployment-options)
  - [First-Time Setup](#first-time-setup)
- [Using the Platform](#using-the-platform)
  - [Authentication](#authentication)
  - [API Reference](#api-reference)
  - [Job Subscription Setup](#job-subscription-setup)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Extending the System](#extending-the-system)
- [Development and Testing](#development-and-testing)
- [License](#license)

## Overview

This serverless notification system is designed to help users stay updated on the latest job opportunities based on their interests. It scrapes Indeed for the newest job postings and delivers them via email or SMS, providing a convenient way to get personalized job alerts.

### Why Serverless?

The serverless architecture was chosen to provide:
- **Cost Efficiency**: Pay only for what you use, no idle resources
- **Automatic Scaling**: Handles varying loads without manual intervention
- **Low Maintenance**: No server management required
- **High Availability**: Built-in resiliency with AWS services
- **Rapid Development**: Focus on business logic rather than infrastructure

## Key Features

- **Job Search Notifications**: Automatically fetch and deliver the latest Indeed job postings
- **Multi-Channel Delivery**: Send notifications via email (SES) or SMS (SNS)
- **Scheduled Alerts**: Set up recurring job notifications at preferred intervals
- **Secure Authentication**: API authentication using Amazon Cognito
- **Robust Error Handling**: Dead letter queues for failed notifications
- **Operational Visibility**: Comprehensive logging and monitoring with CloudWatch
- **Infrastructure as Code**: Fully automated deployment with Terraform
- **CI/CD Pipeline**: Automated testing and deployment with GitHub Actions

## Architecture

### Design Principles

The system was designed with the following principles in mind:

1. **Loose Coupling**: Each component focuses on a single responsibility
2. **Resilience**: Multiple layers of error handling and recovery
3. **Scalability**: Automatically scales with demand
4. **Security**: Secure by default with least privilege access
5. **Observability**: Comprehensive logging and monitoring
6. **Maintainability**: Clean code structure and comprehensive documentation

### Component Breakdown

The system consists of the following key components:

- **API Layer**: API Gateway + Cognito authentication
- **Processing Layer**: Lambda functions for API and worker processing
- **Queuing Layer**: SQS queues with dead-letter handling
- **Storage Layer**: DynamoDB for notification status tracking
- **Notification Layer**: SES (email) and SNS (SMS) for delivery
- **Scheduling Layer**: EventBridge for recurring notifications
- **Monitoring Layer**: CloudWatch for logs, metrics, and alarms

### Notification Flow

1. **Request** → A client authenticates with Cognito and sends a notification request
2. **Validation** → API Gateway validates the request and forwards to the API Lambda
3. **Queueing** → The API Lambda enqueues the message to appropriate SQS queue
4. **Processing** → Worker Lambdas consume messages from the queues
5. **Job Fetching** → For job requests, workers fetch the latest job postings
6. **Delivery** → Notifications are sent via email (SES) or SMS (SNS)
7. **Status Tracking** → All steps are tracked in DynamoDB
8. **Error Handling** → Failed messages are sent to Dead Letter Queues for investigation

## Technical Implementation

### AWS Services

- **Lambda**: Serverless compute for API and worker functions
- **API Gateway**: REST API management and request handling
- **SQS**: Message queuing with dead-letter support
- **Cognito**: Authentication and authorization
- **DynamoDB**: NoSQL database for notification status
- **SES**: Email sending service
- **SNS**: SMS notification service
- **EventBridge**: Schedule management for recurring notifications
- **CloudWatch**: Monitoring, logging, and alerting
- **IAM**: Access management and security

### Infrastructure as Code

All infrastructure is defined using Terraform, enabling:

- **Consistent Deployments**: Same infrastructure across all environments
- **Version Control**: Infrastructure changes tracked in git
- **Automated Deployment**: Rapid and reliable deployments
- **Documentation as Code**: Self-documenting infrastructure

### CI/CD Pipeline

The GitHub Actions workflow automates:

- **Dependency Installation**: Managing Python packages
- **Testing**: Running unit and integration tests
- **Packaging**: Creating Lambda deployment packages
- **Deployment**: Applying Terraform configurations
- **Verification**: Validating deployment success
- **Notifications**: Alerting team of deployment status

## Setting Up the Project

### Prerequisites

- **AWS Account** with administrator access
- **GitHub Account** for repository hosting and CI/CD
- **Terraform** (v1.4.6+) installed locally
- **Python** (3.9+) installed locally
- **AWS CLI** configured with appropriate credentials

### Deployment Options

#### Option 1: Local Deployment

1. Clone the repository:
   ```bash
   git clone https://github.com/SishuZhang/NotificationProject.git
   cd NotificationProject
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Package Lambda functions:
   ```bash
   chmod +x ziplambda.sh
   ./ziplambda.sh
   ```

4. Initialize and apply Terraform:
   ```bash
   terraform init
   terraform plan -var="aws_region=us-east-2"
   terraform apply -var="aws_region=us-east-2"
   ```

#### Option 2: Using the Deploy Script

Simply run the deployment script:
```bash
chmod +x deploy_lambdas.sh
./deploy_lambdas.sh
```

This script handles Lambda packaging, Terraform initialization, and deployment in one command.

#### Option 3: GitHub Actions CI/CD

1. Fork the repository to your GitHub account.
2. Set up GitHub Secrets:
   - `AWS_ROLE_ARN`: ARN of an IAM role with deployment permissions
   - `SLACK_WEBHOOK_URL` (optional): For deployment notifications

3. Push to the `main` branch to trigger deployment.
4. Monitor the Actions tab for deployment status.

### First-Time Setup

After deploying the infrastructure, complete these steps:

1. Verify SES email for sending notifications:
   ```bash
   aws ses verify-email-identity --email-address your-email@example.com --region us-east-2
   ```

2. Create a test user in Cognito:
   ```bash
   aws cognito-idp admin-create-user \
     --user-pool-id $(terraform output -raw user_pool_id) \
     --username testuser \
     --temporary-password Test@123 \
     --user-attributes Name=email,Value=your-email@example.com \
     --region us-east-2
   ```

3. Set a permanent password:
   ```bash
   aws cognito-idp admin-set-user-password \
     --user-pool-id $(terraform output -raw user_pool_id) \
     --username testuser \
     --password YourStrongPassword123! \
     --permanent \
     --region us-east-2
   ```

## Using the Platform

### Authentication

#### Option 1: Using Hosted UI (Recommended for Testing)

1. Visit the Cognito hosted UI URL (available in terraform outputs)
2. Register and login to obtain tokens
3. Use the ID token for API requests

#### Option 2: Programmatic Authentication

```bash
aws cognito-idp initiate-auth \
  --client-id $(terraform output -raw cognito_app_client_id) \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=your-username,PASSWORD=your-password \
  --region us-east-2
```

### API Reference

#### Send Standard Email Notification

```bash
curl -X POST $(terraform output -raw api_url) \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email",
    "recipient": "user@example.com",
    "subject": "Test Notification",
    "message": "This is a test message"
  }'
```

#### Send Standard SMS Notification

```bash
curl -X POST $(terraform output -raw api_url) \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "sms",
    "recipient": "+1234567890",
    "message": "This is a test SMS"
  }'
```

#### Send Indeed Job Alert via Email

```bash
curl -X POST $(terraform output -raw api_url) \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email",
    "recipient": "user@example.com",
    "job_search": true,
    "job_title": "Software Engineer",
    "job_location": "Remote"
  }'
```

#### Send Indeed Job Alert via SMS

```bash
curl -X POST $(terraform output -raw api_url) \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "sms",
    "recipient": "+1234567890",
    "job_search": true,
    "job_title": "Data Scientist",
    "job_location": "New York"
  }'
```

### Job Subscription Setup

For recurring job notifications, use the subscription setup script:

```bash
chmod +x setup_job_subscription.sh
./setup_job_subscription.sh email user@example.com "Software Engineer" "Remote" "rate(1 day)"
```

Parameters:
1. Notification type (`email` or `sms`)
2. Recipient (email address or phone number)
3. Job title to search for
4. Job location (optional, defaults to "Remote")
5. Schedule expression (optional, defaults to daily)

Available schedule expressions:
- `rate(1 hour)` - Hourly
- `rate(1 day)` - Daily
- `rate(7 days)` - Weekly
- `cron(0 8 ? * MON-FRI *)` - Weekdays at 8 AM

## Monitoring and Troubleshooting

### CloudWatch Logs

View Lambda function logs:
```bash
aws logs get-log-events \
  --log-group-name /aws/lambda/notification_api_lambda \
  --region us-east-2
```

### DynamoDB Status Check

Check notification status:
```bash
aws dynamodb query \
  --table-name notification_status \
  --key-condition-expression "message_id = :id" \
  --expression-attribute-values '{":id":{"S":"YOUR_MESSAGE_ID"}}' \
  --region us-east-2
```

### Dead Letter Queues

Check failed messages:
```bash
aws sqs receive-message \
  --queue-url $(aws sqs get-queue-url --queue-name email-dlq --region us-east-2 --query 'QueueUrl' --output text) \
  --region us-east-2
```

## Extending the System

### Adding New Notification Types

1. Add a new SQS queue in `Deploy.tf`
2. Create a new worker Lambda function
3. Add the notification type to the API Lambda
4. Update the IAM policies for the new services

### Customizing Job Alerts

The job search functionality can be customized:

1. **Modify search parameters**: Update job title, location, or date range
2. **Adjust formatting**: Edit the `format_jobs_email` and `format_jobs_sms` functions
3. **Add job sources**: Implement additional job boards beyond Indeed
4. **Customize schedule**: Adjust the EventBridge schedule expressions

### Enhancing the Platform

Potential enhancements:

- **Multi-region deployment**: Deploy across multiple AWS regions
- **Advanced filtering**: Filter jobs by salary, company, or experience level
- **User preferences**: Store user preferences in DynamoDB
- **Job analytics**: Track job trends and popular searches
- **Resumé matching**: Match user resumés to job requirements

## Development and Testing

### Local Testing

Test the job search functionality:
```bash
python test_job_search.py "Software Engineer" "Remote"
```

This will:
1. Search for matching jobs
2. Display job details in the console
3. Generate a sample email notification (saved as `sample_email.html`)
4. Output a sample SMS notification
5. Save job data to `jobs.json`

### Running Tests

Execute the test suite:
```bash
pytest tests/
```

### Adding New Features

1. Create feature branch
2. Implement changes
3. Add tests
4. Create a pull request
5. Review and merge

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Project Maintainers

- [Sishu Zhang](https://github.com/SishuZhang)

## Acknowledgments

- AWS for providing the serverless infrastructure
- Indeed for job posting data 