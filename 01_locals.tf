# -------------- Local Extract ------------------#

# Extract VPC IDs
locals {
  vpc_id_by_name = { for name, vpc in module.chat_app_vpc.vpcs : name => vpc.id }
}

# Extract VPC cidr
locals {
  vpc_cidr_by_name = { for name, vpc in module.chat_app_vpc.vpcs : name => vpc.cidr_block }
}

# Extract sg_id
locals {
  sgs_id_by_name = { for name, sg in module.chat_app_security_group.sgs : name => sg.id }
}

# Extract Subnet IDs for RT associations
locals {
  subnet_id_by_name = { for name, subnet in module.chat_app_subnet.subnets : name => subnet.id }
}

# Extract RT IDs for RT associations
locals {
  rt_id_by_name = module.chat_app_rt.route_table_ids
}

# Extract Internet Gateway IDs
locals {
  extract_internet_gateway_ids = {
    for name, igw_obj in module.chat_app_ig.igws :
    name => igw_obj.id
  }
}

# Extract NATGateway IDs
locals {
  extract_nat_gateway_ids = {
    for name, nat in module.chat_app_nat.nat_ids :
    name => nat.id
  }
}
# Extract EIP IDs
locals {
  eip_id_by_name = { for name, eip in module.chat_app_eip.eips : name => eip.id }
}
