output "route_table_ids" {
  description = "Map of route table IDs"
  value       = { for key, rt in aws_route_table.example : key => rt.id }
}
