#!/bin/bash

echo "Running ECS task"

#printenv
#f"{app_name}-{app_env}-{resource_type}-{id} use sed my-app-sdc-dev-ec2-ec2-1002/terraform.tfstate

echo "IOD Provider: ${IACPROVIDER}"

#if IACPROVIDER = pulumi
if [ ${IACPROVIDER} == 'pulumi' ]
then
    echo "executing Pulumi Flow"

    #echo ${GIT_REPO}
    mkdir ${GIT_REPO}
    cd ${GIT_REPO}

    echo "Creating pulumi project config"
    echo ${RESOURCE_CONFIG} > payload.json
    cat payload.json

    STACK="$(cut -d'/' -f1 <<<"${BACKEND_S3_KEY}")"
    #echo ${STACK}
    #echo ${PROJECT}

    echo "Run pulumi login"
    #set PULUMI_CONFIG_PASSPHRASE in env variables
    pulumi login --cloud-url s3://${BACKEND_BUCKET}/${STACK}

    echo "Setting up Pulumi project"
    pulumi new https://github.com/${GIT_ORG}/${GIT_REPO}.git -g -n "${PROJECT}" -s "${STACK}" -y --force

    echo "setup environment ..."
    echo "Running Step 1 - python3 -m venv venv"
    python3 -m venv venv
    echo "Running Step 2 - source venv/bin/activate"
    source venv/bin/activate
    echo "Running Step 3 - python -m pip install --upgrade pip setuptools wheel"
    python -m pip install --upgrade pip setuptools wheel
    echo "Running Step 4 - python -m pip install -r requirements.txt"
    python -m pip install -r requirements.txt
    echo "setup complete"

    echo "Running Step 5"
    echo "check if stack is present"
    count="$(pulumi stack ls | grep -i -c ${STACK})"
    echo ${count}

    if [ "$count" -gt 0 ]
    then
        echo "Stack ${STACK} present ... selecting stack ${STACK}"
        echo "pulumi stack select ${STACK}"
        pulumi stack select ${STACK}
        pulumi config refresh
    else
        echo "Stack ${STACK} not present ... creating stack ${STACK}"
        echo "pulumi stack init ${STACK}"
        pulumi stack init ${STACK}
    fi

    echo "creating ${STACK} configuration"
    #if EC2
    if [ ${GIT_REPO} == 'aws-ec2-pulumi' ]
    then
        NAME="$(jq '.name' payload.json | sed "s/\"//g")"
        #echo ${NAME}
        pulumi config set --path "data.machine_name" ${NAME}

        INSTANCETYPE="$(jq '.instance_type' payload.json | sed "s/\"//g")"
        #echo ${INSTANCETYPE}
        pulumi config set --path "data.instance_type" ${INSTANCETYPE}

        SG="$(jq '.security_group' payload.json | sed "s/\"//g")"
        #echo ${SG}
        pulumi config set --path "data.vpc_security_group_ids" ${SG}

        SUBNET="$(jq '.subnet_id' payload.json | sed "s/\"//g")"
        #echo ${SUBNET}
        pulumi config set --path "data.subnet_id" ${SUBNET}

        AMI="$(jq '.ami' payload.json | sed "s/\"//g")"
        #echo ${AMI}
        pulumi config set --path "data.ami" ${AMI}

        #TAGS="$(jq '.resource_tags' payload.json | sed "s/\"//g")"
        #echo ${TAGS}
    fi

    if [ ${GIT_REPO} == 'aws-s3-pulumi' ]
    then
        BUCKET="$(jq '.bucket_name' payload.json | sed "s/\"//g")"
        echo ${BUCKET}
        pulumi config set --path "data.bucket_name" ${BUCKET}

        ACL="$(jq '.acl' payload.json | sed "s/\"//g")"
        echo ${ACL}
        pulumi config set --path "data.acl" ${ACL}

        REGION="$(jq '.aws_region' payload.json | sed "s/\"//g")"
        echo ${REGION}
        pulumi config set --path "aws_region" ${REGION}
    fi

    file="Pulumi.${STACK}.yaml"
    cat ${file}

    echo "Running Step 6"
    echo "Pulumi ${COMMAND}"
    pulumi ${COMMAND} -y

    if [ ${COMMAND} == 'destroy' ]
    then
        pulumi stack rm ${stack} -y
    fi
    
fi
