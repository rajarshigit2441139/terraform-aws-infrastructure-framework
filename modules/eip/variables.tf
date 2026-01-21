variable "eip_parameters" {
  type = map(object({
    domain                    = optional(string)
    network_interface         = optional(string)
    associate_with_private_ip = optional(string)
    instance                  = optional(string)
    public_ipv4_pool          = optional(string)
    ipam_pool_id              = optional(string)
    tags                      = map(string)
  }))
}