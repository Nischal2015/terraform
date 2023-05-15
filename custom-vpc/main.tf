provider "aws" {
  region = "us-east-1"
}

# 1. Create a custom VPC
resource "aws_vpc" "first-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "first-vpc"
  }
}

# 2. Create and attach the internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.first-vpc.id

  tags = {
    Name = "first-vpc-igw"
  }
}

# 3. Create a NAT gateway
resource "aws_eip" "elastic-ip" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.elastic-ip.id
  subnet_id     = aws_subnet.public-subnet.id

  tags = {
    Name = "NAT Gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# 4. Create public and private subnets
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.first-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = var.az-1
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.first-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az-1

  tags = {
    Name = "private-subnet"
  }
}

# 5. Create custom route tables
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.first-vpc.id

  route {
    cidr_block = var.all-ipv4
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.first-vpc.id

  route {
    cidr_block = var.all-ipv4
    gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# 6. Subnet association with route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-rt.id
}

# 7. Create security groups
resource "aws_security_group" "allow" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description = "HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.all-ipv4]
  }

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.all-ipv4]
  }

  ingress {
    description = "SSH into instance"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.all-ipv4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all-ipv4]
  }

  tags = {
    Name = "allow-tls"
  }
}

resource "aws_security_group" "only-ssh-bastion" {
  name        = "ssh-bastion"
  description = "Allow SSH for bastion"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description = "SSH into instance"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.all-ipv4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all-ipv4]
  }

  tags = {
    Name = "ssh-bastion"
  }
}

resource "aws_security_group" "private-allow" {
  name        = "ssh-private"
  description = "Allow SSH from bastion"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description     = "SSH into private instance"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.only-ssh-bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all-ipv4]
  }

  tags = {
    Name = "private-allow-tls"
  }
}

# 8. Create EC2 instances
resource "aws_instance" "public-instance" {
  ami                    = var.ec2-ami
  instance_type          = var.default-instance
  availability_zone      = var.az-1
  subnet_id              = aws_subnet.public-subnet.id
  key_name               = "main-key"
  vpc_security_group_ids = [aws_security_group.allow.id]
  user_data              = <<-EOF
              #!/bin/bash
              yum update -y
              yum install httpd -y
              echo "Nischal Shakya" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name = "public-instance"
  }
}

resource "aws_instance" "bastion-host" {
  ami                    = var.ec2-ami
  instance_type          = var.default-instance
  availability_zone      = var.az-1
  subnet_id              = aws_subnet.public-subnet.id
  key_name               = "main-key"
  vpc_security_group_ids = [aws_security_group.only-ssh-bastion.id]

  tags = {
    Name = "bastion-host"
  }
}

resource "aws_instance" "private-instance" {
  ami                    = var.ec2-ami
  instance_type          = var.default-instance
  availability_zone      = var.az-1
  subnet_id              = aws_subnet.private-subnet.id
  key_name               = "private-key"
  vpc_security_group_ids = [aws_security_group.private-allow.id]

  tags = {
    Name = "private-instance"
  }
}
