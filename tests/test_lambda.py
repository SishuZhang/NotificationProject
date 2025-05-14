import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the parent directory to the path so we can import the lambda modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import lambda_function
import worker_lambda

class TestLambdaFunctions(unittest.TestCase):
    
    @patch('lambda_function.sqs')
    @patch('lambda_function.table')
    def test_standard_notification(self, mock_table, mock_sqs):
        # Set up mocks
        mock_sqs.send_message.return_value = {'MessageId': '1234'}
        mock_table.put_item.return_value = {}
        
        # Test event
        event = {
            'body': json.dumps({
                'type': 'email',
                'recipient': 'test@example.com',
                'subject': 'Test Subject',
                'message': 'Test Message'
            })
        }
        
        # Execute the lambda function
        response = lambda_function.lambda_handler(event, None)
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertIn('message_id', response_body)
        self.assertEqual(response_body['type'], 'standard_notification')
        
        # Verify mocks were called correctly
        mock_sqs.send_message.assert_called_once()
        mock_table.put_item.assert_called_once()
    
    @patch('lambda_function.sqs')
    @patch('lambda_function.table')
    def test_job_notification(self, mock_table, mock_sqs):
        # Set up mocks
        mock_sqs.send_message.return_value = {'MessageId': '1234'}
        mock_table.put_item.return_value = {}
        
        # Test event
        event = {
            'body': json.dumps({
                'type': 'email',
                'recipient': 'test@example.com',
                'job_search': True,
                'job_title': 'Software Engineer',
                'job_location': 'Remote'
            })
        }
        
        # Execute the lambda function
        response = lambda_function.lambda_handler(event, None)
        
        # Verify the response
        self.assertEqual(response['statusCode'], 200)
        response_body = json.loads(response['body'])
        self.assertIn('message_id', response_body)
        self.assertEqual(response_body['type'], 'job_notification')
        
        # Verify mocks were called correctly
        mock_sqs.send_message.assert_called_once()
        call_args = mock_table.put_item.call_args[1]['Item']
        self.assertTrue(call_args['job_search'])
        self.assertEqual(call_args['job_title'], 'Software Engineer')
    
    @patch('worker_lambda.search_indeed_jobs')
    @patch('worker_lambda.send_email')
    @patch('worker_lambda.update_status')
    def test_job_notification_processing(self, mock_update_status, mock_send_email, mock_search_jobs):
        # Set up mocks
        mock_search_jobs.return_value = [
            {
                'title': 'Software Engineer',
                'company': 'Example Corp',
                'location': 'Remote',
                'date': 'Just posted',
                'link': 'https://example.com/job'
            }
        ]
        mock_send_email.return_value = {'success': True, 'message_id': '1234'}
        
        # Test event
        event = {
            'Records': [
                {
                    'messageId': 'test-message-id',
                    'body': json.dumps({
                        'message_id': 'test-message-id',
                        'type': 'email',
                        'recipient': 'test@example.com',
                        'job_search': True,
                        'job_title': 'Software Engineer',
                        'job_location': 'Remote'
                    })
                }
            ]
        }
        
        # Execute the lambda function
        worker_lambda.lambda_handler(event, None)
        
        # Verify mocks were called correctly
        mock_search_jobs.assert_called_once_with('Software Engineer', 'Remote')
        mock_send_email.assert_called_once()
        self.assertEqual(mock_update_status.call_count, 2)  # Called for 'processing' and 'sent'

if __name__ == '__main__':
    unittest.main() 