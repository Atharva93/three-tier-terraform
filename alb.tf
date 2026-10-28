# alb for web
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_alb_sg.id]
  subnets            = [aws_subnet.public_web_subnetA.id, aws_subnet.public_web_subnetB.id]
}

resource "aws_lb_target_group" "web_lb_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_lb_tg.arn
  }
}

# alb for app
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_alb_sg.id]
  subnets            = [aws_subnet.private_app_subnetA.id, aws_subnet.private_app_subnetB.id]
}

resource "aws_lb_target_group" "app_lb_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_lb_tg.arn
  }
}
