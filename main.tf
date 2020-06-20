provider "aws" {
  region = var.aws_region
}

#-===========VPC============
resource "aws_vpc" "wp_vpc" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true

  tags = {
    Name = "wp_vpc"
  }
}

#internet gateway
resource "aws_internet_gateway" "wp_internet_gateway" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "wp_igw"
  }
}
#route table
resource "aws_route_table" "wp_public_route_table" {
  vpc_id = aws_vpc.wp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wp_internet_gateway.id
  }
  tags = {
    Name = "wp_public_rt"
  }
}
resource "aws_default_route_table" "wp_privat_route_table" {
  default_route_table_id = aws_vpc.wp_vpc.default_route_table_id

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.wp_nat_instance.id
  }

  tags = {
    Name = "wp_privat_rt"
  }
}
#subnet
resource "aws_subnet" "wp_public_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["public"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wp_public"
  }
}

resource "aws_subnet" "wp_privat_subnet" {
  vpc_id                  = aws_vpc.wp_vpc.id
  cidr_block              = var.cidrs["privat"]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name = "wp_privat"
  }
}
#subnet associations
resource "aws_route_table_association" "wp_public_association" {
  subnet_id      = aws_subnet.wp_public_subnet.id
  route_table_id = aws_route_table.wp_public_route_table.id
}

resource "aws_route_table_association" "wp_privat_association" {
  subnet_id      = aws_subnet.wp_privat_subnet.id
  route_table_id = aws_default_route_table.wp_privat_route_table.id
}

#security_groups
resource "aws_security_group" "wp_public_sg" {
  name        = "wp_public_sg"
  description = "Allow http https and ssh traffic"
  vpc_id      = aws_vpc.wp_vpc.id

  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["148.75.34.51/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "wp_privat_sg" {
  name        = "wp_privat_sg"
  description = "Privat subnet security_rule"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "wp_nat_sg" {
  name        = "wp_nat_sg"
  description = "Nat instance security_rule"
  vpc_id      = aws_vpc.wp_vpc.id

  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#===========Instances====================
#key pair
resource "aws_key_pair" "wp_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}
#HAPROXY
resource "aws_instance" "wp_haproxy" {
  instance_type          = var.haproxy_instance_type
  ami                    = var.haproxy_ami
  vpc_security_group_ids = [aws_security_group.wp_public_sg.id]
  subnet_id              = aws_subnet.wp_public_subnet.id
  key_name               = aws_key_pair.wp_auth.id


  tags = {
    Name = "haproxy_instance"
  }
}
#Nat instance
resource "aws_instance" "wp_nat_instance" {
  instance_type          = var.nat_instance_type
  ami                    = var.nat_ami
  vpc_security_group_ids = [aws_security_group.wp_nat_sg.id]
  subnet_id              = aws_subnet.wp_public_subnet.id
  source_dest_check      = false
  key_name               = aws_key_pair.wp_auth.id


  tags = {
    Name = "nat_instance"
  }
}
#wordpress
resource "aws_instance" "wp_instance" {
  instance_type          = var.wp_instance_type
  ami                    = var.wp_ami
  vpc_security_group_ids = [aws_security_group.wp_privat_sg.id]
  subnet_id              = aws_subnet.wp_privat_subnet.id
  key_name               = aws_key_pair.wp_auth.id

  root_block_device {
    volume_size = 15
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = {
    Name = "wp_instance"
  }
}
#==============EIP=======================
resource "aws_eip" "wp_haproxy_eip" {
  instance = aws_instance.wp_haproxy.id
  vpc      = true
}
resource "aws_eip" "nat_eip" {
  instance = aws_instance.wp_nat_instance.id
  vpc      = true
}
