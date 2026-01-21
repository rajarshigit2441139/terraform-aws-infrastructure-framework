output "eks_clusters" {
  description = "All EKS clusters created by this module"
  value = {
    for k, v in aws_eks_cluster.cluster :
    k => {
      cluster_name                      = v.name
      cluster_arn                       = v.arn
      cluster_endpoint                  = v.endpoint
      cluster_cert                      = v.certificate_authority[0].data
      cluster_role_arn                  = aws_iam_role.eks_cluster[k].arn
      cluster_version                   = v.version
      cluster_primary_security_group_id = v.vpc_config[0].cluster_security_group_id
    }
  }
}
