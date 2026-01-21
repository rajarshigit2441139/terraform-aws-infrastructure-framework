output "nodegroups" {
  description = "All node group details from this module"
  value = {
    for k, v in aws_eks_node_group.nodegroup :
    k => {
      node_group_name = v.node_group_name
      arn             = v.arn
      node_role_name  = aws_iam_role.node[k].name
      node_role_arn   = aws_iam_role.node[k].arn
      instance_types  = v.instance_types
      status          = v.status
      labels          = v.labels
      tags            = v.tags

      scaling = {
        min     = v.scaling_config[0].min_size
        max     = v.scaling_config[0].max_size
        desired = v.scaling_config[0].desired_size
      }
    }
  }
}
