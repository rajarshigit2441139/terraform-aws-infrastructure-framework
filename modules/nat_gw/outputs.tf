output "nat_ids" {
  description = "Nat Ids"
  value       = { for name, nat in aws_nat_gateway.nat_gateway_module : name => { id = nat.id } }
}