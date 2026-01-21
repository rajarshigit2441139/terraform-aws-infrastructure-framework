variable "vpc_endpoints" {
  type = map(object({
    region            = string
    vpc_id            = string
    service_name      = string
    vpc_endpoint_type = string # "Gateway" or "Interface"

    # Gateway only
    route_table_ids = optional(list(string))

    # Interface only
    subnet_ids          = optional(list(string))
    security_group_ids  = optional(list(string))
    private_dns_enabled = optional(bool)

    tags = optional(map(string))
  }))
}
