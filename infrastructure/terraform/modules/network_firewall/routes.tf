# Network Firewall Routing Configuration
# 
# IMPORTANT: Before applying this configuration, you need to manually delete any existing 
# conflicting routes in the route tables. Otherwise, you'll get "RouteAlreadyExists" errors.
# You can use the following AWS CLI command to delete conflicting routes:
#
# aws ec2 delete-route --route-table-id <rtb-id> --destination-cidr-block <cidr>
#
# For example:
# aws ec2 delete-route --route-table-id rtb-0123456789abcdef --destination-cidr-block 10.0.10.0/24
#
# This configuration implements the following routing pattern:
# - Traffic from public subnet in AZ-1 (p1) to private subnets (v1, v2) routes through firewall in AZ-1 (n1)
# - Traffic from public subnet in AZ-2 (p2) to private subnets (v1, v2) routes through firewall in AZ-2 (n2)
# - Traffic from private subnets (v1, v2) to public subnet in AZ-1 (p1) routes through firewall in AZ-1 (n1)
# - Traffic from private subnets (v1, v2) to public subnet in AZ-2 (p2) routes through firewall in AZ-2 (n2)
# - Traffic from private subnets to VPC endpoints (ECR, etc.) bypasses the firewall
#   (this is handled naturally by AWS VPC endpoint routing without explicit route definitions)

# Create routes for traffic through the Network Firewall with specific routing patterns
# We'll use the replace_route pattern to handle existing routes

# Get firewall endpoints by AZ for easier reference
locals {
  firewall_endpoints_by_az = {
    for sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states :
      sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}

# 1. Traffic from public subnet in AZ-1 (p1) to private subnet in AZ-1 (v1) through firewall in AZ-1 (n1)
resource "aws_route" "public_az1_to_private_az1_via_firewall_az1" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.private_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 2. Traffic from public subnet in AZ-1 (p1) to private subnet in AZ-2 (v2) through firewall in AZ-1 (n1)
resource "aws_route" "public_az1_to_private_az2_via_firewall_az1" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.private_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 3. Traffic from public subnet in AZ-2 (p2) to private subnet in AZ-1 (v1) through firewall in AZ-2 (n2)
resource "aws_route" "public_az2_to_private_az1_via_firewall_az2" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.private_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 4. Traffic from public subnet in AZ-2 (p2) to private subnet in AZ-2 (v2) through firewall in AZ-2 (n2)
resource "aws_route" "public_az2_to_private_az2_via_firewall_az2" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.private_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 5. Traffic from private subnet in AZ-1 (v1) to public subnet in AZ-1 (p1) through firewall in AZ-1 (n1)
resource "aws_route" "private_az1_to_public_az1_via_firewall_az1" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.public_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 6. Traffic from private subnet in AZ-1 (v1) to public subnet in AZ-2 (p2) through firewall in AZ-2 (n2)
resource "aws_route" "private_az1_to_public_az2_via_firewall_az2" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.public_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 7. Traffic from private subnet in AZ-2 (v2) to public subnet in AZ-1 (p1) through firewall in AZ-1 (n1)
resource "aws_route" "private_az2_to_public_az1_via_firewall_az1" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.public_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
}

# 8. Traffic from private subnet in AZ-2 (v2) to public subnet in AZ-2 (p2) through firewall in AZ-2 (n2)
resource "aws_route" "private_az2_to_public_az2_via_firewall_az2" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.public_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]
  
  depends_on = [aws_networkfirewall_firewall.main]
  
  lifecycle {
    create_before_destroy = true
  }
} 