# Security groups
resource "aws_security_group" "web_alb_sg" {
  name_prefix = "web-alb-sg-"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "web-alb-sg"
  }
}

resource "aws_security_group" "web_ec2_sg" {
  name_prefix = "web-ec2-sg-"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "web-ec2-sg"
  }
}

# app load balancer
resource "aws_security_group" "app_alb_sg" {
  name_prefix = "app-alb-sg-"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "app-alb-sg"
  }
}

resource "aws_security_group" "app_ec2_sg" {
  name_prefix = "app-ec2-sg-"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "app_ec2_sg"
  }
}

resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "db-sg"
  }
}


# in out rules
# web_alb_sg
resource "aws_vpc_security_group_ingress_rule" "web_alb_in_web" {
  security_group_id = aws_security_group.web_alb_sg.id
  description       = "WEB to WEB ALB"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "web_alb_out_web_ec2" {
  security_group_id            = aws_security_group.web_alb_sg.id
  description                  = "WEB ALB to WEB EC2"
  referenced_security_group_id = aws_security_group.web_ec2_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}


# web ec2 sg
resource "aws_vpc_security_group_ingress_rule" "web_ec2_web_in" {
  security_group_id            = aws_security_group.web_ec2_sg.id
  description                  = "WEB ALB to EC2"
  referenced_security_group_id = aws_security_group.web_alb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "web_ec2_out_app_alb" {
  security_group_id            = aws_security_group.web_ec2_sg.id
  description                  = "WEB EC2 to APP ALB"
  referenced_security_group_id = aws_security_group.app_alb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "web_ec2_out_internet" {
  security_group_id = aws_security_group.web_ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "EC2 to internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

#app_alb_sg
resource "aws_vpc_security_group_ingress_rule" "app_alb_in_web_ec2" {
  security_group_id            = aws_security_group.app_alb_sg.id
  description                  = "WEB EC2 to APP ALB"
  referenced_security_group_id = aws_security_group.web_ec2_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_alb_out_app_ec2" {
  security_group_id            = aws_security_group.app_alb_sg.id
  description                  = "APP ALB to APP EC2"
  referenced_security_group_id = aws_security_group.app_ec2_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# app_ec2_sg
resource "aws_vpc_security_group_ingress_rule" "app_ec2_in_app_alb" {
  security_group_id            = aws_security_group.app_ec2_sg.id
  description                  = "APP ALB to APP EC2"
  referenced_security_group_id = aws_security_group.app_alb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_ec2_out_db" {
  security_group_id            = aws_security_group.app_ec2_sg.id
  description                  = "APP EC2 to DB"
  referenced_security_group_id = aws_security_group.db_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_ec2_out_web" {
  security_group_id = aws_security_group.app_ec2_sg.id
  description       = "Outbound HTTPS for SSM and package updates"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_sg_in_app_ec2" {
  security_group_id            = aws_security_group.db_sg.id
  description                  = "APP EC2 to DB"
  referenced_security_group_id = aws_security_group.app_ec2_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}