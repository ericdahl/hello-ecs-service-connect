resource "aws_autoscaling_group" "default" {
  name = local.name

  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  vpc_zone_identifier = [aws_subnet.public.id]

  tag {
    key                 = "Name"
    value               = local.name
    propagate_at_launch = true
  }

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.default.id
        version            = aws_launch_template.default.latest_version
      }
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 0
    }
  }

  protect_from_scale_in = true
}

resource "aws_key_pair" "default" {
  public_key = var.public_key
}

resource "aws_launch_template" "default" {
  name = local.name

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_ec2.name
  }

  image_id      = data.aws_ssm_parameter.ecs_amazon_linux_2.value
  instance_type = "t3.medium"
  key_name      = aws_key_pair.default.key_name

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data =base64encode(<<EOF
#!/bin/bash
echo "ECS_CLUSTER=${local.name}" >> /etc/ecs/ecs.config
EOF
)

}

data "aws_ssm_parameter" "ecs_amazon_linux_2" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_security_group" "ec2" {
  vpc_id = aws_vpc.default.id
  name   = "${local.name}-ec2"
}


resource "aws_iam_role" "ec2_role" {
  name        = "${local.name}-instance-role"
#  description = "Role applied to ECS container instances - EC2 hosts - allowing them to register themselves, pull images from ECR, etc."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "default" {
  name       = "${aws_ecs_cluster.default.name}-ec2"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_ec2" {
  name = "${aws_iam_role.ec2_role.name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}