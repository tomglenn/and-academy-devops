variable "env" {
    default = "dev"
}

data "aws_region" "current" {}

resource "aws_s3_bucket" "test" {
    bucket = "tomglenn-test123-${var.env}"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_ecr_repository" "main" {
  name = "toms-academy"
}

resource "aws_iam_user" "cf-deployer" {
    name = "cf-deployer"
}

resource "aws_iam_policy" "cf-deployer" {
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
        {
          Effect: "Allow",
          Action: [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload",
              "ecr:PutImage",
              "ecs:DescribeServices",
              "ecs:DescribeTaskDefinition",
              "ecs:DescribeTasks",
              "ecs:ListClusters",
              "ecs:ListServices",
              "ecs:ListTasks",
              "ecs:RegisterTaskDefinition",
              "ecs:UpdateService"
          ],
          Resource: [ aws_ecr_repository.main.arn, aws_ecs_cluster.cluster.arn, aws_ecs_service.main.id ]
        },
        {
          Effect: "Allow",
          Action: [
              "ecr:GetAuthorizationToken",
          ],
          Resource: "*"
        },
        {
          Effect: "Allow",
          Action: "iam:PassRole",
          Resource: "*"
        }
    ]
    })
}

resource "aws_iam_user_policy_attachment" "main" {
  policy_arn = aws_iam_policy.cf-deployer.arn
  user = aws_iam_user.cf-deployer.name
}

resource "aws_iam_access_key" "cf-deployer" {
  user = aws_iam_user.cf-deployer.name
}

output "AWS_ACCESS_KEY_ID" {
  value = aws_iam_access_key.cf-deployer.id
}

output "AWS_SECRET_ACCESS_KEY" {
  value = aws_iam_access_key.cf-deployer.secret
}

resource "aws_ecs_cluster" "cluster" {
  name = "and-academy-${var.env}"
}

resource "aws_alb" "main" {
  name            = "academy-${var.env}"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.main.id]
}

output "url" {
  value = "http://${aws_alb.main.dns_name}/"
}

resource "aws_alb_target_group" "main" {
  name        = "academy-${var.env}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
}

resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.main.arn
    type             = "forward"
  }
}

resource "aws_ecs_service" "main" {
  name            = "academy-${var.env}"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 5
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.main.id]
    subnets         = module.vpc.private_subnets
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = "first"
    container_port   = 80
  }

  depends_on = [
    aws_alb_listener.main
  ]
}

resource "aws_security_group" "main" {
  vpc_id = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "service" {
  family                   = "service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.main.arn

  container_definitions = jsonencode([{
    name: "first",
    image: "${aws_ecr_repository.main.repository_url}:master",
    cpu: 256,
    memory: 512,
    essential: true,
    readonly_root_filesystem = false,
    portMappings : [
      {
        containerPort : 80,
        hostPort : 80
      }
    ],
    logConfiguration: {
      logDriver: "awslogs",
      options: {
        "awslogs-group": aws_cloudwatch_log_group.logs.name,
        "awslogs-stream-prefix": "academy-logs",
        "awslogs-region": data.aws_region.current.name
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "academy-log-group-${var.env}"
}

resource "aws_iam_role" "main" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "main" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "main" {
  policy_arn = aws_iam_policy.main.arn
  role       = aws_iam_role.main.name
}