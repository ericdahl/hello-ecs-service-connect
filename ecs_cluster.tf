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
#
#resource "aws_ecs_cluster_capacity_providers" "default" {
#  cluster_name = aws_ecs_cluster.default.name
#
#  capacity_providers = ["FARGATE"]
#
#  default_capacity_provider_strategy {
#    base              = 1
#    weight            = 100
#    capacity_provider = "FARGATE"
#  }
#}

resource "aws_service_discovery_http_namespace" "default" {
  name = local.name
}

resource "aws_service_discovery_private_dns_namespace" "default" {
  name = local.name
  vpc  = aws_vpc.default.id
}