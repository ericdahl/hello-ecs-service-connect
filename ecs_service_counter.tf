resource "aws_ecs_task_definition" "counter" {
  family = "counter"

  requires_compatibilities = ["EC2"]

  execution_role_arn = aws_iam_role.counter_task_execution.arn

  task_role_arn = aws_iam_role.counter_task.arn

  network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name  = "counter"
      image = "ericdahl/hello-ecs:6770354"
      portMappings = [
        {
          name          = "http"
          protocol      = "tcp"
          appProtocol   = "http"
          containerPort = 8080
          hostPort      = 8080
        }
      ],
      environment : [
        {
          "name" : "SPRING_REDIS_HOST",
          "value" : "redis"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.counter.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "counter"
        }
      }
    }
  ])

  cpu    = 256
  memory = 512
}

resource "aws_cloudwatch_log_group" "counter" {
  name              = "/${local.name}/counter"
  retention_in_days = 1
}

resource "aws_ecs_service" "counter" {
  name    = "counter"
  cluster = aws_ecs_cluster.default.name

  desired_count = 2

  enable_execute_command = true

  launch_type = "EC2"

  network_configuration {

    # for demo purposes only; no private subnets here
    # to save costs on NAT GW, speed up deploys, etc
    # only works for Fargate
#    assign_public_ip = true

    subnets = [
      aws_subnet.public.id
    ]

    security_groups = [
      aws_security_group.counter.id
    ]
  }

  service_connect_configuration {
    enabled = true

    service {
      port_name = "http"

      discovery_name = "counter"

      client_alias {
        port     = 8080
        dns_name = "counter"
      }
    }

    log_configuration {
      log_driver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.counter_ecs_service_connect.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "counter"
      }
    }
  }

  task_definition = aws_ecs_task_definition.counter.arn

  depends_on = [aws_ecs_service.redis]
}

resource "aws_cloudwatch_log_group" "counter_ecs_service_connect" {
  name              = "/ecs/counter"
  retention_in_days = 1
}

resource "aws_security_group" "counter" {
  name   = "counter"
  vpc_id = aws_vpc.default.id
}

resource "aws_security_group_rule" "counter_egress_all" {
  security_group_id = aws_security_group.counter.id

  type = "egress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = ["0.0.0.0/0"]
  description = "allows ECS task to make egress calls"
}

resource "aws_security_group_rule" "counter_ingress_admin" {
  security_group_id = aws_security_group.counter.id

  type = "ingress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = [var.admin_cidr]
}

# for testing
resource "aws_security_group_rule" "counter_ingress_vpc" {
  security_group_id = aws_security_group.counter.id

  type = "ingress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = [aws_vpc.default.cidr_block]
}

resource "aws_iam_role" "counter_task_execution" {
  name               = "counter-task-execution"
  assume_role_policy = data.aws_iam_policy_document.role_assume_ecs_tasks.json
}

resource "aws_iam_role" "counter_task" {
  name               = "counter-task"
  assume_role_policy = data.aws_iam_policy_document.role_assume_ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "counter_task_ecs_exec" {
  role       = aws_iam_role.counter_task.name
  policy_arn = aws_iam_policy.ecs_task_exec.arn
}

resource "aws_iam_role_policy_attachment" "counter_task_execution" {
  role       = aws_iam_role.counter_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
#
#data "aws_network_interface" "counter" {
#  for_each = toset(data.aws_network_interfaces.counter.ids)
#  id = each.key
#}
#
#data "aws_network_interfaces" "counter" {
#  filter {
#    name   = "group-id"
#    values = [aws_security_group.counter.id]
#  }
#}

#output "counter_eni" {
#  value = [ for eni in data.aws_network_interface.counter : eni.association[0].public_ip ]
#}