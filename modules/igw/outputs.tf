output "igws" {
  description = "Internet Gateway resources"
  value       = { for name, igw in aws_internet_gateway.igw_module : name => { id = igw.id } }
}