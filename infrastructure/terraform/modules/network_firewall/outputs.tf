output "firewall_id" {
  description = "ID of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.id
}

output "firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.arn
}

output "firewall_status" {
  description = "Full status details of the Network Firewall"
  value       = aws_networkfirewall_firewall.main.firewall_status
}

output "firewall_policy_id" {
  description = "ID of the Network Firewall Policy"
  value       = aws_networkfirewall_firewall_policy.main.id
} 