## Architecture

![arch](static/images/arch.jpg?raw=true "Architecture")

- [Installation Steps](#installation-steps)
  - [Terraform](#terraform)
    - [TF Pre-requisits](#tf-pre-requisits)
    - [TF Deployment steps](#tf-deployment-steps)
  - [Docker](#docker)
    - [Docker Pre-requisits](#docker-pre-requisits)
    - [Docker Deployment steps](#docker-deployment-steps)
- [Usage](#usage)

## Installation Steps

### Terraform
#### TF Pre-requisits
- Configure `~/.aws/credentials`

#### TF Deployment steps
* Add your lambda function code in `lambda.py`
* run `zip lambda lambda.py`
* run `terraform init --backend-config="bucket=<bucketname>"` (Add this bucket name from terraform.tfvars.json file and SSM)
* run `terraform plan`
* run `terraform apply`

#### TF Deployment AWS SSM step
- Add below per project configurations in SSM parameter store (/terraform/provisioning/environment-vars)
```
{
   "projects": {
      "my-app-sdc-dev" : {
         "application_name": "my-app-sdc",
         "application_env": "dev",
         "git_org": "amoltatkare",
         "AWS_ACCESS_KEY_ID":"<>",
         "AWS_SECRET_ACCESS_KEY":"<>",
	       "s3_backend_bucket":"markiv-terraform-states",
         "PULUMI_CONFIG_PASSPHRASE":"<>",
         "security_groups":[
            "sg-<>"
         ],
         "subnets":[
            "subnet-<>"
         ],
         "ami":{
            "redhat8-linux": "ami-06640050dc3f556bb",
            "windows19": "ami-05912b6333beaa478",
            "windows22": "ami-027f2f92dac883acf",
            "amazon-linux2": "ami-090fa75af13c156b4"
         }
      }
   }
}
```



### Docker
#### Docker Pre-requisits
Install Docker and make sure Docker daemon is running.

#### Docker Deployment steps
You'll find these steps on your ECR repository (`tf-task`)
* aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-account-number>.dkr.ecr.us-east-1.amazonaws.com
* docker build --platform=linux/amd64 -t tf-task .
* docker tag tf-task:latest <your-account-number>.dkr.ecr.us-east-1.amazonaws.com/tf-task:latest
* docker push <your-account-number>.dkr.ecr.us-east-1.amazonaws.com/tf-task:latest

## Usage
* Terraform apply for project-1:
Add below message in SQS queue to trigger terraform apply for project-1
```
{
   "projects":[
      {
         "application_name": "my-app-sdc",
         "application_env": "dev",
         "resources": [
            {
               "id": "s3-0001",
               "provider": "aws",
               "iacprovider": "terraform",
               "command" : "apply/destroy",
               "resource_type": "s3",
               "config": {
                  "aws_region":"us-east-1",
                  "bucket_name":"my-app-sdc-dev-s3-0001",
                  "acl":"private"
               }
            },
            {
               "id": "ec2-0001",
               "provider": "aws",
               "iacprovider": "terraform",
               "command" : "apply/destroy",
               "resource_type": "ec2",
               "config": {
                  "name": "my-app-sdc-dev-ec2-0001",
                  "os": "redhat8-linux",
                  "instance_type": "t1.micro"
               }
            },
            {
               "id": "s3-0001",
               "provider": "aws",
               "iacprovider": "pulumi",
               "command" : "up/destroy",
               "resource_type": "s3",
               "config": {
                  "aws_region":"us-east-1",
                  "bucket_name":"my-app-sdc-dev-s3-0001",
                  "acl":"private"
               }
            },
            {
               "id": "ec2-0002",
               "provider": "aws",
               "iacprovider": "pulumi",
               "command" : "up/destroy", 
               "resource_type": "ec2",
               "config": {
                  "name": "my-app-sdc-dev-ec2-0002",
                  "os": "redhat8-linux",
                  "instance_type": "t1.micro"
               }
            }
         ]
      }
   ]
}
```
## Template terraform repos:
- s3: https://github.com/amoltatkare/aws-s3-terraform
- ec2: https://github.com/amoltatkare/aws-ec2-terraform
- s3: https://github.com/amoltatkare/aws-s3-pumumi
- ec2: https://github.com/amoltatkare/aws-ec2-pumumi

