provider "aws" {
  region = var.region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC & Subnets
resource "aws_vpc" "mon_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "Mon-VPC-Certification" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.mon_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "Subnet-Public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.mon_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "Subnet-Private" }
}

# Internet Gateway & public route
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mon_vpc.id
  tags   = { Name = "Internet-gateway" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mon_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "Route-Table-Public" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Groups
resource "aws_security_group" "app_sg" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.mon_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Security-Group-App" }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.mon_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "RDS Security Group" }
}

# random password used only to bootstrap DB admin; state will contain it (sensibilité gérée)
resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!@#$%&*()-_+=<>?"
}

# RDS Subnet group
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private.id]

  tags = { Name = "RDS Subnet Group" }
}

# RDS Instance with IAM DB Authentication enabled
resource "aws_db_instance" "mydb" {
  identifier                           = "mydb-instance"
  allocated_storage                    = 20
  storage_type                         = "gp3"
  engine                               = "mysql"
  engine_version                       = "8.0"
  instance_class                       = "db.t3.micro"
  name                                 = "mydb"
  username                             = var.db_username
  password                             = random_password.db.result
  db_subnet_group_name                 = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids               = [aws_security_group.rds_sg.id]
  publicly_accessible                  = false
  multi_az                             = false
  backup_retention_period              = 7
  skip_final_snapshot                  = true
  iam_database_authentication_enabled  = true

  tags = { Name = "My RDS Instance" }
}

# IAM role / instance profile for EC2 so it can:
# - use rds-db:connect (to connect to the DB using IAM auth)
# - use SSM (optional, helpful to access instance)
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role-rds-iam-auth"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "ec2-role-rds-iam-auth" }
}

# Policy allowing rds-db:connect to the specific DB resource and user
resource "aws_iam_policy" "rds_connect_policy" {
  name = "RDSConnectPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["rds-db:connect"],
        Resource = [
          "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.mydb.resource_id}/${var.db_username}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_rds_connect" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.rds_connect_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile-rds-iam-auth"
  role = aws_iam_role.ec2_role.name
}

# EC2 instance (public) with the instance profile
resource "aws_instance" "mon_serveur_web" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx mysql-client awscli
    echo "<h1>Mon premier serveur avec Terraform!</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx

    # Exemple pour générer un token IAM (à adapter selon les besoins):
    # TOKEN=$(aws rds generate-db-auth-token --hostname ${aws_db_instance.mydb.address} --port 3306 --region ${var.region} --username ${var.db_username})
    # mysql --host=${aws_db_instance.mydb.address} --port=3306 --enable-cleartext-plugin -u ${var.db_username} -p${TOKEN} mydb
  EOF

  tags = { Name = "mon-serveur-web" }
}
