data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}


provider "aws" {
  region  = "us-east-1"
  profile = "default"
}


# SQS queue
resource "aws_sqs_queue" "terraform_queue" {
  name = "terraform-provisioning-queue"
}


# Lambda function role
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ecs-tasks.amazonaws.com", "lambda.amazonaws.com"]
        }
      },
    ]
  })

  inline_policy {
    name = "lambda-policies"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "iam:PassRole",
            "ecs:RunTask",
            "ecs:ListTasks",
            "ecs:StartTask",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "ssm:DescribeParameters",
            "ssm:GetParameter",
            "ssm:GetParameters",
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
            "Sid": "ListAndDescribe",
            "Effect": "Allow",
            "Action": [
                "dynamodb:List*",
                "dynamodb:DescribeReservedCapacity*",
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SpecificTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/markiv-resources"
        }
      ]
    })
  }

}

# Lambda function
resource "aws_lambda_function" "lambda" {
  filename      = "lambda.zip"
  function_name = "trigger-ecs-task"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"

  source_code_hash = filebase64sha256("lambda.zip")

  runtime = "python3.8"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# Log group for lambda function
resource "aws_cloudwatch_log_group" "trigger-ecs-task" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 365
}

# Event source from SQS
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.terraform_queue.arn
  enabled          = true
  function_name    = aws_lambda_function.lambda.arn
  batch_size       = 1
}



# VPC and Networking

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "r" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
  depends_on             = [aws_route_table.rt]
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# IAM

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "tf-provisioning-ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "tf-provisioning-ecsTaskRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}


# ECR repository
resource "aws_ecr_repository" "tf_task" {
  name = "tf-task"
}

# ECR repository #added on 14aug
resource "aws_ecr_repository" "pulumi_task" {
  name = "pulumi-task"
} #added on 14aug

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "tf-provisioning"
}

# ECS task definition
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "tf-deployment-task-def"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode([
    {
      name      = "tf-deployment-task"
      image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/tf-task:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/tf-deployment-task-def"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Pulumi task definition #added on 14aug
resource "aws_ecs_task_definition" "pulumi_task_definition" {
  family                   = "pulumi-deployment-task-def"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode([
    {
      name      = "pulumi-deployment-task"
      image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/pulumi-task:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/tf-deployment-task-def"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
} #added on 14aug

resource "aws_cloudwatch_log_group" "lg" {
  name = "/ecs/tf-deployment-task-def"
}

resource "aws_dynamodb_table" "markiv-requests" {
  name         = "markiv-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_uuid"
  range_key    = "request_id"

  attribute {
    name = "request_uuid"
    type = "S"
  }
  attribute {
    name = "request_id"
    type = "S"
  }
 }

resource "aws_dynamodb_table" "markiv-resources" {
  name         = "markiv-resources"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "resource_uuid"
  range_key    = "resource_id"

  attribute {
    name = "resource_uuid"
    type = "S"
  }
  attribute {
    name = "resource_id"
    type = "S"
  }
}
