resource "aws_vpc" "mon_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Mon-VPC-Certification"
  }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.mon_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-3a"

# Second subnet privé pour RDS (dans une autre zone de disponibilité)
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.mon_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-3c"
  tags = {
    Name = "Subnet-Private-2"
  }
}

# Groupe de subnets RDS (nécessaire pour créer RDS dans un VPC)
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Security Group pour RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.mon_vpc.id

  # Autorise les connexions depuis l'application (exemple sur le port 3306 pour MySQL)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.security_group.id] # Security group app/web
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

# Instance RDS
resource "aws_db_instance" "mydb" {
  identifier              = "mydb-instance"
  allocated_storage       = 20
  storage_type            = "gp3"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  name                    = "mydb"
  username                = "admin"
  password                = "example-password" # Utiliser une variable ou AWS Secrets Manager pour plus de sécurité
  db_subnet_group_name    = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 7
  skip_final_snapshot     = false

  tags = {
    Name = "My RDS Instance"
  }
}

# Output de l'endpoint RDS
output "rds_endpoint" {
  value       = aws_db_instance.mydb.endpoint
  description = "Endpoint privé de l'instance RDS"
}

    tags = {
        Name = "Subnet-Public"
    }
    
    }

resource "aws_subnet" "private" {
    vpc_id = aws_vpc.mon_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-3b"
    tags = {
        Name = "Subnet-Private" }

}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.mon_vpc.id
    tags = {
      Name = "Internet-gateway"
    }
  
}
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.mon_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id 
    }
    tags = {
        Name = "Route- Table-Public"
    }
}

    resource "aws_route_table_association" "public_assoc" {
        subnet_id = aws_subnet.public.id
        route_table_id = aws_route_table.public_rt.id
    }
   

resource "aws_security_group" "security_group" {
    name = "allow_ssh_http"
    description = "Allow SSH and HTTP inbound traffic"
    vpc_id = aws_vpc.mon_vpc.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
}

ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
        egress {
            from_port = 0
            to_port = 0
            protocol = "-1" 
            cidr_blocks = ["0.0.0.0/0"]
        }
    
        tags = {
            Name = "Security-Group"
        }
    }

    resource "aws_instance" "mon_serveur_web" {
        ami = "ami-00ac45f3035ff009e"
        instance_type = "t2.micro"
        subnet_id = aws_subnet.public.id

        vpc_security_group_ids = [aws_security_group.security_group.id]
        associate_public_ip_address = true
 user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y nginx
              echo "<h1>Mon premier serveur avec Terraform!</h1>" > /var/www/html/index.html
              systemctl start nginx
              EOF

        tags = {
            Name = "mon-serveur-web"
        }

    }

    # Afficher l'adresse IP publique du serveur
output "ip_publique_serveur" {
  value       = aws_instance.mon_serveur_web.public_ip
  description = "Adresse IP publique du serveur web"
}
