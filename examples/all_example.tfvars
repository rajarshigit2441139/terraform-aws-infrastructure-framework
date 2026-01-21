# -------------- VPC Parameters -------------- #
vpc_parameters = {        # variable
  default = {             # worksapce
    chat_app_dev_vpc1 = { #vpc name/key
      cidr_block           = "10.10.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags = {
        Environment = "dev"
      }
    }
  }

  qe = {
    chat_app_qe_vpc1 = {
      cidr_block           = "10.20.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags = {
        Environment = "qe"
      }
    }
  }

  prod = {
    chat_app_prod_vpc1 = {
      cidr_block = "10.30.0.0/16"
      tags = {
        Environment = "prod"
      }
    }
  }
}


# -------------- Subnet Parameters -------------- #
subnet_parameters = {
  default = {
    #VPC1
    cad_vpc1_pub_sub1 = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "chat_app_dev_vpc1"
      az_index                = 0
      map_public_ip_on_launch = false
      tags                    = { Environment = "dev" }
    }

    cad_vpc1_pub_sub2 = {
      cidr_block              = "10.10.2.0/24"
      vpc_name                = "chat_app_dev_vpc1"
      az_index                = 0
      map_public_ip_on_launch = false
      tags                    = { Environment = "dev" }
    }

    cad_vpc1_pri_sub1 = {
      cidr_block              = "10.10.3.0/24"
      vpc_name                = "chat_app_dev_vpc1"
      az_index                = 0
      map_public_ip_on_launch = false
      tags                    = { Environment = "dev" }
    }

    cad_vpc1_pri_sub2 = {
      cidr_block              = "10.10.4.0/24"
      vpc_name                = "chat_app_dev_vpc1"
      az_index                = 1
      map_public_ip_on_launch = false
      tags                    = { Environment = "dev" }
    }
  }
}


# -------------- IG Parameters -------------- #

igw_parameters = {
  default = {
    #VPC1
    cad_vpc1_igw = {
      vpc_name = "chat_app_dev_vpc1"
      tags     = { Environment = "dev" }
    }
  }
}


# -------------- RT Parameters -------------- #

rt_parameters = {
  default = {
    # Public RT for VPC1
    vpc1_pub_rt = { # 1st rt
      vpc_name = "chat_app_dev_vpc1"
      routes = [{
        cidr_block  = "0.0.0.0/0"    # Destination for default route, for example
        target_type = "igw"          # Use IGW from your lookup
        target_key  = "cad_vpc1_igw" # The key/name of your IGW, not its ID directly
      }]
      tags = {
        Environment = "dev"
        VPC         = "chat_app_dev_vpc1"
      }
    }
    # Private RT for VPC1
    vpc1_pri_rt = { # 2nd rt
      vpc_name = "chat_app_dev_vpc1"
      routes = [{
        cidr_block  = "0.0.0.0/0"     # Destination for default route, for example
        target_type = "nat"           # Use IGW from your lookup
        target_key  = "chat_app_nat1" # The key/name of your IGW, not its ID directly
      }]
      tags = {
        Environment = "dev"
        VPC         = "chat_app_dev_vpc1"
      }
    }
  }
}

# -------------- RT Associations Parameters -------------- #

rt_association_parameters = {
  # VPC 1 PUB
  rt_assco_pub_sub1 = {
    subnet_name = "cad_vpc1_pub_sub1"
    rt_name     = "vpc1_pub_rt"
  }
  rt_assco_pub_sub2 = {
    subnet_name = "cad_vpc1_pub_sub2"
    rt_name     = "vpc1_pub_rt"
  }
  # VPC 1 PRI
  rt_assco_pri_sub1 = {
    subnet_name = "cad_vpc1_pri_sub1"
    rt_name     = "vpc1_pri_rt"
  }
  rt_assco_pri_sub2 = {
    subnet_name = "cad_vpc1_pri_sub2"
    rt_name     = "vpc1_pri_rt"
  }
}

# -------------- SG Parameters -------------- #

security_group_parameters = {
  default = {
    chat_app_dev_cluster_sg = {
      name     = "chat_app_dev_cluster_sg"
      vpc_name = "chat_app_dev_vpc1"
      tags = {
        Environment = "dev"
        VPC         = "chat_app_dev_vpc1"
      }
    }
    chat_app_dev_node_sg = {
      name     = "chat_app_dev_node_sg"
      vpc_name = "chat_app_dev_vpc1"
      tags = {
        Environment = "dev"
        VPC         = "chat_app_dev_vpc1"
      }
    }
    chat_app_dev_endpoint_sg = {
      name     = "chat_app_dev_endpoint_sg"
      vpc_name = "chat_app_dev_vpc1"
      tags = {
        Environment = "dev"
        VPC         = "chat_app_dev_vpc1"
      }
    }
  }
}

# -------------- SG Rules Parameters -------------- #

ipv4_ingress_rule = {
  default = {
    chat_app_dev_cluster_ingress1 = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_cluster_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_node_sg"
    }

    chat_app_dev_node_sg_ingress1 = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_node_sg" # Node SG
      from_port                  = 10250
      to_port                    = 10250
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_cluster_sg"
    }

    chat_app_dev_node_sg_ingress2 = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_node_sg" # Node SG
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_cluster_sg"
    }

    chat_app_dev_node_sg_ingress_nodeport = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_node_sg"
      from_port                  = 30000
      to_port                    = 32767
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_cluster_sg"
    }


    chat_app_dev_node_sg_ingress_self = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_node_sg"
      protocol                   = -1
      source_security_group_name = "chat_app_dev_node_sg"
    }

    chat_app_dev_endpoint_sg_ingress1 = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_endpoint_sg" # Node SG
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_node_sg"
    }
  }
}

ipv4_egress_rule = {
  default = {
    chat_app_dev_cluster_sg_egress = {
      vpc_name  = "chat_app_dev_vpc1"
      sg_name   = "chat_app_dev_cluster_sg"
      protocol  = -1
      cidr_ipv4 = "0.0.0.0/0"
    }

    chat_app_dev_node_sg_egress = {
      vpc_name  = "chat_app_dev_vpc1"
      sg_name   = "chat_app_dev_node_sg"
      protocol  = -1
      cidr_ipv4 = "0.0.0.0/0"
    }

    chat_app_dev_endpoint_sg_egress = {
      vpc_name  = "chat_app_dev_vpc1"
      sg_name   = "chat_app_dev_endpoint_sg"
      protocol  = -1
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}


# -------------- EIP Parameters -------------- #
eip_parameters = {
  default = {
    chat_app_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "dev"
      }
    }
  }
}

# -------------- NAT Parameters -------------- #

nat_gateway_parameters = {
  default = {
    chat_app_nat1 = {
      subnet_name                = "cad_vpc1_pub_sub1"
      eip_name_for_allocation_id = "chat_app_nat_eip"
    }
  }
}


# -------------- vpc_gateway_endpointParameters -------------- #

vpc_endpoint_parameters = {
  default = {
    chat_app_gateway = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"

      route_table_names = ["vpc1_pri_rt"]
    }

    chat_app_interface_ec2 = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "ec2"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }

    chat_app_interface_ec2messages = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "ec2messages"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_ssm = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "ssm"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_ssmmessages = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "ssmmessages"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_ecr_api = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "ecr.api"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_ecr_dkr = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "ecr.dkr"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_logs = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "logs"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_sts = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "sts"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
    chat_app_interface_eks = {
      region            = "ap-south-1"
      vpc_name          = "chat_app_dev_vpc1"
      service_name      = "eks"
      vpc_endpoint_type = "Interface"

      subnet_names         = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      security_group_names = ["chat_app_dev_endpoint_sg"]
      private_dns_enabled  = true
    }
  }
}

# -------------- EKS Parameters -------------- #


# -------------- Cluster Parameters -------------- #
eks_clusters = {
  default = {
    # -------------------------
    # Cluster A (dev frontend)
    # -------------------------
    a = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_dev_vpc1"
      subnet_name             = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      sg_name                 = ["chat_app_dev_cluster_sg"]
      endpoint_public_access  = true
      endpoint_private_access = true

      tags = {
        Environment = "dev"
        Cluster     = "a"
      }
    }

    # -------------------------
    # Cluster B (dev backend)
    # -------------------------
    # b = {
    #   cluster_version         = "1.34"
    #   vpc_name                = "chat_app_dev_vpc1"
    #   subnet_name             = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
    #   sg_name                 = ["chat_app_dev_cluster_sg"]
    #   endpoint_public_access  = false
    #   endpoint_private_access = true

    #   tags = {
    #     Environment = "dev"
    #     Cluster     = "b"
    #   }
    # }
  }

  # ===============================================================
  # QE Workspaces — Example
  # ===============================================================
  qe = {
    qe-a = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_dev_vpc1"
      subnet_name             = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      sg_name                 = ["chat_app_dev_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "qe"
        Cluster     = "QE-a"
      }
    }
  }

  # ===============================================================
  # PROD Workspaces — Example
  # ===============================================================
  prod = {
    prod-1 = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_dev_vpc1"
      subnet_name             = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      sg_name                 = ["chat_app_dev_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "prod"
        Cluster     = "prod-1"
      }
    }
  }
}


# -------------- Node Parameters -------------- #

eks_nodegroups = { # variable
  default = {      # workspace
    a = {          # clauster name ( node will attached to this cluster)
      a1 = {       # node name
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 2
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
        node_security_group_names = ["chat_app_dev_node_sg"]
        tags                      = { Team = "a" }
      }
      #   a2 = {
      #     min_size                  = 1
      #     max_size                  = 2
      #     desired_size              = 1
      #     instance_types            = "t3.small"
      #     subnet_name               = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      #     node_security_group_names = ["chat_app_dev_node_sg"]
      #     tags                      = { Team = "a" }
      #   }
      # }

      # b = {
      #   b1 = {
      #     k8s_version               = "1.34"
      #     arch                      = "arm64"
      #     min_size                  = 1
      #     max_size                  = 2
      #     desired_size              = 1
      #     instance_types            = "t4g.small"
      #     subnet_name               = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      #     node_security_group_names = ["chat_app_dev_node_sg"]
      #     tags                      = { Team = "b" }
      #   }
    }
  }
}