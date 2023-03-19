resource "aws_ecs_task_definition" "httpbin" {
  family = "httpbin"

  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.httpbin_task_execution.arn


  network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name  = "httpbin"
      image = "ericdahl/httpbin:e249975"
      portMappings = [
        {
          name          = "http"
          protocol      = "tcp"
          containerPort = 8080
          hostPort      = 8080
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.httpbin.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "httpbin"
        }
      }
    }
  ])

  cpu    = "256"
  memory = "512"

}

resource "aws_cloudwatch_log_group" "httpbin" {
  name              = "/${local.name}/httpbin"
  retention_in_days = 1
}

resource "aws_ecs_service" "httpbin" {
  name    = "httpbin"
  cluster = aws_ecs_cluster.default.name

  desired_count = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
  }

  network_configuration {

    # for demo purposes only; no private subnets here
    # to save costs on NAT GW, speed up deploys, etc
    assign_public_ip = true

    subnets = [
      aws_subnet.public.id
    ]

    security_groups = [
      aws_security_group.httpbin.id
    ]
  }

    service_connect_configuration {
      enabled = true

      service {
        port_name = "http"

        discovery_name = "httpbin"

        client_alias {
          port = 8080
          dns_name = "httpbin"
        }
      }

      log_configuration {
        log_driver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.httpbin_ecs_service_connect.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "httpbin"
        }
      }
    }

  task_definition = aws_ecs_task_definition.httpbin.arn
}

resource "aws_cloudwatch_log_group" "httpbin_ecs_service_connect" {
  name = "/ecs/httpbin"
}

resource "aws_security_group" "httpbin" {
  vpc_id = aws_vpc.default.id
}

resource "aws_security_group_rule" "httpbin_egress_all" {
  security_group_id = aws_security_group.httpbin.id

  type = "egress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = ["0.0.0.0/0"]
  description = "allows ECS task to make egress calls"
}

resource "aws_security_group_rule" "httpbin_ingress_admin" {
  security_group_id = aws_security_group.httpbin.id

  type = "ingress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = [var.admin_cidr]
}

resource "aws_iam_role" "httpbin_task_execution" {
  name = "httpbin-task-execution"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
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

resource "aws_iam_policy" "httpbin_task_execution" {
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
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "httpbin_task_execution" {
  role       = aws_iam_role.httpbin_task_execution.name
  policy_arn = aws_iam_policy.httpbin_task_execution.arn
}