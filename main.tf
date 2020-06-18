provider "aws" {
  region = var.aws_region
}

#===========IAM================
resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access"
  role = "aws_iam_role.s3_access_role.name"
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = "aws_iam_role.s3_access_role.id"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
  },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
EOF
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
resource "aws_security_group" "wp_public_sc" {
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
