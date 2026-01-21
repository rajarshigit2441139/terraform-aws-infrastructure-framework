variable "igw_parameters" {
  description = "IGW parameters"
  type = map(object({
    vpc_name = string
    vpc_id   = string
    tags     = optional(map(string), {})
  }))
  default = {}
}