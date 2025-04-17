# Get current AWS region
data "aws_region" "current" {}

# AWS Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.project_name}-${var.environment}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    policy_variables {
      rule_variables {
        key = "HOME_NET"
        ip_set {
          definition = var.private_subnet_cidrs
        }
      }
    }

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.custom_http_headers.arn
      priority     = 5
    }

    stateful_rule_group_reference {
      resource_arn = "arn:aws:network-firewall:${data.aws_region.current.name}:aws-managed:stateful-rulegroup/ThreatSignaturesScannersStrictOrder"
      priority     = 10
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-firewall-policy"
  }
}

# Custom rule group for HTTP header inspection
resource "aws_networkfirewall_rule_group" "custom_http_headers" {
  capacity = 100
  name     = "${var.project_name}-${var.environment}-http-headers"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
# Block HTTP requests with 'attack' header
drop http any any -> $HOME_NET any (msg:"Attack header detected"; flow:established,to_server; http.header; content:"attack"; nocase; sid:1000001; rev:1;)

# Additional HTTP header inspection rules
drop http any any -> $HOME_NET any (msg:"Malicious header detected - XSS attempt"; flow:established,to_server; http.header; content:"<script>"; nocase; sid:1000002; rev:1;)

# Block requests with specific query parameters
drop http any any -> $HOME_NET any (msg:"SQL Injection attempt in query"; flow:established,to_server; http.uri; content:"union"; nocase; content:"select"; nocase; sid:1000003; rev:1;)
EOF
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-http-headers"
  }
}

# AWS Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.project_name}-${var.environment}-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = var.vpc_id

  delete_protection = false

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-network-firewall"
  }
}

# CloudWatch Log Groups for Network Firewall logs
resource "aws_cloudwatch_log_group" "network_firewall_flow" {
  name              = "/aws/network-firewall/${var.project_name}-${var.environment}/flow"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-network-firewall-flow-logs"
  }
}

resource "aws_cloudwatch_log_group" "network_firewall_alert" {
  name              = "/aws/network-firewall/${var.project_name}-${var.environment}/alert"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-network-firewall-alert-logs"
  }
}

# Configure Network Firewall logging
resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.network_firewall_flow.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.network_firewall_alert.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

# We'll need to use a terraform output and apply in two stages
# Stage 1: Create the firewall without routes
# Stage 2: Use terraform output to get the endpoints and apply routes in second run

# We need to output the firewall details after creation
# Then use a target approach to create Network Firewall first
# Then add routes in a subsequent apply

# These routes must be added manually after the firewall is created
# and endpoints are known

# Example Go-Traffic route (ALB -> ECS through Firewall)
# resource "aws_route" "alb_to_ecs_through_firewall" {
#   route_table_id         = lookup(var.public_route_tables_by_az, each.key, null)
#   destination_cidr_block = each.value.destination_cidr
#   vpc_endpoint_id        = each.value.endpoint_id
# }

# Example Return-Traffic route (ECS -> ALB through Firewall)
# resource "aws_route" "ecs_to_alb_through_firewall" {
#   route_table_id         = lookup(var.private_route_tables_by_az, each.key, null)
#   destination_cidr_block = each.value.destination_cidr
#   vpc_endpoint_id        = each.value.endpoint_id
# } 