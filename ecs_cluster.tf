resource "aws_ecs_cluster" "default" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_private_dns_namespace.default.arn
  }

}

resource "aws_service_discovery_http_namespace" "default" {
  name = local.name
}

resource "aws_service_discovery_private_dns_namespace" "default" {
  name = local.name
  vpc  = aws_vpc.default.id
}