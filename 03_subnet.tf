
# -------------- Subnet module -------------- #

# AZ
data "aws_availability_zones" "available" {}

# Inject VPC IDs for subnets
locals {
  generated_subnet_parameters = {
    for workspace, subnets in var.subnet_parameters :
    workspace => {
      for name, subnet in subnets :
      name => merge(
        subnet,
        { vpc_id            = local.vpc_id_by_name[subnet.vpc_name]
          availability_zone = data.aws_availability_zones.available.names[subnet.az_index]
        }
      )
    }
  }
}

module "chat_app_subnet" {
  source            = "./modules/subnet"
  subnet_parameters = lookup(local.generated_subnet_parameters, terraform.workspace, {})
  depends_on        = [module.chat_app_vpc]
}