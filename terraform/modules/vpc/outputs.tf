output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "firewall_subnets" {
  description = "List of IDs of firewall subnets"
  value       = aws_subnet.firewall[*].id
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_id" {
  description = "ID of the primary NAT Gateway (for backwards compatibility)"
  value       = aws_nat_gateway.main[0].id
}

output "nat_gateway_ids" {
  description = "List of all NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_ids_by_az" {
  description = "Map of AZ to NAT Gateway IDs"
  value       = { for i, az in var.availability_zones : az => aws_nat_gateway.main[i].id }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_route_tables_by_az" {
  description = "Map of AZ to public route table IDs"
  value       = { for az, rt in aws_route_table.public : az => rt.id }
}

output "private_route_tables_by_az" {
  description = "Map of AZ to private route table IDs"
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}

output "firewall_route_tables_by_az" {
  description = "Map of AZ to firewall route table IDs"
  value       = { for az, rt in aws_route_table.firewall : az => rt.id }
} 