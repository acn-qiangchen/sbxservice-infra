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
}

# 2. Traffic from public subnet in AZ-1 (p1) to private subnet in AZ-2 (v2) through firewall in AZ-1 (n1)
resource "aws_route" "public_az1_to_private_az2_via_firewall_az1" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.private_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 3. Traffic from public subnet in AZ-2 (p2) to private subnet in AZ-1 (v1) through firewall in AZ-2 (n2)
resource "aws_route" "public_az2_to_private_az1_via_firewall_az2" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.private_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 4. Traffic from public subnet in AZ-2 (p2) to private subnet in AZ-2 (v2) through firewall in AZ-2 (n2)
resource "aws_route" "public_az2_to_private_az2_via_firewall_az2" {
  route_table_id         = var.public_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.private_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 5. Traffic from private subnet in AZ-1 (v1) to public subnet in AZ-1 (p1) through firewall in AZ-1 (n1)
resource "aws_route" "private_az1_to_public_az1_via_firewall_az1" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.public_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 6. Traffic from private subnet in AZ-1 (v1) to public subnet in AZ-2 (p2) through firewall in AZ-2 (n2)
resource "aws_route" "private_az1_to_public_az2_via_firewall_az2" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[0]]
  destination_cidr_block = var.public_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 7. Traffic from private subnet in AZ-2 (v2) to public subnet in AZ-1 (p1) through firewall in AZ-1 (n1)
resource "aws_route" "private_az2_to_public_az1_via_firewall_az1" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.public_subnet_cidrs[0]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[0]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 8. Traffic from private subnet in AZ-2 (v2) to public subnet in AZ-2 (p2) through firewall in AZ-2 (n2)
resource "aws_route" "private_az2_to_public_az2_via_firewall_az2" {
  route_table_id         = var.private_route_tables_by_az[var.availability_zones[1]]
  destination_cidr_block = var.public_subnet_cidrs[1]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[1]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# Route private subnet traffic to internet (0.0.0.0/0) through Network Firewall in same AZ
resource "aws_route" "private_to_internet_via_firewall" {
  for_each = var.private_route_tables_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoints_by_az[each.key]

  depends_on = [aws_networkfirewall_firewall.main]
}

# New routing pattern for Internet Gateway -> ALB through Network Firewall
# Create an edge route table for Internet Gateway
resource "aws_route_table" "igw_edge" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw-edge-rt"
  }
}

# Associate the edge route table with the Internet Gateway
resource "aws_route_table_association" "igw_edge" {
  gateway_id     = var.internet_gateway_id
  route_table_id = aws_route_table.igw_edge.id
}

# Route traffic from Internet Gateway to public subnets through Network Firewall
resource "aws_route" "igw_to_public_via_firewall" {
  for_each = {
    for i, az in var.availability_zones : az => {
      public_cidr = var.public_subnet_cidrs[i]
      endpoint_id = local.firewall_endpoints_by_az[az]
    }
  }

  route_table_id         = aws_route_table.igw_edge.id
  destination_cidr_block = each.value.public_cidr
  vpc_endpoint_id        = each.value.endpoint_id

  depends_on = [aws_networkfirewall_firewall.main]
}

# Instead of routing the entire VPC CIDR, create specific routes for private subnets
# This avoids conflicts with the default local route that AWS creates automatically
resource "aws_route" "igw_to_private_via_firewall" {
  count = length(var.private_subnet_cidrs)

  route_table_id         = aws_route_table.igw_edge.id
  destination_cidr_block = var.private_subnet_cidrs[count.index]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[count.index % length(var.availability_zones)]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# Add default routes for public subnets to reach the internet via firewall
resource "aws_route" "public_to_internet_via_firewall" {
  for_each = var.public_route_tables_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoints_by_az[each.key]

  depends_on = [aws_networkfirewall_firewall.main]
} 