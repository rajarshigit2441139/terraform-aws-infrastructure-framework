variable "eks_clusters" {
  description = "Map of EKS cluster configurations"
  type = map(object({
    cluster_version         = string
    vpc_id                  = string
    subnet_ids              = list(string)
    security_group_ids      = optional(list(string))
    endpoint_public_access  = bool
    endpoint_private_access = bool
    tags                    = map(string)
  }))
}
