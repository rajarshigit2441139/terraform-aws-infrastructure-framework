variable "nat_gateway_parameters" {
  description = "Nat parameters"
  type = map(object({
    subnet_id                          = string
    connectivity_type                  = optional(string) #"private"
    secondary_private_ip_address_count = optional(number)
    allocation_id                      = optional(string)
    secondary_allocation_ids           = optional(list(string))
    secondary_private_ip_addresses     = optional(list(string))
    tags                               = optional(map(string), {})
  }))
  default = {}
}
