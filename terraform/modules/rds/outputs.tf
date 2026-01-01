output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.kong.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.kong.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.kong.endpoint
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.kong.address
}

output "db_instance_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.kong.port
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.kong.db_name
}

output "db_username" {
  description = "Master username for the database"
  value       = aws_db_instance.kong.username
  sensitive   = true
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.kong.name
}

output "db_parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.kong.name
}

