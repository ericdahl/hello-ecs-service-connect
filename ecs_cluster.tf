resource "aws_ecs_cluster" "default" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.default.arn
  }

  depends_on = [aws_cloudwatch_log_group.container_insights_performance]
}

resource "aws_ecs_cluster_capacity_providers" "default" {
  cluster_name = aws_ecs_cluster.default.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_service_discovery_http_namespace" "default" {
  name = local.name
}

resource "aws_cloudwatch_log_group" "container_insights_performance" {
  name              = "/aws/ecs/containerinsights/${local.name}/performance"
  retention_in_days = 1
}