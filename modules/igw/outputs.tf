output "igws" {
  description = "Internet Gateway resources"
  value       = { for name, igw in aws_internet_gateway.example : name => { id = igw.id } }
}