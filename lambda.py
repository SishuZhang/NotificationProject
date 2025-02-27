import json
import boto3
import os

# Ensure required libraries are available
try:
    import urllib3
except ImportError:
    print("Error: urllib3 is not installed. Ensure dependencies are installed correctly.")
    raise

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE"))

# Mapping notification types to their respective SQS queues
QUEUE_URLS = {
    "email": os.getenv("SQS_EMAIL_QUEUE"),
    "sms": os.getenv("SQS_SMS_QUEUE"),
    "push": os.getenv("SQS_PUSH_QUEUE"),
}

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        notification_type = body.get("type")
        message = body.get("message")
        recipient = body.get("recipient")
        
        if not notification_type or not message or not recipient:
            return {"statusCode": 400, "body": json.dumps("Missing required fields")}
        
        queue_url = QUEUE_URLS.get(notification_type)
        if not queue_url:
            return {"statusCode": 400, "body": json.dumps("Invalid notification type")}
        
        sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(body))
        
        table.put_item(Item={
            "message_id": context.aws_request_id,
            "status": "queued",
            "type": notification_type,
            "recipient": recipient,
            "message": message
        })
        
        return {"statusCode": 200, "body": json.dumps("Message queued successfully")}
    
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": json.dumps("Invalid JSON format")}
    except boto3.exceptions.Boto3Error as e:
        print(f"AWS SDK Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps("AWS Service Error")}
    except Exception as e:
        print(f"General Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps("Internal Server Error")}
