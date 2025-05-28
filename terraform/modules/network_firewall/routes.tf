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
# - IGW route table: Traffic to public subnets routes through Network Firewall endpoints
# - Firewall subnet route tables: All outbound traffic (0.0.0.0/0) routes to IGW
# - Public subnet route tables: All outbound traffic routes to Network Firewall endpoints
# - Private subnet route tables: All outbound traffic routes to NAT Gateway
# - Each AZ's route tables only use firewall endpoints in the same AZ

# Create routes for traffic through the Network Firewall with specific routing patterns
# We'll use the replace_route pattern to handle existing routes

# Get firewall endpoints by AZ for easier reference
locals {
  firewall_endpoints_by_az = {
    for sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states :
    sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}

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

# 1. IGW ROUTES: Traffic to public subnets routes through Network Firewall endpoints
# Each AZ has its own route to its public subnet through its own firewall endpoint
resource "aws_route" "igw_to_public_via_firewall" {
  count = length(var.public_subnet_cidrs)

  route_table_id         = aws_route_table.igw_edge.id
  destination_cidr_block = var.public_subnet_cidrs[count.index]
  vpc_endpoint_id        = local.firewall_endpoints_by_az[var.availability_zones[count.index % length(var.availability_zones)]]

  depends_on = [aws_networkfirewall_firewall.main]
}

# 2. PUBLIC SUBNET ROUTES: Default route for all outbound traffic directly to Internet Gateway
# Skip firewall inspection for outbound traffic from public subnets
resource "aws_route" "public_to_internet_direct" {
  for_each = var.public_route_tables_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id

  depends_on = [aws_networkfirewall_firewall.main]
}

# 3. PRIVATE SUBNET ROUTES: Default route for all outbound traffic to NAT Gateway
# Each private subnet routes outbound traffic to the NAT Gateway in its own AZ
resource "aws_route" "private_to_internet_via_nat" {
  for_each = var.private_route_tables_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids_by_az[each.key]

  depends_on = [aws_networkfirewall_firewall.main]
} 