resource "aws_ecs_cluster" "default" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.default.arn
  }

}

resource "aws_service_discovery_http_namespace" "default" {
  name = local.name
}