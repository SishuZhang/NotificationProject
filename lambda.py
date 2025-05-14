import json
import boto3
import os
import uuid
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sqs = boto3.client("sqs")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE"))

# SQS queue URLs from environment variables
QUEUE_URLS = {
    "email": os.getenv("SQS_EMAIL_QUEUE"),
    "sms": os.getenv("SQS_SMS_QUEUE")
}

def lambda_handler(event, context):
    """
    API Gateway Lambda handler for notification requests
    
    Expected request formats:
    
    Standard notification:
    {
        "type": "email" or "sms",
        "recipient": "user@example.com" or "+1234567890",
        "message": "Your notification message",
        "subject": "Optional email subject"
    }
    
    Job notification:
    {
        "type": "email" or "sms",
        "recipient": "user@example.com" or "+1234567890",
        "job_search": true,
        "job_title": "Software Engineer",
        "job_location": "Remote" (optional)
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse request body
        body = json.loads(event.get("body", "{}"))
        
        # Extract and validate required fields
        notification_type = body.get("type")
        recipient = body.get("recipient")
        
        # Handle job search notification
        job_search = body.get("job_search", False)
        
        if job_search:
            # Job notification requires job_title
            job_title = body.get("job_title")
            if not notification_type or not recipient or not job_title:
                return {
                    "statusCode": 400,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": "Missing required fields: type, recipient, or job_title"})
                }
            
            # Use provided subject or default based on job title
            subject = body.get("subject", f"Latest {job_title} Job Opportunities")
            message = body.get("message", "See the latest job opportunities")
            
            # Add job search parameters
            body["job_search"] = True
            body["job_location"] = body.get("job_location", "remote")
            
        else:
            # Standard notification requires message
            message = body.get("message")
            subject = body.get("subject", "Notification")
            
            if not notification_type or not recipient or not message:
                return {
                    "statusCode": 400,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": "Missing required fields: type, recipient, or message"})
                }
        
        # Validate notification type
        if notification_type not in QUEUE_URLS:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": f"Invalid notification type. Supported types: {', '.join(QUEUE_URLS.keys())}"})
            }
        
        # Generate a unique message ID
        message_id = str(uuid.uuid4())
        
        # Prepare message payload
        message_payload = {
            "message_id": message_id,
            "type": notification_type,
            "recipient": recipient,
            "message": message,
            "subject": subject
        }
        
        # Add job search parameters if applicable
        if job_search:
            message_payload["job_search"] = True
            message_payload["job_title"] = job_title
            message_payload["job_location"] = body.get("job_location", "remote")
        
        # Send message to appropriate SQS queue
        queue_url = QUEUE_URLS[notification_type]
        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message_payload)
        )
        
        # Store initial status in DynamoDB
        item = {
            "message_id": message_id,
            "status": "queued",
            "type": notification_type,
            "recipient": recipient,
            "timestamp": int(boto3.client('dynamodb').describe_table(TableName=os.getenv("DYNAMODB_TABLE"))['Table']['CreationDateTime'].timestamp() * 1000)
        }
        
        # Add job information if applicable
        if job_search:
            item["job_search"] = True
            item["job_title"] = job_title
        
        table.put_item(Item=item)
        
        # Return successful response
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Notification queued successfully",
                "message_id": message_id,
                "type": "job_notification" if job_search else "standard_notification"
            })
        }
    
    except json.JSONDecodeError:
        logger.error("Invalid JSON in request body")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Invalid JSON format in request body"})
        }
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Internal server error"})
        }
