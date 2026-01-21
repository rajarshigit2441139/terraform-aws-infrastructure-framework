# -------------- IGW module -------------- #

# Inject VPC IDs for IGWs
locals {
  generated_igw_parameters = {
    for workspace, igws in var.igw_parameters :
    workspace => {
      for name, igw in igws :
      name => merge(
        igw,
        { vpc_id = local.vpc_id_by_name[igw.vpc_name] }
      )
    }
  }
}

module "chat_app_ig" {
  source         = "./modules/igw"
  igw_parameters = lookup(local.generated_igw_parameters, terraform.workspace, {})
  depends_on     = [module.chat_app_vpc]
}


# -------------- NAT module -------------- #

# Inject Subnet IDs into nat_gateway_parameters
locals {
  generated_nat_gateway_parameters = {
    for workspace, nat_gateways in var.nat_gateway_parameters :
    workspace => {
      for name, nat_gateway in nat_gateways :
      name => merge(
        nat_gateway,
        { subnet_id     = local.subnet_id_by_name[nat_gateway.subnet_name]
          allocation_id = local.eip_id_by_name[nat_gateway.eip_name_for_allocation_id]
        }
      )
    }
  }
}

module "chat_app_nat" {
  source                 = "./modules/nat_gw"
  nat_gateway_parameters = lookup(local.generated_nat_gateway_parameters, terraform.workspace, {})
  depends_on             = [module.chat_app_ig]
}
