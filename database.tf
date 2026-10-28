resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_subnetA.id, aws_subnet.private_db_subnetB.id]

  tags = {
    Name = "main-db-subnet-group"
  }
}

# rds
resource "aws_db_instance" "main" {
  identifier = "three-tier-db"

  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "appdb"
  username = "dbadmin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = 1

  skip_final_snapshot = true
  deletion_protection = false
}

