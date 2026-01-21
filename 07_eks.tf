locals {
  # Workspace selection
  cluster_config = lookup(var.eks_clusters, terraform.workspace, {})

  # Transform cluster configs by injecting vpc_id + subnet_ids
  generated_cluster_config = {
    for cluster_name, cluster in local.cluster_config :
    cluster_name => merge(
      cluster,
      {
        vpc_id = local.vpc_id_by_name[cluster.vpc_name]

        subnet_ids = [
          for subnet_name in cluster.subnet_name :
          local.subnet_id_by_name[subnet_name]
        ]

        # Inject SG IDs using your prepared local map
        security_group_ids = [
          for sg_name in cluster.sg_name :
          local.sgs_id_by_name[sg_name]
        ]
      }
    )
  }
}

# -----------------------------
#   EKS CLUSTER (per workspace)
# -----------------------------
module "eks_cluster" {
  source = "./modules/eks_mng/eks_cluster"

  for_each = local.generated_cluster_config

  eks_clusters = {
    (each.key) = each.value
  }

  depends_on = [
    module.chat_app_subnet,
    module.chat_app_security_group,
    module.chat_app_security_rules,
  ]
}

# -----------------------------------------
#   NODEGROUPS (per cluster per workspace)
# -----------------------------------------

locals {
  # Get workspace-specific nodegroup config
  ws_nodegroup_config = lookup(var.eks_nodegroups, terraform.workspace, {})

  # Flatten all nodegroups across clusters (workspace scoped)
  flat_nodegroups = flatten([
    for cluster_name, ngroups in local.ws_nodegroup_config : [
      for ng_name, ng in ngroups : {
        key          = "${cluster_name}/${ng_name}"
        cluster_name = cluster_name
        ng_name      = ng_name
        config       = ng
      }
    ]
  ])

  flat_nodegroups_map = {
    for ng in local.flat_nodegroups :
    ng.key => ng.config
  }

}


# Fetch AMI if not present
data "aws_ssm_parameter" "eks_ami" {
  for_each = {
    for k, ng in local.flat_nodegroups_map :
    k => ng
    if ng.instance_ami == ""
  }

  name = "/aws/service/eks/optimized-ami/${each.value.k8s_version}/amazon-linux-2023/${each.value.arch}/standard/recommended/image_id"
}

locals {
  generated_nodegroup_config = {
    for cluster_name, ngroups in local.ws_nodegroup_config :
    cluster_name => {
      for ng_name, ng in ngroups :
      ng_name => merge(
        ng,
        {

          arch = ng.arch
          # subnet name to subnet id 
          subnet_ids = [
            for sn in ng.subnet_name :
            local.subnet_id_by_name[sn]
          ]
          # sg name to sg id
          node_security_group_ids = [
            for node_security_group_names in ng.node_security_group_names :
            local.sgs_id_by_name[node_security_group_names]
          ]
          # AMI
          instance_ami = (
            try(ng.instance_ami, "") != ""
            ? ng.instance_ami
            : data.aws_ssm_parameter.eks_ami["${cluster_name}/${ng_name}"].value
          )
        }
      )
    }
  }
}



module "eks_nodegroups" {
  for_each = local.generated_nodegroup_config

  source = "./modules/eks_mng/eks_nodegroups"

  cluster_name = module.eks_cluster[each.key].eks_clusters[each.key].cluster_name

  nodegroup_parameters = each.value

  depends_on = [module.eks_cluster,
    module.chat_app_security_group,
    module.chat_app_security_rules,
    module.chat_app_subnet
  ]
}
