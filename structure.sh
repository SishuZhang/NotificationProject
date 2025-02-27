#!/bin/bash

set -e

# Install Terraform and AWS CLI if not installed
if ! command -v terraform &> /dev/null
then
    echo "Terraform not found, installing..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install terraform -y
fi

if ! command -v aws &> /dev/null
then
    echo "AWS CLI not found, installing..."
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
fi

# Initialize and apply Terraform
terraform init
terraform apply -auto-approve

echo "Deployment complete!"
