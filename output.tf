output "web_alb_dns" {
  value = aws_lb.web_alb.dns_name
}

output "app_alb_dns" {
  value = aws_lb.app_alb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}