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
    
    if [ ${COMMAND} == 'apply' ]
    then
        echo "Terraform ${COMMAND}"
        terraform ${COMMAND} -auto-approve
    fi

    if [ ${COMMAND} == 'destroy' ]
    then
        echo "Terraform ${COMMAND}"
        terraform ${COMMAND} -auto-approve
    fi

    if [ ${COMMAND} == 'import' ]
    then
        echo "Terraform ${COMMAND} aws_instance.tf_ec2 ${INSTANCE_ID}"
        terraform ${COMMAND} aws_instance.tf_ec2 ${INSTANCE_ID}
    fi
fi
