# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc"
  }
}

# subnets 
# us-east-1a
resource "aws_subnet" "public_web_subnetA" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-web-1a"
  }
}
resource "aws_subnet" "private_app_subnetA" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.128.0/20"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-app-1a"
  }
}
resource "aws_subnet" "private_db_subnetA" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.160.0/20"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-db-1a"
  }
}

# us-east-1b
resource "aws_subnet" "public_web_subnetB" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-web-1b"
  }
}
resource "aws_subnet" "private_app_subnetB" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.144.0/20"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-app-1b"
  }
}
resource "aws_subnet" "private_db_subnetB" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.176.0/20"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-db-1b"
  }
}

# main internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# elastic IP for NAT gateway
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "nat-gateway-eip"
  }
}

# NAT gateway
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_web_subnetA.id

  tags = {
    Name = "main-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}


# ----------- route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table" "db_isolated" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "db-isolated-route-table"
  }
}

# route table associations to subnets
resource "aws_route_table_association" "public_web_A" {
  subnet_id      = aws_subnet.public_web_subnetA.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_web_B" {
  subnet_id      = aws_subnet.public_web_subnetB.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_app_A" {
  subnet_id      = aws_subnet.private_app_subnetA.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_app_B" {
  subnet_id      = aws_subnet.private_app_subnetB.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_db_A" {
  subnet_id      = aws_subnet.private_db_subnetA.id
  route_table_id = aws_route_table.db_isolated.id
}
resource "aws_route_table_association" "private_db_B" {
  subnet_id      = aws_subnet.private_db_subnetB.id
  route_table_id = aws_route_table.db_isolated.id
}
