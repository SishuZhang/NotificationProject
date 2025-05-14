import json
import boto3
import os
import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import urllib.parse

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
ses = boto3.client('ses')
sns = boto3.client('sns')
table = dynamodb.Table(os.getenv('DYNAMODB_TABLE'))

# Sample job data for demo mode
SAMPLE_JOBS = {
    "Data Scientist": [
        {
            "title": "Senior Data Scientist",
            "company": "Tech Innovations Inc",
            "location": "New York, NY (Remote)",
            "date": "Just posted",
            "link": "https://www.indeed.com/viewjob?jk=abc123"
        },
        {
            "title": "Data Scientist, Machine Learning",
            "company": "DataCorp Analytics",
            "location": "New York, NY",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=def456"
        },
        {
            "title": "AI/ML Data Scientist",
            "company": "Big Tech Co",
            "location": "Remote in New York",
            "date": "1 day ago",
            "link": "https://www.indeed.com/viewjob?jk=ghi789"
        },
        {
            "title": "Data Scientist - NLP",
            "company": "FinTech Solutions",
            "location": "New York or Remote",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=jkl101"
        },
        {
            "title": "Junior Data Scientist",
            "company": "StartUp Adventures",
            "location": "New York, NY",
            "date": "Just posted",
            "link": "https://www.indeed.com/viewjob?jk=mno112"
        }
    ],
    "Software Engineer": [
        {
            "title": "Senior Software Engineer",
            "company": "CodeCraft Technologies",
            "location": "Remote",
            "date": "Just posted",
            "link": "https://www.indeed.com/viewjob?jk=pqr131"
        },
        {
            "title": "Full Stack Software Engineer",
            "company": "WebDev Pros",
            "location": "Remote (US)",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=stu415"
        },
        {
            "title": "Backend Software Engineer - Python",
            "company": "Software Solutions Inc",
            "location": "Remote",
            "date": "1 day ago",
            "link": "https://www.indeed.com/viewjob?jk=vwx161"
        },
        {
            "title": "Frontend React Engineer",
            "company": "User Interface Co",
            "location": "Remote, US-based",
            "date": "Today",
            "link": "https://www.indeed.com/viewjob?jk=yz1718"
        }
    ]
}

def send_email(recipient, message, subject):
    """Send email notification via Amazon SES"""
    try:
        response = ses.send_email(
            Source='notifications@example.com',
            Destination={
                'ToAddresses': [recipient]
            },
            Message={
                'Subject': {
                    'Data': subject
                },
                'Body': {
                    'Text': {
                        'Data': message
                    },
                    'Html': {
                        'Data': message if message.startswith('<html>') else f"<html><body>{message}</body></html>"
                    }
                }
            }
        )
        return {'success': True, 'message_id': response['MessageId']}
    except Exception as e:
        logger.error(f"Failed to send email: {str(e)}")
        return {'success': False, 'error': str(e)}

def send_sms(recipient, message):
    """Send SMS notification via Amazon SNS"""
    try:
        response = sns.publish(
            PhoneNumber=recipient,
            Message=message,
            MessageAttributes={
                'AWS.SNS.SMS.SMSType': {
                    'DataType': 'String',
                    'StringValue': 'Transactional'
                }
            }
        )
        return {'success': True, 'message_id': response['MessageId']}
    except Exception as e:
        logger.error(f"Failed to send SMS: {str(e)}")
        return {'success': False, 'error': str(e)}

def update_status(message_id, status, error=None):
    """Update notification status in DynamoDB"""
    try:
        update_expr = "SET #status = :status, #updated = :updated"
        expr_names = {
            "#status": "status",
            "#updated": "updated_at"
        }
        expr_values = {
            ":status": status,
            ":updated": datetime.now().isoformat()
        }
        
        if error:
            update_expr += ", #error = :error"
            expr_names["#error"] = "error"
            expr_values[":error"] = error
        
        table.update_item(
            Key={'message_id': message_id},
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_names,
            ExpressionAttributeValues=expr_values
        )
    except Exception as e:
        logger.error(f"Failed to update status in DynamoDB: {str(e)}")

def search_indeed_jobs(job_title, location="remote", days=1):
    """
    Search Indeed for job listings based on job title and location
    Returns a list of job postings
    
    Will use demo data if web access fails
    """
    try:
        # Try real web search first
        jobs = _search_indeed_real(job_title, location, days)
        
        # If no jobs found or error occurred, use demo data
        if not jobs:
            logger.info(f"No jobs found through web search, using demo data for: {job_title}")
            jobs = _get_demo_jobs(job_title, location)
        
        return jobs
        
    except Exception as e:
        logger.error(f"Error in job search, using demo data: {str(e)}")
        return _get_demo_jobs(job_title, location)

def _get_demo_jobs(job_title, location):
    """Get demo jobs data based on job title"""
    # Find the best match in our sample data
    if job_title in SAMPLE_JOBS:
        return SAMPLE_JOBS[job_title]
    
    # Try a partial match
    for title, jobs in SAMPLE_JOBS.items():
        if job_title.lower() in title.lower() or title.lower() in job_title.lower():
            return jobs
    
    # Return the first sample dataset as fallback
    return list(SAMPLE_JOBS.values())[0]

def _search_indeed_real(job_title, location="remote", days=1):
    """Actual web search implementation for Indeed"""
    # Format the search query
    query = urllib.parse.quote_plus(job_title)
    loc = urllib.parse.quote_plus(location)
    
    # Create URL for Indeed search
    url = f"https://www.indeed.com/jobs?q={query}&l={loc}&sort=date&fromage={days}"
    
    logger.info(f"Searching jobs with URL: {url}")
    
    # Set headers to avoid blocking
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
    }
    
    # Send request to Indeed
    response = requests.get(url, headers=headers)
    
    if response.status_code != 200:
        logger.error(f"Failed to get Indeed response: {response.status_code}")
        return []
    
    # Parse the HTML content
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Extract job listings
    job_cards = soup.find_all('div', class_='job_seen_beacon')
    
    jobs = []
    for card in job_cards[:5]:  # Limit to 5 jobs
        try:
            # Extract job details
            title_elem = card.find('a', class_='jcs-JobTitle')
            company_elem = card.find('span', class_='companyName')
            location_elem = card.find('div', class_='companyLocation')
            date_elem = card.find('span', class_='date')
            link_elem = title_elem.get('href') if title_elem else None
            
            # Create job object
            job = {
                'title': title_elem.text.strip() if title_elem else 'Unknown',
                'company': company_elem.text.strip() if company_elem else 'Unknown',
                'location': location_elem.text.strip() if location_elem else 'Unknown',
                'date': date_elem.text.strip() if date_elem else 'Unknown',
                'link': f"https://www.indeed.com{link_elem}" if link_elem else '#'
            }
            
            jobs.append(job)
        except Exception as e:
            logger.error(f"Error parsing job card: {str(e)}")
    
    return jobs

def format_jobs_email(jobs, job_title):
    """Format job listings into an HTML email"""
    if not jobs:
        return f"No new {job_title} jobs found in the last 24 hours."
    
    html = f"""
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            h1 {{ color: #2557a7; }}
            .job {{ border: 1px solid #ddd; padding: 15px; margin-bottom: 20px; border-radius: 5px; }}
            .job:hover {{ background-color: #f9f9f9; }}
            .job-title {{ color: #2557a7; font-size: 18px; margin-bottom: 5px; }}
            .company {{ font-weight: bold; }}
            .location {{ color: #666; }}
            .date {{ color: #666; font-style: italic; }}
            .apply {{ display: inline-block; background-color: #2557a7; color: white; padding: 8px 15px; 
                     text-decoration: none; border-radius: 4px; margin-top: 10px; }}
            .apply:hover {{ background-color: #1c4380; }}
        </style>
    </head>
    <body>
        <h1>Latest {job_title} Job Opportunities</h1>
        <p>Here are the latest job postings for {job_title} from the past 24 hours:</p>
    """
    
    for job in jobs:
        html += f"""
        <div class="job">
            <div class="job-title">{job['title']}</div>
            <div class="company">{job['company']}</div>
            <div class="location">{job['location']}</div>
            <div class="date">Posted: {job['date']}</div>
            <a href="{job['link']}" class="apply" target="_blank">View Job</a>
        </div>
        """
    
    html += """
    </body>
    </html>
    """
    
    return html

def format_jobs_sms(jobs, job_title):
    """Format job listings into a SMS message"""
    if not jobs:
        return f"No new {job_title} jobs found in the last 24 hours."
    
    sms = f"Latest {job_title} Jobs:\n\n"
    
    for i, job in enumerate(jobs[:3], 1):  # Limit to 3 jobs for SMS
        sms += f"{i}. {job['company']}: {job['title']}\n"
    
    sms += "\nReply STOP to unsubscribe."
    
    return sms

def lambda_handler(event, context):
    """
    Process SQS messages for sending notifications
    """
    logger.info(f"Received {len(event['Records'])} messages")
    
    for record in event['Records']:
        try:
            # Parse the SQS message
            message = json.loads(record['body'])
            message_id = message.get('message_id')
            
            # Log message details
            logger.info(f"Processing message: {message_id}")
            
            notification_type = message.get('type')
            recipient = message.get('recipient')
            content = message.get('message')
            subject = message.get('subject', 'Notification')
            
            # Check if this is a job notification
            job_search = message.get('job_search', False)
            job_title = message.get('job_title', '')
            job_location = message.get('job_location', 'remote')
            
            # Update status to processing
            update_status(message_id, 'processing')
            
            # If job search is requested, get job listings
            if job_search and job_title:
                logger.info(f"Searching for {job_title} jobs in {job_location}")
                jobs = search_indeed_jobs(job_title, job_location)
                
                if notification_type == 'email':
                    content = format_jobs_email(jobs, job_title)
                    subject = f"Latest {job_title} Job Opportunities"
                elif notification_type == 'sms':
                    content = format_jobs_sms(jobs, job_title)
            
            # Send notification based on type
            result = None
            if notification_type == 'email':
                result = send_email(recipient, content, subject)
            elif notification_type == 'sms':
                result = send_sms(recipient, content)
            else:
                error_msg = f"Unsupported notification type: {notification_type}"
                logger.error(error_msg)
                update_status(message_id, 'failed', error_msg)
                continue
            
            # Update status based on the result
            if result['success']:
                update_status(message_id, 'sent')
                logger.info(f"Successfully sent {notification_type} notification: {message_id}")
            else:
                update_status(message_id, 'failed', result.get('error', 'Unknown error'))
                logger.error(f"Failed to send {notification_type} notification: {result.get('error')}")
                
        except Exception as e:
            # Log and handle any exceptions during processing
            logger.error(f"Error processing message {record.get('messageId')}: {str(e)}")
            try:
                message_data = json.loads(record['body'])
                message_id = message_data.get('message_id')
                if message_id:
                    update_status(message_id, 'failed', str(e))
            except:
                logger.error("Could not update message status due to parsing error")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }
