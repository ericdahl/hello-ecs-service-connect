provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Name       = "hello-ecs-service-connect"
      Repository = "https://github.com/ericdahl/hello-ecs-service-connect"
    }
  }
}

data "aws_default_tags" "default" {}

locals {
  name = data.aws_default_tags.default.tags["Name"]
}

data "aws_iam_policy_document" "role_assume_ecs_tasks" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}