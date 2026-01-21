# Child SG Module's variables

variable "security_group_parameters" {
  description = "AWS Security Group parameters"
  type = map(object({
    name     = string
    vpc_name = string
    vpc_id   = string
    tags     = optional(map(string), {})
  }))
  default = {}
}

variable "ipv4_ingress_rule" {
  description = "IPv4 ingress rule parameters"
  type = map(object({
    vpc_name                     = string
    sg_name                      = string
    security_group_id            = string
    from_port                    = number
    to_port                      = number
    protocol                     = string
    cidr_ipv4                    = optional(string) #VPC CIDR blocks can be passed here
    source_security_group_id     = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}
}

variable "sg_name_to_id_map" {
  description = "Optional map from security group name (as used in rules) to security group id created by another module"
  type        = map(string)
  default     = {}
}

variable "ipv6_ingress_rule" {
  description = "IPv6 ingress rule parameters"
  type = map(object({
    security_group_id = string
    from_port         = number
    to_port           = number
    protocol          = string
    cidr_ipv6         = string #VPC CIDR blocks can be passed here
  }))
  default = {}
}

variable "ipv4_egress_rule" {
  description = "IPv4 engress rule parameters"
  type = map(object({
    vpc_name                     = string
    sg_name                      = string
    security_group_id            = string
    protocol                     = string
    cidr_ipv4                    = optional(string) #VPC CIDR blocks can be passed here
    source_security_group_id     = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}
}

variable "ipv6_egress_rule" {
  description = "IPv6 engress rule parameters"
  type = map(object({
    security_group_id = string
    protocol          = string
    cidr_ipv6         = string #VPC CIDR blocks can be passed here
  }))
  default = {}
}