# -------------- VPC Parameters -------------- #

variable "vpc_parameters" {
  description = "VPC parameters"
  type = map(map(object({
    cidr_block           = string
    enable_dns_support   = optional(bool, true)
    enable_dns_hostnames = optional(bool, true)
    tags                 = optional(map(string), {})
  })))
  default = {}
}


# -------------- Subnet Parameters -------------- #

variable "subnet_parameters" {
  description = "Subnet parameters"
  type = map(map(object({
    cidr_block              = string
    vpc_name                = string
    vpc_id                  = optional(string)
    availability_zone       = optional(string)
    az_index                = number
    map_public_ip_on_launch = optional(bool)
    tags                    = optional(map(string), {})
  })))
  default = {}
}


# -------------- IGW Parameters -------------- #

variable "igw_parameters" {
  description = "IGW parameters"
  type = map(map(object({
    vpc_name = string
    # vpc_id   = optional(string)
    tags = optional(map(string), {})
  })))
  default = {}
}

# -------------- RT Parameters -------------- #

variable "rt_parameters" {
  description = "Route table parameters"
  type = map(map(object({
    vpc_name = string
    vpc_id   = optional(string)
    tags     = optional(map(string), {})
    routes = optional(list(object({
      cidr_block  = string
      target_type = string # "igw" | "nat" | "vgw" | "tgw" | etc.
      target_key  = string # name or id
    })), [])

  })))
  default = {}
}
variable "internet_gateway_ids" {
  description = "Map of internet gateway IDs keyed by identifier"
  type        = map(string)
  default     = {}
}

variable "nat_gateway_ids" {
  description = "Map of internet gateway IDs keyed by identifier"
  type        = map(string)
  default     = {}
}

# -------------- RT Associations Parameters -------------- #

variable "rt_association_parameters" {
  description = "RT association parameters"
  type = map(object({
    subnet_name    = string
    subnet_id      = optional(string)
    route_table_id = optional(string)
    rt_name        = string
  }))
  default = {}
}


# -------------- SG Parameters -------------- #

variable "security_group_parameters" {
  description = "AWS Security Group parameters"
  type = map(map(object({
    name     = string
    vpc_name = string
    vpc_id   = optional(string)
    tags     = optional(map(string), {})
  })))
  default = {}
}


# -------------- SG Rules Parameters -------------- #

variable "ipv4_ingress_rule" {
  description = "IPv4 ingress rule parameters"
  type = map(map(object({
    vpc_name                   = string
    sg_name                    = string
    security_group_id          = optional(string)
    from_port                  = optional(number)
    to_port                    = optional(number)
    protocol                   = string
    source_security_group_name = optional(string)
    cidr_ipv4                  = optional(string) #VPC CIDR blocks can be passed here
  })))
  default = {}
}

variable "ipv4_egress_rule" {
  description = "IPv4 engress rule parameters"
  type = map(map(object({
    vpc_name                   = string
    sg_name                    = string
    security_group_id          = optional(string)
    source_security_group_name = optional(string)
    cidr_ipv4                  = optional(string) #VPC CIDR blocks can be passed here or IPs: "0.0.0.0"
    protocol                   = string
  })))
  default = {}
}

# -------------- EIP Parameters -------------- #
variable "eip_parameters" {
  type = map(map(object({
    domain                    = optional(string)
    network_interface         = optional(string)
    associate_with_private_ip = optional(string)
    instance                  = optional(string)
    public_ipv4_pool          = optional(string)
    ipam_pool_id              = optional(string)
    tags                      = map(string)
  })))
  default = {}
}

# -------------- NAT Parameters -------------- #
variable "nat_gateway_parameters" {
  description = "Nat parameters"
  type = map(map(object({
    subnet_name                        = string
    connectivity_type                  = optional(string) #"private"
    secondary_private_ip_address_count = optional(number)
    eip_name_for_allocation_id         = optional(string)
    secondary_allocation_ids           = optional(list(string))
    secondary_private_ip_addresses     = optional(list(string))
    tags                               = optional(map(string), {})
  })))
  default = {}
}


# -------------- vpc_endpoint Parameters -------------- #
variable "vpc_endpoint_parameters" {
  type = map(map(object({
    region            = string
    vpc_name          = string
    service_name      = string
    vpc_endpoint_type = string # "Gateway" or "Interface"

    # Gateway only
    route_table_names = optional(list(string))

    # Interface only
    subnet_names         = optional(list(string))
    security_group_names = optional(list(string))
    private_dns_enabled  = optional(bool)

    tags = optional(map(string))
  })))
  default = {}
}


# -------------- eks_cluster Parameters -------------- #

variable "eks_clusters" {
  description = "Map of EKS cluster configurations"
  type = map(map(object({
    cluster_version         = string
    vpc_name                = optional(string)
    vpc_id                  = optional(string)
    subnet_name             = optional(list(string))
    subnet_ids              = optional(list(string))
    sg_name                 = optional(list(string))
    endpoint_public_access  = bool
    endpoint_private_access = bool
    tags                    = map(string)
  })))
  default = {}
}


# -------------- eks_nodegroup Parameters -------------- #

variable "eks_nodegroups" {
  description = "Map of nodegroup configs per environment"
  type = map(map(map(object({
    k8s_version               = optional(string)
    arch                      = optional(string)
    min_size                  = number
    max_size                  = number
    desired_size              = number
    instance_types            = string
    instance_ami              = optional(string)
    subnet_name               = optional(list(string))
    subnet_ids                = optional(list(string))
    node_security_group_names = list(string)
    tags                      = map(string)
  }))))
  default = {}
}