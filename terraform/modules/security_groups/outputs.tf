output "public_sg_id" {
  description = "ID of the public security group"
  value       = aws_security_group.public.id
}

output "application_sg_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}

output "database_sg_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
} 