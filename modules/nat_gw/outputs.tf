output "nat_ids" {
  description = "Nat Ids"
  value       = { for name, nat in aws_nat_gateway.example : name => { id = nat.id } }
}