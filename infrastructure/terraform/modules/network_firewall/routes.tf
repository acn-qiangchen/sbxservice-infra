# Create routes for traffic between subnets through the Network Firewall
resource "aws_route" "public_to_private_through_firewall" {
  # Use static keys for the for_each to avoid the "derived from resource attributes" error
  for_each = {
    for i, az in var.availability_zones : 
    "az-${i}" => {
      az = az
      private_cidr = var.private_subnet_cidrs[i]
      public_rt_id = var.public_route_tables_by_az[az]
    }
  }

  route_table_id         = each.value.public_rt_id
  destination_cidr_block = each.value.private_cidr
  vpc_endpoint_id        = [
    for sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states :
    sync_state.attachment[0].endpoint_id
    if sync_state.availability_zone == each.value.az
  ][0]

  depends_on = [aws_networkfirewall_firewall.main]
}

resource "aws_route" "private_to_public_through_firewall" {
  # Use static keys for the for_each to avoid the "derived from resource attributes" error
  for_each = {
    for i, az in var.availability_zones : 
    "az-${i}" => {
      az = az
      public_cidr = var.public_subnet_cidrs[i]
      private_rt_id = var.private_route_tables_by_az[az]
    }
  }

  route_table_id         = each.value.private_rt_id
  destination_cidr_block = each.value.public_cidr
  vpc_endpoint_id        = [
    for sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states :
    sync_state.attachment[0].endpoint_id
    if sync_state.availability_zone == each.value.az
  ][0]

  depends_on = [aws_networkfirewall_firewall.main]
} 