# VPC Configuration
vpc_parameters = {
  default = {
    my_vpc = {
      cidr_block = "10.10.0.0/16"
      tags = {
        Environment = "dev"
        Project     = "my-project"
      }
    }
  }
}

# Subnet Configuration
subnet_parameters = {
  default = {
    public_subnet_az1 = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags                    = { Type = "public" }
    }

    private_subnet_az1 = {
      cidr_block              = "10.10.10.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags                    = { Type = "private" }
    }
  }
}

