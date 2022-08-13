#!/bin/bash

echo "Running ECS task for terraform commands"

#printenv

echo "Pulling git repo for given resource"
git clone https://github.com/${GIT_ORG}/${GIT_REPO}.git

cd ${GIT_REPO}

echo ${GIT_REPO}

echo "IOD Provider: ${IACPROVIDER}"

#if IACPROVIDER = terraform
if [ ${IACPROVIDER} == 'terraform' ]
then
    echo "executing Terraform Flow"

    echo "Creating terraform project config"
    echo ${RESOURCE_CONFIG} > terraform.tfvars.json
    cat terraform.tfvars.json

    echo "Terraform init"
    terraform init --backend-config="bucket=${BACKEND_BUCKET}" --backend-config="key=${BACKEND_S3_KEY}"
    
    echo "Terraform ${COMMAND}"
    terraform ${COMMAND} -auto-approve
fi

#if IACPROVIDER = pulumi
if [ ${IACPROVIDER} == 'pulumi' ]
then
    echo "executing Pulumi Flow"

    echo "Pulumi ${COMMAND}"
    pulumi ${COMMAND}
fi
