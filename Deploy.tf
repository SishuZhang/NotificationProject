provider "aws" {
  region = "us-east-1"
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

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda_logs"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Functions
resource "aws_lambda_function" "entry_lambda" {
  filename      = "lambda.zip"
  function_name = "entry_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  source_code_hash = filebase64sha256("lambda.zip")
  environment {
    variables = {
      SQS_EMAIL_QUEUE = aws_sqs_queue.email_queue.arn
      SQS_SMS_QUEUE   = aws_sqs_queue.sms_queue.arn
      SQS_PUSH_QUEUE  = aws_sqs_queue.push_queue.arn
    }
  }
}

resource "aws_lambda_function" "worker_lambda" {
  filename      = "worker_lambda.zip"
  function_name = "worker_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  source_code_hash = filebase64sha256("worker_lambda.zip")
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.notification_status.name
    }
  }
}

# API Gateway with JWT Authentication via Cognito
resource "aws_cognito_user_pool" "user_pool" {
  name = "notification-user-pool"
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "notification-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  generate_secret = false
}

resource "aws_api_gateway_rest_api" "notification_api" {
  name        = "notification-api"
  description = "API for notifications"
}

resource "aws_api_gateway_authorizer" "cognito_auth" {
  name          = "cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.notification_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.user_pool.arn]
}



# API Gateway Resource and Methods with Cognito Authentication
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
  rest_api_id = aws_api_gateway_rest_api.notification_api.id
  resource_id = aws_api_gateway_resource.notification.id
  http_method = aws_api_gateway_method.post_notification.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.entry_lambda.invoke_arn
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
}

# CloudWatch Alarms for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-error-alarm"
  metric_name         = "Errors"
  namespace          = "AWS/Lambda"
  statistic          = "Sum"
  period             = 300
  evaluation_periods = 1
  threshold          = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions      = ["arn:aws:sns:us-east-1:605134449510:LambdaErrors"]
}
