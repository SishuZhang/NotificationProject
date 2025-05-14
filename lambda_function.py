# Import wrapper for tests
from lambda_handler import lambda_handler, sqs, table, uuid, os, json, logging, boto3

# Reexport for tests
__all__ = ['lambda_handler', 'sqs', 'table', 'uuid', 'os', 'json', 'logging', 'boto3'] 