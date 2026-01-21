# ----------------------- NEW ----------------------- #

vpc_parameters = {
  default = {
    chat_app_dev_vpc1 = {
      cidr_block           = "10.10.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags                 = { Environment = "dev" }
    }
  }
}


subnet_parameters = {
  default = {
    cad_vpc1_pub_sub1 = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "chat_app_dev_vpc1"
      az_index                = 0
      map_public_ip_on_launch = true
      tags                    = { Environment = "dev" }
    }

    cad_vpc1_pub_sub2 = {
      cidr_block              = "10.10.2.0/24"
      vpc_name                = "chat_app_dev_vpc1"
      az_index                = 1
      map_public_ip_on_launch = true
      tags                    = { Environment = "dev" }
    }
  }
}


igw_parameters = {
  default = {
    cad_vpc1_igw = {
      vpc_name = "chat_app_dev_vpc1"
      tags     = { Environment = "dev" }
    }
  }
}


rt_parameters = {
  default = {
    vpc1_pub_rt = {
      vpc_name = "chat_app_dev_vpc1"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "igw"
        target_key  = "cad_vpc1_igw"
      }]
      tags = {
        Environment = "dev"
        VPC         = "chat_app_dev_vpc1"
      }
    }
  }
}

rt_association_parameters = {
  rt_assco_pub_sub1 = {
    subnet_name = "cad_vpc1_pub_sub1"
    rt_name     = "vpc1_pub_rt"
  }

  rt_assco_pub_sub2 = {
    subnet_name = "cad_vpc1_pub_sub2"
    rt_name     = "vpc1_pub_rt"
  }
}


security_group_parameters = {
  default = {
    chat_app_dev_cluster_sg = {
      name     = "chat_app_dev_cluster_sg"
      vpc_name = "chat_app_dev_vpc1"
      tags     = { Environment = "dev" }
    }

    chat_app_dev_node_sg = {
      name     = "chat_app_dev_node_sg"
      vpc_name = "chat_app_dev_vpc1"
      tags     = { Environment = "dev" }
    }
  }
}

ipv4_ingress_rule = {
  default = {
    cluster_from_nodes = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_cluster_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_node_sg"
    }

    node_from_cluster_https = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_node_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_cluster_sg"
    }

    node_from_cluster_kubelet = {
      vpc_name                   = "chat_app_dev_vpc1"
      sg_name                    = "chat_app_dev_node_sg"
      from_port                  = 10250
      to_port                    = 10250
      protocol                   = "TCP"
      source_security_group_name = "chat_app_dev_cluster_sg"
    }
  }
}
ipv4_egress_rule = {
  default = {
    all_out = {
      vpc_name  = "chat_app_dev_vpc1"
      sg_name   = "chat_app_dev_node_sg"
      protocol  = -1
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}


eks_clusters = {
  default = {
    a = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_dev_vpc1"
      subnet_name             = ["cad_vpc1_pub_sub1", "cad_vpc1_pub_sub2"]
      sg_name                 = ["chat_app_dev_cluster_sg"]
      endpoint_public_access  = true
      endpoint_private_access = false
      tags = {
        Environment = "dev"
        Cluster     = "a"
      }
    }
  }
}


eks_nodegroups = {
  default = {
    a = {
      a1 = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 2
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["cad_vpc1_pub_sub1", "cad_vpc1_pub_sub2"]
        node_security_group_names = ["chat_app_dev_node_sg"]
        tags                      = { Team = "a" }
      }
    }
  }
}
