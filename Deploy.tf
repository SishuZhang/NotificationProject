variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

provider "aws" {
  region = var.aws_region
}

# SQS Queues with Dead Letter Queues (DLQ)
resource "aws_sqs_queue" "email_dlq" {
  name                      = "email-dlq"
  message_retention_seconds = 86400
}

resource "aws_sqs_queue" "email_queue" {
  name                      = "email-queue"
  message_retention_seconds = 86400
  redrive_policy            = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "sms_dlq" {
  name                      = "sms-dlq"
  message_retention_seconds = 86400
}

resource "aws_sqs_queue" "sms_queue" {
  name                      = "sms-queue"
  message_retention_seconds = 86400
  redrive_policy            = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sms_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "push_dlq" {
  name                      = "push-dlq"
  message_retention_seconds = 86400
}

resource "aws_sqs_queue" "push_queue" {
  name                      = "push-queue"
  message_retention_seconds = 86400
  redrive_policy            = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.push_dlq.arn
    maxReceiveCount     = 3
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# Add additional policies for SQS, SES, SNS, and DynamoDB access
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_notification_policy"
  description = "Policy for Lambda to access notification services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = [
          aws_sqs_queue.email_queue.arn,
          aws_sqs_queue.sms_queue.arn,
          aws_sqs_queue.email_dlq.arn,
          aws_sqs_queue.sms_dlq.arn
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*",
        Effect = "Allow"
      },
      {
        Action = [
          "sns:Publish"
        ],
        Resource = "*",
        Effect = "Allow"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ],
        Resource = aws_dynamodb_table.notification_status.arn,
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Functions
resource "aws_lambda_function" "notification_api_lambda" {
  filename         = "lambda.zip"
  function_name    = "notification_api_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      SQS_EMAIL_QUEUE = aws_sqs_queue.email_queue.url
      SQS_SMS_QUEUE   = aws_sqs_queue.sms_queue.url
      DYNAMODB_TABLE  = aws_dynamodb_table.notification_status.name
    }
  }
}

resource "aws_lambda_function" "email_worker_lambda" {
  filename         = "worker_lambda.zip"
  function_name    = "email_worker_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "worker_lambda.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("worker_lambda.zip")
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.notification_status.name
      NOTIFICATION_TYPE = "email"
    }
  }
}

resource "aws_lambda_function" "sms_worker_lambda" {
  filename         = "worker_lambda.zip"
  function_name    = "sms_worker_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "worker_lambda.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("worker_lambda.zip")
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.notification_status.name
      NOTIFICATION_TYPE = "sms"
    }
  }
}

# Lambda Event Source Mappings
resource "aws_lambda_event_source_mapping" "email_queue_mapping" {
  event_source_arn = aws_sqs_queue.email_queue.arn
  function_name    = aws_lambda_function.email_worker_lambda.arn
  batch_size       = 10
}

resource "aws_lambda_event_source_mapping" "sms_queue_mapping" {
  event_source_arn = aws_sqs_queue.sms_queue.arn
  function_name    = aws_lambda_function.sms_worker_lambda.arn
  batch_size       = 10
}

# API Gateway with Cognito Authentication
resource "aws_cognito_user_pool" "user_pool" {
  name = "notification-user-pool"
  
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  
  auto_verified_attributes = ["email"]
  
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
    
    string_attribute_constraints {
      min_length = 5
      max_length = 255
    }
  }
  
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
  
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
  
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject = "Your Notification Service Verification Code"
    email_message = "Your verification code is {####}. This code will expire in 24 hours."
  }
  
  admin_create_user_config {
    allow_admin_create_user_only = false
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "notification-system-${random_string.domain_prefix.result}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "random_string" "domain_prefix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  numeric = true
}

resource "aws_cognito_user_pool_client" "client" {
  name                         = "notification-client"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  generate_secret              = false
  explicit_auth_flows          = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  access_token_validity        = 24
  refresh_token_validity       = 30
  callback_urls                = ["https://example.com/callback"]
  allowed_oauth_flows          = ["implicit"]
  allowed_oauth_scopes         = ["openid", "email", "profile", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]
}

resource "aws_api_gateway_rest_api" "notification_api" {
  name        = "notification-api"
  description = "API for sending notifications"
}

resource "aws_api_gateway_authorizer" "cognito_auth" {
  name          = "cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.notification_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.user_pool.arn]
}

# API Gateway Resources and Methods
resource "aws_api_gateway_resource" "notification" {
  rest_api_id = aws_api_gateway_rest_api.notification_api.id
  parent_id   = aws_api_gateway_rest_api.notification_api.root_resource_id
  path_part   = "send"
}

resource "aws_api_gateway_method" "post_notification" {
  rest_api_id   = aws_api_gateway_rest_api.notification_api.id
  resource_id   = aws_api_gateway_resource.notification.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.notification_api.id
  resource_id             = aws_api_gateway_resource.notification.id
  http_method             = aws_api_gateway_method.post_notification.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notification_api_lambda.invoke_arn
}

# API Gateway Deployment and Stage
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  
  rest_api_id = aws_api_gateway_rest_api.notification_api.id
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.notification_api.id
  stage_name    = "prod"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.notification_api.execution_arn}/*/*"
}

# DynamoDB Table
resource "aws_dynamodb_table" "notification_status" {
  name           = "notification_status"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "message_id"

  attribute {
    name = "message_id"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }
  
  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    projection_type    = "ALL"
    write_capacity     = 0
    read_capacity      = 0
  }
}

# CloudWatch Alarm for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-error-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "This metric monitors lambda function errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.notification_api_lambda.function_name
  }
}

# Outputs
output "api_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/send"
  description = "The URL endpoint for sending notifications"
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.client.id
  description = "Cognito App Client ID for authentication"
}

output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
  description = "Cognito User Pool ID"
}

output "aws_region" {
  value = var.aws_region
  description = "AWS region where resources are deployed"
}

output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
  description = "Cognito domain URL for sign-up and sign-in"
}

output "hosted_ui_url" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.client.id}&response_type=token&scope=aws.cognito.signin.user.admin&redirect_uri=https://example.com/callback"
  description = "URL for the hosted UI login page"
}
