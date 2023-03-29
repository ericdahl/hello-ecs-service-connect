resource "aws_ecs_task_definition" "redis" {
  family = "redis"

  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.redis_task_execution.arn


  network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name  = "redis"
      image = "redis:latest"
      portMappings = [
        {
          name          = "redis"
          protocol      = "tcp"
          containerPort = 6379
          hostPort      = 6379
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.redis.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "redis"
        }
      }
    }
  ])

  cpu    = "256"
  memory = "512"

}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/${local.name}/redis"
  retention_in_days = 1
}

resource "aws_ecs_service" "redis" {
  name    = "redis"
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
      aws_security_group.redis.id
    ]
  }

  service_connect_configuration {
    enabled = true

    service {
      port_name = "redis"

      discovery_name = "redis"

      client_alias {
        port     = 6379
        dns_name = "redis"
      }
    }

    log_configuration {
      log_driver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.redis_ecs_service_connect.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "redis"
      }
    }
  }

  task_definition = aws_ecs_task_definition.redis.arn
}

resource "aws_cloudwatch_log_group" "redis_ecs_service_connect" {
  name = "/ecs/redis"
}

resource "aws_security_group" "redis" {
  vpc_id = aws_vpc.default.id
}

resource "aws_security_group_rule" "redis_egress_all" {
  security_group_id = aws_security_group.redis.id

  type = "egress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = ["0.0.0.0/0"]
  description = "allows ECS task to make egress calls"
}

resource "aws_security_group_rule" "redis_ingress_admin" {
  security_group_id = aws_security_group.redis.id

  type = "ingress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = [var.admin_cidr]
}

resource "aws_security_group_rule" "redis_ingress_counter" {
  security_group_id = aws_security_group.redis.id

  type = "ingress"

  from_port = 6379
  to_port   = 6379
  protocol  = "tcp"

  source_security_group_id = aws_security_group.counter.id
}

resource "aws_iam_role" "redis_task_execution" {
  name               = "redis-task-execution"
  assume_role_policy = data.aws_iam_policy_document.role_assume_ecs_tasks.json
}

data "aws_iam_policy_document" "redis_task_execution" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "redis_task_execution" {
  name   = "redis-task-execution"
  policy = data.aws_iam_policy_document.redis_task_execution.json
}

resource "aws_iam_role_policy_attachment" "redis_task_execution" {
  role       = aws_iam_role.redis_task_execution.name
  policy_arn = aws_iam_policy.redis_task_execution.arn
}