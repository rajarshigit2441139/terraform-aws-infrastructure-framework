# ROOT LEVEL OUTPUTS.TF

output "vpc_ids" {
  description = "Map of VPC IDs by name from the VPC module"
  value       = { for name, vpc in module.chat_app_vpc.vpcs : name => vpc.id }
}

output "vpc_cidr_blocks" {
  description = "Map of VPC CIDR blocks by name from the VPC module"
  value       = { for name, vpc in module.chat_app_vpc.vpcs : name => vpc.cidr_block }
}

output "vpc_names" {
  description = "List of VPC names from the VPC module"
  value       = [for name, vpc in module.chat_app_vpc.vpcs : vpc.name]
}

output "subnet_id" {
  value = { for name, subnet in module.chat_app_subnet.subnets : name => subnet.id }
}

output "igws_ids" {
  description = "Map of IGW IDs from the IGW module"
  value       = { for name, igw in module.chat_app_ig.igws : name => { id = igw.id } }
}

output "nat_ids" {
  description = "Nat Ids"
  value       = { for name, nat in module.chat_app_nat.nat_ids : name => { id = nat.id } }
}

output "rt_ids" {
  description = "Map of route table IDs from the RT module"
  value       = module.chat_app_rt.route_table_ids
}

output "sg_ids" {
  value = { for name, sgs_obj in module.chat_app_security_group.sgs : name => sgs_obj.id }
}


output "eips_id" {
  value = { for name, eip in module.chat_app_eip.eips : name => eip.id }
}



###############################################
# Root Outputs — EKS Clusters (Multi-Cluster) #
###############################################

# Output all cluster names
output "eks_cluster_names" {
  description = "Map of cluster keys to cluster names"
  value = {
    for k, mod in module.eks_cluster :
    k => lookup(mod.eks_clusters[k], "cluster_name", null)
  }
}

# Output all cluster ARNs
output "eks_cluster_arns" {
  description = "Map of cluster keys to cluster ARNs"
  value = {
    for k, mod in module.eks_cluster :
    k => lookup(mod.eks_clusters[k], "arn", null)
  }
}

# Output all cluster API endpoints
output "eks_cluster_endpoints" {
  description = "Map of cluster keys to API endpoints"
  value = {
    for k, mod in module.eks_cluster :
    k => lookup(mod.eks_clusters[k], "endpoint", null)
  }
}

# Output all CA certificates
output "eks_cluster_ca_certs" {
  description = "Map of cluster keys to CA certs"
  value = {
    for k, mod in module.eks_cluster :
    k => lookup(mod.eks_clusters[k], "cert", null)
  }
}

# Output all role ARNs (if present)
output "eks_cluster_role_arns" {
  description = "Map of cluster keys to role ARNs"
  value = {
    for k, mod in module.eks_cluster :
    k => lookup(mod.eks_clusters[k], "role_arn", null)
  }
}

# Output cluster versions
output "eks_cluster_versions" {
  description = "Map of cluster keys to cluster version"
  value = {
    for k, mod in module.eks_cluster :
    k => lookup(mod.eks_clusters[k], "version", null)
  }
}


