# Inject VPC IDs for vpc_endpoint
locals {
  generated_vpc_endpoint_parameters = {
    for workspace, endpoints in var.vpc_endpoint_parameters :
    workspace => {
      for name, ep in endpoints :
      name => merge(
        ep,
        {
          vpc_id = local.vpc_id_by_name[ep.vpc_name]

          # Only for Interface endpoints
          subnet_ids = (
            ep.vpc_endpoint_type == "Interface" ?
            [for sn in coalesce(ep.subnet_names, []) :
              lookup(local.subnet_id_by_name, sn)
            ] :
            null
          )

          security_group_ids = (
            ep.vpc_endpoint_type == "Interface" ?
            [for sg in coalesce(ep.security_group_names, []) :
              lookup(local.sgs_id_by_name, sg)
            ] :
            null
          )

          # Only for Gateway endpoints
          route_table_ids = (
            ep.vpc_endpoint_type == "Gateway" ?
            [for rt in coalesce(ep.route_table_names, []) :
              lookup(local.rt_id_by_name, rt)
            ] :
            null
          )
        }
      )
    }
  }
}




module "chat_app_vpc_endpoint" {
  source        = "./modules/vpc_endpoint"
  vpc_endpoints = lookup(local.generated_vpc_endpoint_parameters, terraform.workspace, {})
}