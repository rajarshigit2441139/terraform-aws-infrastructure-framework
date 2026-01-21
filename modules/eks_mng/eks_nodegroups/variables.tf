variable "cluster_name" {
  type = string
}

variable "nodegroup_parameters" {
  description = "Map of node group configurations"
  type = map(object({
    min_size                = number
    max_size                = number
    desired_size            = number
    arch                    = string
    instance_types          = string
    instance_ami            = string
    subnet_ids              = list(string)
    node_security_group_ids = list(string)
    tags                    = map(string)
  }))
}

variable "additional_policies" {

  type = map(object({
    nodegroups = list(string)
    policy     = list(string)
  }))

  # 1. Ensure that all nodegroups in additional_policies exist in nodegroup_parameters
  validation {
    condition = alltrue([
      for pol_name, pol in var.additional_policies :
      alltrue([
        for ng in pol.nodegroups :
        contains(keys(var.nodegroup_parameters), ng)
      ])
    ])

    error_message = <<EOT
Validation failed: One or more nodegroup names in additional_policies.<policy>.nodegroups 
do not exist in nodegroup_parameters.
EOT
  }

  # 2. Ensure policy list is NOT empty
  validation {
    condition = alltrue([
      for pol_name, pol in var.additional_policies :
      length(pol.policy) > 0
    ])

    error_message = <<EOT
Validation failed: Each additional_policies.<policy>.policy list must NOT be empty.
Provide at least one IAM JSON policy per policy group.
EOT
  }

  # 3. Ensure nodegroups list is NOT empty
  validation {
    condition = alltrue([
      for pol_name, pol in var.additional_policies :
      length(pol.nodegroups) > 0
    ])

    error_message = <<EOT
Validation failed: Each additional_policies.<policy>.nodegroups list must NOT be empty.
Specify at least one nodegroup to attach the policy to.
EOT
  }
  default = {}
}

