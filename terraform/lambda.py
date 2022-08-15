import json
import boto3
from pprint import pprint

ecs = boto3.client('ecs')
ssm = boto3.client('ssm')

def get_resource_config(type, config, app_config, app_env):
    """Get resource config based on resource type."""
    resource_config = config["config"]
    if type == "s3":
        return resource_config
    elif type == "ec2":
        app_os = resource_config["os"]
        return {
            "name":resource_config["name"],
            "ami":app_config["ami"][app_os],
            "instance_type":resource_config["instance_type"],
            "security_group":app_config["security_groups"][0],
            "subnet_id":app_config["subnets"][0],
            "resource_tags":{
                "Name": resource_config["name"],
                "environment":app_env
            }
        }


def handler(event, context):
    pprint("Received event: " + json.dumps(event, indent=2))

    config = ssm.get_parameter(Name='/terraform/provisioning/environment-vars',WithDecryption=True)["Parameter"]["Value"]
    config = json.loads(config)

    payload = json.loads(event["Records"][0]["body"])
    projects = payload["projects"]

    for project in projects:
        app_name = project["application_name"]
        app_env = project["application_env"]
        resources = project["resources"]
        
        project_name = f"{app_name}-{app_env}"
        app_config = config["projects"][project_name]

        for resource in resources:
            provider = resource['provider']
            resource_type = resource['resource_type']
            iacprovider = resource["iacprovider"] #terraform or pulumi or ...
            command = resource["command"] # in case of terraform use apply/destroy or for pulumi use up/destroy
            id = resource["id"]

            git_repo = f"{provider}-{resource_type}-{iacprovider}"
            git_org = app_config["git_org"]

            backend_s3_key = f"{app_name}-{app_env}-{resource_type}-{id}/terraform.tfstate"
            resource_config = get_resource_config(resource_type, resource, app_config, app_env)

            if iacprovider == "pulumi":
                taskdef = "pulumi-deployment-task-def"
                taskname = "pulumi-deployment-task"

            if iacprovider == "terraform":
                taskdef = "tf-deployment-task-def"
                taskname = "tf-deployment-task"

            ecs.run_task(
                cluster='tf-provisioning',
                count=1,
                enableECSManagedTags=True,
                launchType='FARGATE',
                networkConfiguration={
                    'awsvpcConfiguration': {
                        'subnets': app_config["subnets"],
                        'securityGroups': app_config["security_groups"],
                        'assignPublicIp': 'ENABLED'
                    }
                },
                overrides={
                    'containerOverrides': [
                        {
                            'name': taskname,
                            'environment': [
                                {
                                    'name': 'AWS_ACCESS_KEY_ID',
                                    'value': app_config["AWS_ACCESS_KEY_ID"]
                                },
                                {
                                    'name': 'AWS_SECRET_ACCESS_KEY',
                                    'value': app_config["AWS_SECRET_ACCESS_KEY"]
                                },
                                {
                                    'name': 'PULUMI_CONFIG_PASSPHRASE',
                                    'value': app_config["PULUMI_CONFIG_PASSPHRASE"] 
                                },
                                {
                                    'name': 'COMMAND',
                                    'value': command
                                },
                                {
                                    'name': 'IACPROVIDER',
                                    'value': iacprovider
                                },
                                {
                                    'name': 'AWS_REGION',
                                    'value': "us-east-1"
                                },
                                {
                                    'name': 'PROJECT',
                                    'value': project_name
                                },
                                {
                                    'name': 'BACKEND_BUCKET',
                                    'value': app_config["s3_backend_bucket"]
                                },
                                {
                                    'name': 'BACKEND_S3_KEY',
                                    'value': backend_s3_key
                                },
                                {
                                    'name': 'RESOURCE_CONFIG',
                                    'value': json.dumps(resource_config)
                                },
                                {
                                    'name': 'GIT_ORG',
                                    'value': git_org
                                },
                                {
                                    'name': 'GIT_REPO',
                                    'value': git_repo
                                },
                            ]
                        },
                    ]
                },
                taskDefinition=taskdef
            )
