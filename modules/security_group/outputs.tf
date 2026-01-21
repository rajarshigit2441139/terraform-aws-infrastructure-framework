# Child SG Module's Outputs

output "sgs" {
  description = "Map of SGs outputs by Name"
  value = {
    for sgs in aws_security_group.example :
    sgs.tags.Name => {
      name       = sgs.tags.Name
      id         = sgs.id
    }
  }
}
