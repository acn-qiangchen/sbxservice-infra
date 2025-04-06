# Get current AWS region
data "aws_region" "current" {}

# AWS Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.project_name}-${var.environment}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    
    # stateful_rule_group_reference {
    #   resource_arn = aws_networkfirewall_rule_group.suricata_compatible.arn
    # }
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
      resource_arn = "arn:aws:network-firewall:${data.aws_region.current.name}:aws-managed:stateful-rulegroup/ThreatSignaturesScannersStrictOrder"
      priority     = 10
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-firewall-policy"
  }
}

# AWS Network Firewall with AWS Managed Suricata-compatible rule group
# resource "aws_networkfirewall_rule_group" "suricata_compatible" {
#   capacity = 100
#   name     = "${var.project_name}-${var.environment}-suricata-rules"
#   type     = "STATEFUL"
  
#   rule_group {
#     rule_variables {
#       ip_sets {
#         key = "HOME_NET"
#         ip_set {
#           definition = [var.vpc_cidr]
#         }
#       }
#     }
    
#     rules_source {
#       rules_string = <<EOF
# # Suricata compatible rules
# # Block known malicious user agents
# alert http any any -> $HOME_NET any (msg:"Potentially malicious user agent detected"; flow:established,to_server; http.user_agent; content:"malicious"; nocase; sid:1000001; rev:1;)

# # Detect potential SQL injection attempts
# alert http any any -> $HOME_NET any (msg:"SQL Injection attempt detected"; flow:established,to_server; http.uri; content:"union"; nocase; pcre:"/union\s+select/i"; sid:1000002; rev:1;)

# # Block known malicious IP ranges (example)
# alert ip [192.168.1.0/24,10.0.0.0/8] any -> $HOME_NET any (msg:"Connection attempt from suspicious IP"; sid:1000003; rev:1;)

# # HTTP protocol compliance check
# alert http any any -> $HOME_NET any (msg:"HTTP Protocol Violation"; flow:established,to_server; http.method; content:!"GET"; content:!"POST"; content:!"PUT"; content:!"DELETE"; content:!"HEAD"; content:!"OPTIONS"; content:!"CONNECT"; content:!"TRACE"; sid:1000004; rev:1;)
# EOF
#     }
#   }

#   tags = {
#     Name = "${var.project_name}-${var.environment}-suricata-rules"
#   }
# }

# AWS Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.project_name}-${var.environment}-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = var.vpc_id
  
  delete_protection   = false
  
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