output "vpc_endpoint_ids" {
  description = "Map of all VPC endpoint IDs"
  value       = { for k, v in aws_vpc_endpoint.example : k => v.id }
}

output "vpc_endpoint_arns" {
  description = "Map of all VPC endpoint ARNs"
  value       = { for k, v in aws_vpc_endpoint.example : k => v.arn }
}

output "vpc_endpoint_dns_entries" {
  description = "DNS entries for Interface endpoints (empty for Gateway endpoints)"
  value = {
    for k, v in aws_vpc_endpoint.example :
    k => try(v.dns_entry, [])
  }
}

output "vpc_endpoint_network_interface_ids" {
  description = "Network interface IDs for Interface endpoints (empty for Gateway endpoints)"
  value = {
    for k, v in aws_vpc_endpoint.example :
    k => try(v.network_interface_ids, [])
  }
}

output "vpc_endpoint_type" {
  description = "Type of each VPC endpoint (Gateway / Interface)"
  value = {
    for k, v in aws_vpc_endpoint.example :
    k => v.vpc_endpoint_type
  }
}
