resource "aws_ecs_task_definition" "httpbin" {
  family = "httpbin"

  #  requires_compatibilities = ["FARGATE"]

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
      ]
    }
  ])

  cpu    = "256"
  memory = "512"

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
    subnets = [
      aws_subnet.public.id
    ]

    security_groups = [
      aws_security_group.httpbin.id
    ]
  }

  #  service_connect_configuration {
  #    enabled = true

  #    log_configuration
  #  }

  task_definition = aws_ecs_task_definition.httpbin.arn
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