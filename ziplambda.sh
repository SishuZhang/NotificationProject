#!/bin/bash

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Lambda packaging...${NC}"

# Make sure we're in the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR"

# Create a temporary directory for packaging
TEMP_DIR="./temp_lambda_packages"
mkdir -p "$TEMP_DIR"

# Clean up existing zip files
rm -f lambda.zip worker_lambda.zip

# Package the API lambda
echo -e "${YELLOW}Packaging API Lambda function...${NC}"
cp lambda.py "$TEMP_DIR/"
cd "$TEMP_DIR"

# Install dependencies for API Lambda
echo -e "${YELLOW}Installing dependencies for API Lambda...${NC}"
if [ -f "../requirements-api.txt" ]; then
    pip install -r ../requirements-api.txt -t .
else
    pip install boto3 -t .
fi

# Create zip file
zip -r ../lambda.zip .

# Clean up
cd ..
rm -rf "$TEMP_DIR"/*

# Package the worker lambda with dependencies
echo -e "${YELLOW}Packaging Worker Lambda function...${NC}"
cp worker_lambda.py "$TEMP_DIR/"
cd "$TEMP_DIR"

# Install dependencies for worker Lambda
echo -e "${YELLOW}Installing dependencies for Worker Lambda...${NC}"
if [ -f "../requirements-worker.txt" ]; then
    pip install -r ../requirements-worker.txt -t .
else
    pip install boto3 requests beautifulsoup4 -t .
fi

# Create zip file
zip -r ../worker_lambda.zip .

# Clean up
cd ..
rm -rf "$TEMP_DIR"

# Verify the packages
echo -e "${GREEN}Lambda packages created:${NC}"
ls -la *.zip

echo -e "${GREEN}Packaging completed successfully!${NC}"

