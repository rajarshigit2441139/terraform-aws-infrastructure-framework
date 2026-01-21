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

variable "rt_parameters" {
  description = "Route table parameters"
  type = map(object({
    vpc_name = string
    vpc_id   = optional(string)
    tags     = optional(map(string), {})
    routes = optional(list(object({
      cidr_block  = string
      target_type = string # "igw" | "nat" | "vgw" | "tgw" | etc.
      target_key  = string # name or id
    })), [])

  }))
  default = {}
}