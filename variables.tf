variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "db_username" {
  description = "Database admin username (bootstrap user)"
  type        = string
  default     = "admin"
}

variable "instance_ami" {
  description = "AMI used for EC2 (region specific). Update to a valid AMI in your region."
  type        = string
  default     = "ami-00ac45f3035ff009e"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
