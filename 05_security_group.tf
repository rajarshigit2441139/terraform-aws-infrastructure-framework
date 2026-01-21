// -------------- Security Group Module -------------- //

// Inject VPC IDs for SG
locals {
  generated_sg_parameters = {
    for workspace, sgs in var.security_group_parameters :
    workspace => {
      for name, sg in sgs :
      name => merge(
        sg,
        { vpc_id = local.vpc_id_by_name[sg.vpc_name] }
      )
    }
  }
}


locals {

  vpc_cidr_by_name_from_var = {
    for name, vpc in lookup(var.vpc_parameters, terraform.workspace, {}) :
    name => try(vpc.cidr_block, null)
  }



  generated_ipv4_ingress_parameters = {
    for workspace, ings in var.ipv4_ingress_rule :
    workspace => {
      for name, ing in ings :
      name => (
        # CASE 1: SG → SG
        try(ing.source_security_group_name, null) != null
        ?
        merge(
          ing,
          {
            referenced_security_group_id = local.sgs_id_by_name[ing.source_security_group_name]
            cidr_ipv4                    = null
          }
        )
        :
        # CASE 2 + 3: CIDR rule
        #  - explicit cidr_ipv4
        #  - OR fallback to VPC CIDR
        merge(
          ing,
          {
            cidr_ipv4 = coalesce(
              try(ing.cidr_ipv4, null),
              lookup(local.vpc_cidr_by_name_from_var, ing.vpc_name, null)
            )
          }
        )
      )
    }
  }





  generated_ipv4_egress_parameters = {
    for workspace, egrs in var.ipv4_egress_rule :
    workspace => {
      for name, egr in egrs :
      name => (
        try(egr.source_security_group_name, null) != null
        ?
        # SG → SG egress rule
        merge(
          egr,
          {
            referenced_security_group_id = local.sgs_id_by_name[egr.source_security_group_name]
            cidr_ipv4                    = null
          }
        )
        :
        # CIDR egress rule (explicit or VPC fallback)
        merge(
          egr,
          {
            cidr_ipv4 = try(
              egr.cidr_ipv4,
              lookup(local.vpc_cidr_by_name_from_var, egr.vpc_name, null)
            )
          }
        )
      )
    }
  }
}




module "chat_app_security_group" {
  source                    = "./modules/security_group"
  security_group_parameters = lookup(local.generated_sg_parameters, terraform.workspace, {})
  depends_on                = [module.chat_app_vpc]
}

module "chat_app_security_rules" {
  source            = "./modules/security_group"
  ipv4_ingress_rule = lookup(local.generated_ipv4_ingress_parameters, terraform.workspace, {})
  ipv4_egress_rule  = lookup(local.generated_ipv4_egress_parameters, terraform.workspace, {})
  sg_name_to_id_map = local.sgs_id_by_name
  depends_on        = [module.chat_app_security_group]
}