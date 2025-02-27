import json
import boto3
import json
import os

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")
sns = boto3.client("sns")
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE"))

def send_email(recipient, message):
    return ses.send_email(
        Source="no-reply@example.com",
        Destination={"ToAddresses": [recipient]},
        Message={
            "Subject": {"Data": "Notification"},
            "Body": {"Text": {"Data": message}},
        },
    )

def send_sms(recipient, message):
    return sns.publish(PhoneNumber=recipient, Message=message)

def lambda_handler(event, context):
    for record in event["Records"]:
        try:
            message = json.loads(record["body"])
            notification_type = message["type"]
            recipient = message["recipient"]
            content = message["message"]
            
            if notification_type == "email":
                send_email(recipient, content)
            elif notification_type == "sms":
                send_sms(recipient, content)
            else:
                raise ValueError("Unsupported notification type")
            
            table.put_item(Item={
                "message_id": record["messageId"],
                "status": "sent",
                "type": notification_type,
                "recipient": recipient,
                "message": content
            })
            
        except Exception as e:
            print(f"Failed to process message: {record["messageId"]}, Error: {str(e)}")
            table.put_item(Item={
                "message_id": record["messageId"],
                "status": "failed",
                "error": str(e),
                "type": message.get("type", "unknown"),
                "recipient": message.get("recipient", "unknown"),
                "message": message.get("message", "unknown")
            })
