output "vpcs" {
  description = "Map of VPC outputs by Name"
  value = {
    for vpc in aws_vpc.vpc_module :
    vpc.tags.Name => {
      name       = vpc.tags.Name
      id         = vpc.id
      cidr_block = vpc.cidr_block
    }
  }
}
