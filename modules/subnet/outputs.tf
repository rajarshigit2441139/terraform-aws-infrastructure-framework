output "subnets" {
  description = "Subnet Outputs"
  value       = { for subnet in aws_subnet.subnet_module : subnet.tags.Name => { "cidr_block" : subnet.cidr_block, "id" : subnet.id } }
}