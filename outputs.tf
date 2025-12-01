output "ec2_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.mon_serveur_web.public_ip
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.mydb.endpoint
}

output "db_resource_id" {
  description = "DB resource id (used in IAM policy ARNs)"
  value       = aws_db_instance.mydb.resource_id
}

output "db_master_password" {
  description = "Initial DB master password (sensitive)"
  value       = random_password.db.result
  sensitive   = true
}
