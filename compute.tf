# EC2 AMI
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ASG for web tier
resource "aws_launch_template" "web_lt" {
  name_prefix            = "web-"
  image_id               = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  metadata_options {
    http_tokens = "required"
  }
  user_data = base64encode(<<-EOF
        #!/bin/bash
        dnf install -y nginx
        echo "Web tier from $(hostname -f)" > /usr/share/nginx/html/index.html
        systemctl enable --now nginx
        EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-asg-instance"
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                      = "web-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public_web_subnetA.id, aws_subnet.public_web_subnetB.id]
  target_group_arns         = [aws_lb_target_group.web_lb_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  depends_on = [
    aws_route_table_association.public_web_A,
    aws_route_table_association.public_web_B
  ]
}

# ASG for app tier
resource "aws_launch_template" "app_lt" {
  name_prefix            = "app-"
  image_id               = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  metadata_options {
    http_tokens = "required"
  }
  user_data = base64encode(<<-EOF
        #!/bin/bash
        dnf install -y nginx
        echo "App tier from $(hostname -f)" > /usr/share/nginx/html/index.html
        systemctl enable --now nginx
        EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-asg-instance"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                      = "app-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.private_app_subnetA.id, aws_subnet.private_app_subnetB.id]
  target_group_arns         = [aws_lb_target_group.app_lb_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  depends_on = [
    aws_route_table_association.private_app_A,
    aws_route_table_association.private_app_B
  ]
}
