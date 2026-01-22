# Complete Architecture Examples

This document provides production-ready Terraform configurations for common AWS architectures. Each example includes full `terraform.tfvars` configurations that you can download and customize.

## Table of Contents

1. [Basic Web Application](#1-basic-web-application)
2. [Three-Tier Web Application](#2-three-tier-web-application)
3. [Multi-Environment Setup](#3-multi-environment-setup)
4. [High-Availability EKS Cluster](#4-high-availability-eks-cluster)
5. [Microservices Platform](#5-microservices-platform)
6. [Data Processing Pipeline](#6-data-processing-pipeline)
7. [Hybrid Cloud Setup](#7-hybrid-cloud-setup)
8. [E-Commerce Platform](#8-e-commerce-platform)
9. [Download Instructions](#download-instructions)
10. [Customization Tips](#customization-tips)

---

## 1. Basic Web Application

**Use Case:** Simple web application with public and private subnets

**Architecture:**
```
Internet → IGW → Public Subnet (ALB) → Private Subnet (App) → Private Subnet (DB)
                                  ↓
                             NAT Gateway
```

**Components:**
- 1 VPC (10.0.0.0/16)
- 2 Public subnets (multi-AZ)
- 4 Private subnets (2 app + 2 db, multi-AZ)
- 1 Internet Gateway
- 1 NAT Gateway
- 3 Security Groups (ALB, App, DB)
- 1 S3 VPC Endpoint (cost optimization)

**Monthly Cost:** ~$32.40 (1 NAT Gateway)

### Configuration

```hcl
# =============================================================================
# VPC Configuration
# =============================================================================
vpc_parameters = {
  default = {
    web_app_vpc = {
      cidr_block           = "10.0.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags = {
        Environment = "dev"
        Project     = "web-app"
        ManagedBy   = "terraform"
      }
    }
  }
}

# =============================================================================
# Subnet Configuration
# =============================================================================
subnet_parameters = {
  default = {
    # Public Subnets (Load Balancer Tier)
    public_subnet_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "web_app_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = {
        Name = "public-az1"
        Type = "public"
        Tier = "load-balancer"
      }
    }

    public_subnet_az2 = {
      cidr_block              = "10.0.2.0/24"
      vpc_name                = "web_app_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = {
        Name = "public-az2"
        Type = "public"
        Tier = "load-balancer"
      }
    }

    # Private App Subnets
    app_subnet_az1 = {
      cidr_block              = "10.0.10.0/24"
      vpc_name                = "web_app_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = {
        Name = "app-az1"
        Type = "private"
        Tier = "application"
      }
    }

    app_subnet_az2 = {
      cidr_block              = "10.0.11.0/24"
      vpc_name                = "web_app_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = {
        Name = "app-az2"
        Type = "private"
        Tier = "application"
      }
    }

    # Private Database Subnets
    db_subnet_az1 = {
      cidr_block              = "10.0.20.0/24"
      vpc_name                = "web_app_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = {
        Name = "db-az1"
        Type = "private"
        Tier = "database"
      }
    }

    db_subnet_az2 = {
      cidr_block              = "10.0.21.0/24"
      vpc_name                = "web_app_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = {
        Name = "db-az2"
        Type = "private"
        Tier = "database"
      }
    }
  }
}

# =============================================================================
# Internet Gateway
# =============================================================================
igw_parameters = {
  default = {
    web_app_igw = {
      vpc_name = "web_app_vpc"
      tags = {
        Name    = "web-app-igw"
        Purpose = "internet-access"
      }
    }
  }
}

# =============================================================================
# Elastic IP for NAT Gateway
# =============================================================================
eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags = {
        Name    = "web-app-nat-eip"
        Purpose = "nat-gateway"
      }
    }
  }
}

# =============================================================================
# NAT Gateway
# =============================================================================
nat_gateway_parameters = {
  default = {
    web_app_nat = {
      subnet_name                = "public_subnet_az1"
      eip_name_for_allocation_id = "nat_eip"
      connectivity_type          = "public"
      tags = {
        Name = "web-app-nat"
      }
    }
  }
}

# =============================================================================
# Route Tables
# =============================================================================
rt_parameters = {
  default = {
    # Public Route Table
    public_rt = {
      vpc_name = "web_app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "web_app_igw"
        }
      ]
      tags = {
        Name = "public-rt"
        Type = "public"
      }
    }

    # Private Route Table (App tier)
    private_app_rt = {
      vpc_name = "web_app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "web_app_nat"
        }
      ]
      tags = {
        Name = "private-app-rt"
        Type = "private"
        Tier = "application"
      }
    }

    # Private Route Table (DB tier - isolated)
    private_db_rt = {
      vpc_name = "web_app_vpc"
      routes   = []
      tags = {
        Name     = "private-db-rt"
        Type     = "private"
        Tier     = "database"
        Isolated = "true"
      }
    }
  }
}

# =============================================================================
# Route Table Associations
# =============================================================================
rt_association_parameters = {
  # Public subnets
  public_az1_assoc = {
    subnet_name = "public_subnet_az1"
    rt_name     = "public_rt"
  }

  public_az2_assoc = {
    subnet_name = "public_subnet_az2"
    rt_name     = "public_rt"
  }

  # App subnets
  app_az1_assoc = {
    subnet_name = "app_subnet_az1"
    rt_name     = "private_app_rt"
  }

  app_az2_assoc = {
    subnet_name = "app_subnet_az2"
    rt_name     = "private_app_rt"
  }

  # Database subnets
  db_az1_assoc = {
    subnet_name = "db_subnet_az1"
    rt_name     = "private_db_rt"
  }

  db_az2_assoc = {
    subnet_name = "db_subnet_az2"
    rt_name     = "private_db_rt"
  }
}

# =============================================================================
# Security Groups
# =============================================================================
security_group_parameters = {
  default = {
    alb_sg = {
      name     = "web-app-alb-sg"
      vpc_name = "web_app_vpc"
      tags = {
        Name = "alb-sg"
        Tier = "load-balancer"
      }
    }

    app_sg = {
      name     = "web-app-app-sg"
      vpc_name = "web_app_vpc"
      tags = {
        Name = "app-sg"
        Tier = "application"
      }
    }

    db_sg = {
      name     = "web-app-db-sg"
      vpc_name = "web_app_vpc"
      tags = {
        Name = "db-sg"
        Tier = "database"
      }
    }
  }
}

# =============================================================================
# Security Group Rules - Ingress
# =============================================================================
ipv4_ingress_rule = {
  default = {
    # ALB: Accept HTTPS from internet
    alb_https = {
      vpc_name  = "web_app_vpc"
      sg_name   = "alb_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }

    alb_http = {
      vpc_name  = "web_app_vpc"
      sg_name   = "alb_sg"
      from_port = 80
      to_port   = 80
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }

    # App: Accept from ALB only
    app_from_alb = {
      vpc_name                   = "web_app_vpc"
      sg_name                    = "app_sg"
      from_port                  = 8080
      to_port                    = 8080
      protocol                   = "TCP"
      source_security_group_name = "alb_sg"
    }

    # DB: Accept from App only
    db_from_app = {
      vpc_name                   = "web_app_vpc"
      sg_name                    = "db_sg"
      from_port                  = 5432
      to_port                    = 5432
      protocol                   = "TCP"
      source_security_group_name = "app_sg"
    }
  }
}

# =============================================================================
# Security Group Rules - Egress
# =============================================================================
ipv4_egress_rule = {
  default = {
    alb_egress = {
      vpc_name  = "web_app_vpc"
      sg_name   = "alb_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }

    app_egress = {
      vpc_name  = "web_app_vpc"
      sg_name   = "app_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }

    db_egress = {
      vpc_name  = "web_app_vpc"
      sg_name   = "db_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}

# =============================================================================
# VPC Endpoints (Cost Optimization)
# =============================================================================
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region             = "ap-south-1"
      vpc_name           = "web_app_vpc"
      service_name       = "s3"
      vpc_endpoint_type  = "Gateway"
      route_table_names  = ["private_app_rt"]
      tags = {
        Name    = "s3-endpoint"
        Purpose = "s3-access"
      }
    }
  }
}
```

### Deployment

```bash
# Initialize
terraform init

# Create workspace (optional, uses 'default' by default)
terraform workspace new dev

# Plan
terraform plan

# Apply
terraform apply

# Verify
terraform output
```

---

## 2. Three-Tier Web Application

**Use Case:** Production web application with separate web, app, and database tiers

**Architecture:**
```
Internet → IGW → ALB (Public) → Web Tier (Private) → App Tier (Private) → DB Tier (Isolated)
                                        ↓
                                  NAT Gateway (Multi-AZ)
```

**Components:**
- 1 VPC (10.0.0.0/16)
- 2 Public subnets (ALB)
- 6 Private subnets (2 per tier, multi-AZ)
- 1 Internet Gateway
- 2 NAT Gateways (high availability)
- 4 Security Groups
- S3 VPC Endpoint

**Monthly Cost:** ~$64.80 (2 NAT Gateways)

### Configuration

```hcl
# =============================================================================
# VPC
# =============================================================================
vpc_parameters = {
  default = {
    app_vpc = {
      cidr_block           = "10.0.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags = {
        Environment  = "production"
        Architecture = "three-tier"
        ManagedBy    = "terraform"
      }
    }
  }
}

# =============================================================================
# Subnets
# =============================================================================
subnet_parameters = {
  default = {
    # Public Subnets (Load Balancer)
    public_lb_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Tier = "load-balancer", AZ = "az1" }
    }

    public_lb_az2 = {
      cidr_block              = "10.0.2.0/24"
      vpc_name                = "app_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Tier = "load-balancer", AZ = "az2" }
    }

    # Web Tier
    web_az1 = {
      cidr_block = "10.0.10.0/24"
      vpc_name   = "app_vpc"
      az_index   = 0
      tags = { Tier = "web", AZ = "az1" }
    }

    web_az2 = {
      cidr_block = "10.0.11.0/24"
      vpc_name   = "app_vpc"
      az_index   = 1
      tags = { Tier = "web", AZ = "az2" }
    }

    # Application Tier
    app_az1 = {
      cidr_block = "10.0.20.0/24"
      vpc_name   = "app_vpc"
      az_index   = 0
      tags = { Tier = "application", AZ = "az1" }
    }

    app_az2 = {
      cidr_block = "10.0.21.0/24"
      vpc_name   = "app_vpc"
      az_index   = 1
      tags = { Tier = "application", AZ = "az2" }
    }

    # Database Tier
    db_az1 = {
      cidr_block = "10.0.30.0/24"
      vpc_name   = "app_vpc"
      az_index   = 0
      tags = { Tier = "database", AZ = "az1" }
    }

    db_az2 = {
      cidr_block = "10.0.31.0/24"
      vpc_name   = "app_vpc"
      az_index   = 1
      tags = { Tier = "database", AZ = "az2" }
    }
  }
}

# =============================================================================
# Internet Gateway
# =============================================================================
igw_parameters = {
  default = {
    app_igw = {
      vpc_name = "app_vpc"
      tags = { Name = "app-igw" }
    }
  }
}

# =============================================================================
# Elastic IPs (Multi-AZ NAT)
# =============================================================================
eip_parameters = {
  default = {
    nat_eip_az1 = {
      domain = "vpc"
      tags = { Name = "nat-eip-az1", AZ = "az1" }
    }

    nat_eip_az2 = {
      domain = "vpc"
      tags = { Name = "nat-eip-az2", AZ = "az2" }
    }
  }
}

# =============================================================================
# NAT Gateways (Multi-AZ for HA)
# =============================================================================
nat_gateway_parameters = {
  default = {
    nat_az1 = {
      subnet_name                = "public_lb_az1"
      eip_name_for_allocation_id = "nat_eip_az1"
      connectivity_type          = "public"
      tags = { Name = "nat-az1", AZ = "az1" }
    }

    nat_az2 = {
      subnet_name                = "public_lb_az2"
      eip_name_for_allocation_id = "nat_eip_az2"
      connectivity_type          = "public"
      tags = { Name = "nat-az2", AZ = "az2" }
    }
  }
}

# =============================================================================
# Route Tables
# =============================================================================
rt_parameters = {
  default = {
    # Public Route Table
    public_rt = {
      vpc_name = "app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "app_igw"
        }
      ]
      tags = { Name = "public-rt" }
    }

    # Private Route Tables (per AZ)
    private_rt_az1 = {
      vpc_name = "app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az1"
        }
      ]
      tags = { Name = "private-rt-az1", AZ = "az1" }
    }

    private_rt_az2 = {
      vpc_name = "app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az2"
        }
      ]
      tags = { Name = "private-rt-az2", AZ = "az2" }
    }

    # Database Route Table (Isolated)
    db_rt = {
      vpc_name = "app_vpc"
      routes   = []
      tags = { Name = "db-rt", Isolated = "true" }
    }
  }
}

# =============================================================================
# Route Table Associations
# =============================================================================
rt_association_parameters = {
  # Public
  public_lb_az1_assoc = { subnet_name = "public_lb_az1", rt_name = "public_rt" }
  public_lb_az2_assoc = { subnet_name = "public_lb_az2", rt_name = "public_rt" }

  # Web Tier
  web_az1_assoc = { subnet_name = "web_az1", rt_name = "private_rt_az1" }
  web_az2_assoc = { subnet_name = "web_az2", rt_name = "private_rt_az2" }

  # App Tier
  app_az1_assoc = { subnet_name = "app_az1", rt_name = "private_rt_az1" }
  app_az2_assoc = { subnet_name = "app_az2", rt_name = "private_rt_az2" }

  # DB Tier
  db_az1_assoc = { subnet_name = "db_az1", rt_name = "db_rt" }
  db_az2_assoc = { subnet_name = "db_az2", rt_name = "db_rt" }
}

# =============================================================================
# Security Groups
# =============================================================================
security_group_parameters = {
  default = {
    lb_sg  = { name = "lb-sg", vpc_name = "app_vpc", tags = { Tier = "load-balancer" } }
    web_sg = { name = "web-sg", vpc_name = "app_vpc", tags = { Tier = "web" } }
    app_sg = { name = "app-sg", vpc_name = "app_vpc", tags = { Tier = "application" } }
    db_sg  = { name = "db-sg", vpc_name = "app_vpc", tags = { Tier = "database" } }
  }
}

# =============================================================================
# Security Group Rules - Ingress
# =============================================================================
ipv4_ingress_rule = {
  default = {
    # LB → Internet
    lb_https = {
      vpc_name  = "app_vpc"
      sg_name   = "lb_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }

    # Web → LB
    web_from_lb = {
      vpc_name                   = "app_vpc"
      sg_name                    = "web_sg"
      from_port                  = 8080
      to_port                    = 8080
      protocol                   = "TCP"
      source_security_group_name = "lb_sg"
    }

    # App → Web
    app_from_web = {
      vpc_name                   = "app_vpc"
      sg_name                    = "app_sg"
      from_port                  = 8080
      to_port                    = 8080
      protocol                   = "TCP"
      source_security_group_name = "web_sg"
    }

    # DB → App
    db_from_app = {
      vpc_name                   = "app_vpc"
      sg_name                    = "db_sg"
      from_port                  = 5432
      to_port                    = 5432
      protocol                   = "TCP"
      source_security_group_name = "app_sg"
    }
  }
}

# =============================================================================
# Security Group Rules - Egress
# =============================================================================
ipv4_egress_rule = {
  default = {
    lb_egress  = { vpc_name = "app_vpc", sg_name = "lb_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    web_egress = { vpc_name = "app_vpc", sg_name = "web_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    app_egress = { vpc_name = "app_vpc", sg_name = "app_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    db_egress  = { vpc_name = "app_vpc", sg_name = "db_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
  }
}

# =============================================================================
# VPC Endpoints
# =============================================================================
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region             = "ap-south-1"
      vpc_name           = "app_vpc"
      service_name       = "s3"
      vpc_endpoint_type  = "Gateway"
      route_table_names  = ["private_rt_az1", "private_rt_az2"]
      tags = { Name = "s3-endpoint" }
    }
  }
}
```

---

## 3. Multi-Environment Setup

**Use Case:** Development, QE, and Production environments with workspace isolation

**Key Features:**
- Separate VPCs per environment
- Different CIDR ranges (10.10.x, 10.20.x, 10.30.x)
- Cost-optimized dev/QE (fewer NAT Gateways)
- Production HA (multi-AZ NAT)

**Monthly Costs:**
- Dev: ~$32.40 (1 NAT)
- QE: ~$64.80 (2 NAT)
- Prod: ~$97.20 (3 NAT)

### Configuration

```hcl
# =============================================================================
# VPC (Per Workspace)
# =============================================================================
vpc_parameters = {
  default = {
    dev_vpc = {
      cidr_block = "10.10.0.0/16"
      tags = { Environment = "dev" }
    }
  }

  qe = {
    qe_vpc = {
      cidr_block = "10.20.0.0/16"
      tags = { Environment = "qe" }
    }
  }

  prod = {
    prod_vpc = {
      cidr_block = "10.30.0.0/16"
      tags = { Environment = "prod" }
    }
  }
}

# =============================================================================
# Subnets
# =============================================================================
subnet_parameters = {
  # Development (Single AZ for cost)
  default = {
    dev_public = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public" }
    }

    dev_private = {
      cidr_block = "10.10.10.0/24"
      vpc_name   = "dev_vpc"
      az_index   = 0
      tags = { Type = "private" }
    }
  }

  # QE (Dual AZ)
  qe = {
    qe_public_az1 = {
      cidr_block              = "10.20.1.0/24"
      vpc_name                = "qe_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az1" }
    }

    qe_public_az2 = {
      cidr_block              = "10.20.2.0/24"
      vpc_name                = "qe_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az2" }
    }

    qe_private_az1 = {
      cidr_block = "10.20.10.0/24"
      vpc_name   = "qe_vpc"
      az_index   = 0
      tags = { Type = "private", AZ = "az1" }
    }

    qe_private_az2 = {
      cidr_block = "10.20.11.0/24"
      vpc_name   = "qe_vpc"
      az_index   = 1
      tags = { Type = "private", AZ = "az2" }
    }
  }

  # Production (Triple AZ)
  prod = {
    prod_public_az1 = {
      cidr_block              = "10.30.1.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az1" }
    }

    prod_public_az2 = {
      cidr_block              = "10.30.2.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az2" }
    }

    prod_public_az3 = {
      cidr_block              = "10.30.3.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 2
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az3" }
    }

    prod_private_az1 = {
      cidr_block = "10.30.10.0/24"
      vpc_name   = "prod_vpc"
      az_index   = 0
      tags = { Type = "private", AZ = "az1" }
    }

    prod_private_az2 = {
      cidr_block = "10.30.11.0/24"
      vpc_name   = "prod_vpc"
      az_index   = 1
      tags = { Type = "private", AZ = "az2" }
    }

    prod_private_az3 = {
      cidr_block = "10.30.12.0/24"
      vpc_name   = "prod_vpc"
      az_index   = 2
      tags = { Type = "private", AZ = "az3" }
    }
  }
}

# =============================================================================
# Internet Gateways
# =============================================================================
igw_parameters = {
  default = {
    dev_igw = { vpc_name = "dev_vpc", tags = { Name = "dev-igw" } }
  }

  qe = {
    qe_igw = { vpc_name = "qe_vpc", tags = { Name = "qe-igw" } }
  }

  prod = {
    prod_igw = { vpc_name = "prod_vpc", tags = { Name = "prod-igw" } }
  }
}

# =============================================================================
# Elastic IPs
# =============================================================================
eip_parameters = {
  # Dev: Single NAT
  default = {
    dev_nat_eip = {
      domain = "vpc"
      tags = { Name = "dev-nat-eip" }
    }
  }

  # QE: Dual NAT
  qe = {
    qe_nat_eip_az1 = { domain = "vpc", tags = { Name = "qe-nat-eip-az1" } }
    qe_nat_eip_az2 = { domain = "vpc", tags = { Name = "qe-nat-eip-az2" } }
  }

  # Prod: Triple NAT
  prod = {
    prod_nat_eip_az1 = { domain = "vpc", tags = { Name = "prod-nat-eip-az1" } }
    prod_nat_eip_az2 = { domain = "vpc", tags = { Name = "prod-nat-eip-az2" } }
    prod_nat_eip_az3 = { domain = "vpc", tags = { Name = "prod-nat-eip-az3" } }
  }
}

# =============================================================================
# NAT Gateways
# =============================================================================
nat_gateway_parameters = {
  default = {
    dev_nat = {
      subnet_name                = "dev_public"
      eip_name_for_allocation_id = "dev_nat_eip"
      tags = { Name = "dev-nat" }
    }
  }

  qe = {
    qe_nat_az1 = {
      subnet_name                = "qe_public_az1"
      eip_name_for_allocation_id = "qe_nat_eip_az1"
      tags = { Name = "qe-nat-az1" }
    }

    qe_nat_az2 = {
      subnet_name                = "qe_public_az2"
      eip_name_for_allocation_id = "qe_nat_eip_az2"
      tags = { Name = "qe-nat-az2" }
    }
  }

  prod = {
    prod_nat_az1 = {
      subnet_name                = "prod_public_az1"
      eip_name_for_allocation_id = "prod_nat_eip_az1"
      tags = { Name = "prod-nat-az1" }
    }

    prod_nat_az2 = {
      subnet_name                = "prod_public_az2"
      eip_name_for_allocation_id = "prod_nat_eip_az2"
      tags = { Name = "prod-nat-az2" }
    }

    prod_nat_az3 = {
      subnet_name                = "prod_public_az3"
      eip_name_for_allocation_id = "prod_nat_eip_az3"
      tags = { Name = "prod-nat-az3" }
    }
  }
}

# =============================================================================
# Route Tables
# =============================================================================
rt_parameters = {
  default = {
    dev_public_rt = {
      vpc_name = "dev_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "igw", target_key = "dev_igw" }]
      tags = { Type = "public" }
    }

    dev_private_rt = {
      vpc_name = "dev_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "dev_nat" }]
      tags = { Type = "private" }
    }
  }

  qe = {
    qe_public_rt = {
      vpc_name = "qe_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "igw", target_key = "qe_igw" }]
      tags = { Type = "public" }
    }

    qe_private_rt_az1 = {
      vpc_name = "qe_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "qe_nat_az1" }]
      tags = { Type = "private", AZ = "az1" }
    }

    qe_private_rt_az2 = {
      vpc_name = "qe_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "qe_nat_az2" }]
      tags = { Type = "private", AZ = "az2" }
    }
  }

  prod = {
    prod_public_rt = {
      vpc_name = "prod_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "igw", target_key = "prod_igw" }]
      tags = { Type = "public" }
    }

    prod_private_rt_az1 = {
      vpc_name = "prod_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "prod_nat_az1" }]
      tags = { Type = "private", AZ = "az1" }
    }

    prod_private_rt_az2 = {
      vpc_name = "prod_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "prod_nat_az2" }]
      tags = { Type = "private", AZ = "az2" }
    }

    prod_private_rt_az3 = {
      vpc_name = "prod_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "prod_nat_az3" }]
      tags = { Type = "private", AZ = "az3" }
    }
  }
}

# =============================================================================
# Route Table Associations
# =============================================================================
rt_association_parameters = {
  # Dev
  dev_public_assoc  = { subnet_name = "dev_public", rt_name = "dev_public_rt" }
  dev_private_assoc = { subnet_name = "dev_private", rt_name = "dev_private_rt" }

  # QE
  qe_public_az1_assoc  = { subnet_name = "qe_public_az1", rt_name = "qe_public_rt" }
  qe_public_az2_assoc  = { subnet_name = "qe_public_az2", rt_name = "qe_public_rt" }
  qe_private_az1_assoc = { subnet_name = "qe_private_az1", rt_name = "qe_private_rt_az1" }
  qe_private_az2_assoc = { subnet_name = "qe_private_az2", rt_name = "qe_private_rt_az2" }

  # Prod
  prod_public_az1_assoc  = { subnet_name = "prod_public_az1", rt_name = "prod_public_rt" }
  prod_public_az2_assoc  = { subnet_name = "prod_public_az2", rt_name = "prod_public_rt" }
  prod_public_az3_assoc  = { subnet_name = "prod_public_az3", rt_name = "prod_public_rt" }
  prod_private_az1_assoc = { subnet_name = "prod_private_az1", rt_name = "prod_private_rt_az1" }
  prod_private_az2_assoc = { subnet_name = "prod_private_az2", rt_name = "prod_private_rt_az2" }
  prod_private_az3_assoc = { subnet_name = "prod_private_az3", rt_name = "prod_private_rt_az3" }
}
```

### Deployment by Environment

```bash
# Development
terraform workspace select default
terraform apply

# QE
terraform workspace new qe
terraform apply

# Production
terraform workspace new prod
terraform apply
```

---

## 4. High-Availability EKS Cluster

**Use Case:** Production EKS cluster with multi-AZ deployment

**Architecture:**
```
Internet → IGW → Public Subnets (NAT) → Private Subnets (EKS Nodes)
                                               ↓
                                         EKS Cluster
```

**Components:**
- 1 VPC (10.0.0.0/16)
- 3 Public subnets (NAT Gateways)
- 3 Private subnets (EKS nodes, multi-AZ)
- 3 NAT Gateways (one per AZ)
- 2 Security Groups (cluster + nodes)
- 2 Node Groups (general + memory-optimized)
- VPC Endpoints (ECR, S3)

**Monthly Cost:** ~$711.80 (infrastructure + nodes)

### Configuration

```hcl
# =============================================================================
# VPC
# =============================================================================
vpc_parameters = {
  default = {
    eks_vpc = {
      cidr_block           = "10.0.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = true
      tags = {
        Environment                      = "production"
        "kubernetes.io/cluster/prod-cluster" = "shared"
      }
    }
  }
}

# =============================================================================
# Subnets
# =============================================================================
subnet_parameters = {
  default = {
    # Public Subnets (NAT Gateways)
    public_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "eks_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = {
        Name                     = "public-az1"
        "kubernetes.io/role/elb" = "1"
      }
    }

    public_az2 = {
      cidr_block              = "10.0.2.0/24"
      vpc_name                = "eks_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = {
        Name                     = "public-az2"
        "kubernetes.io/role/elb" = "1"
      }
    }

    public_az3 = {
      cidr_block              = "10.0.3.0/24"
      vpc_name                = "eks_vpc"
      az_index                = 2
      map_public_ip_on_launch = true
      tags = {
        Name                     = "public-az3"
        "kubernetes.io/role/elb" = "1"
      }
    }

    # Private Subnets (EKS Nodes)
    private_az1 = {
      cidr_block = "10.0.10.0/24"
      vpc_name   = "eks_vpc"
      az_index   = 0
      tags = {
        Name                              = "private-az1"
        "kubernetes.io/role/internal-elb" = "1"
      }
    }

    private_az2 = {
      cidr_block = "10.0.11.0/24"
      vpc_name   = "eks_vpc"
      az_index   = 1
      tags = {
        Name                              = "private-az2"
        "kubernetes.io/role/internal-elb" = "1"
      }
    }

    private_az3 = {
      cidr_block = "10.0.12.0/24"
      vpc_name   = "eks_vpc"
      az_index   = 2
      tags = {
        Name                              = "private-az3"
        "kubernetes.io/role/internal-elb" = "1"
      }
    }
  }
}

# =============================================================================
# Internet Gateway
# =============================================================================
igw_parameters = {
  default = {
    eks_igw = {
      vpc_name = "eks_vpc"
      tags = { Name = "eks-igw" }
    }
  }
}

# =============================================================================
# Elastic IPs
# =============================================================================
eip_parameters = {
  default = {
    nat_eip_az1 = { domain = "vpc", tags = { Name = "eks-nat-eip-az1" } }
    nat_eip_az2 = { domain = "vpc", tags = { Name = "eks-nat-eip-az2" } }
    nat_eip_az3 = { domain = "vpc", tags = { Name = "eks-nat-eip-az3" } }
  }
}

# =============================================================================
# NAT Gateways
# =============================================================================
nat_gateway_parameters = {
  default = {
    nat_az1 = {
      subnet_name                = "public_az1"
      eip_name_for_allocation_id = "nat_eip_az1"
      tags = { Name = "eks-nat-az1" }
    }

    nat_az2 = {
      subnet_name                = "public_az2"
      eip_name_for_allocation_id = "nat_eip_az2"
      tags = { Name = "eks-nat-az2" }
    }

    nat_az3 = {
      subnet_name                = "public_az3"
      eip_name_for_allocation_id = "nat_eip_az3"
      tags = { Name = "eks-nat-az3" }
    }
  }
}

# =============================================================================
# Route Tables
# =============================================================================
rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "eks_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "igw", target_key = "eks_igw" }]
      tags = { Name = "eks-public-rt" }
    }

    private_rt_az1 = {
      vpc_name = "eks_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "nat_az1" }]
      tags = { Name = "eks-private-rt-az1" }
    }

    private_rt_az2 = {
      vpc_name = "eks_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "nat_az2" }]
      tags = { Name = "eks-private-rt-az2" }
    }

    private_rt_az3 = {
      vpc_name = "eks_vpc"
      routes = [{ cidr_block = "0.0.0.0/0", target_type = "nat", target_key = "nat_az3" }]
      tags = { Name = "eks-private-rt-az3" }
    }
  }
}

# =============================================================================
# Route Table Associations
# =============================================================================
rt_association_parameters = {
  public_az1_assoc  = { subnet_name = "public_az1", rt_name = "public_rt" }
  public_az2_assoc  = { subnet_name = "public_az2", rt_name = "public_rt" }
  public_az3_assoc  = { subnet_name = "public_az3", rt_name = "public_rt" }
  private_az1_assoc = { subnet_name = "private_az1", rt_name = "private_rt_az1" }
  private_az2_assoc = { subnet_name = "private_az2", rt_name = "private_rt_az2" }
  private_az3_assoc = { subnet_name = "private_az3", rt_name = "private_rt_az3" }
}

# =============================================================================
# Security Groups
# =============================================================================
security_group_parameters = {
  default = {
    eks_cluster_sg = {
      name     = "eks-cluster-sg"
      vpc_name = "eks_vpc"
      tags = { Name = "eks-cluster-sg", Purpose = "EKS-Control-Plane" }
    }

    eks_node_sg = {
      name     = "eks-node-sg"
      vpc_name = "eks_vpc"
      tags = { Name = "eks-node-sg", Purpose = "EKS-Worker-Nodes" }
    }
  }
}

# =============================================================================
# Security Group Rules - Ingress
# =============================================================================
ipv4_ingress_rule = {
  default = {
    cluster_from_nodes = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_cluster_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "eks_node_sg"
    }

    node_kubelet = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      from_port                  = 10250
      to_port                    = 10250
      protocol                   = "TCP"
      source_security_group_name = "eks_cluster_sg"
    }

    node_https = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "eks_cluster_sg"
    }

    node_self = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      protocol                   = "-1"
      source_security_group_name = "eks_node_sg"
    }
  }
}

# =============================================================================
# Security Group Rules - Egress
# =============================================================================
ipv4_egress_rule = {
  default = {
    cluster_egress = {
      vpc_name  = "eks_vpc"
      sg_name   = "eks_cluster_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }

    node_egress = {
      vpc_name  = "eks_vpc"
      sg_name   = "eks_node_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}

# =============================================================================
# EKS Cluster
# =============================================================================
eks_clusters = {
  default = {
    prod_cluster = {
      cluster_version         = "1.34"
      vpc_name                = "eks_vpc"
      subnet_name             = ["private_az1", "private_az2", "private_az3"]
      sg_name                 = ["eks_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "production"
        Cluster     = "prod-cluster"
      }
    }
  }
}

# =============================================================================
# EKS Node Groups
# =============================================================================
eks_nodegroups = {
  default = {
    prod_cluster = {
      general = {
        k8s_version                = "1.34"
        arch                       = "arm64"
        min_size                   = 3
        max_size                   = 10
        desired_size               = 5
        instance_types             = "t4g.large"
        subnet_name                = ["private_az1", "private_az2", "private_az3"]
        node_security_group_names  = ["eks_node_sg"]
        tags = { Workload = "general" }
      }

      memory = {
        k8s_version                = "1.34"
        arch                       = "x86_64"
        min_size                   = 2
        max_size                   = 6
        desired_size               = 3
        instance_types             = "r5.large"
        subnet_name                = ["private_az1", "private_az2", "private_az3"]
        node_security_group_names  = ["eks_node_sg"]
        tags = { Workload = "memory-intensive" }
      }
    }
  }
}

# =============================================================================
# VPC Endpoints (Cost Optimization)
# =============================================================================
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region             = "ap-south-1"
      vpc_name           = "eks_vpc"
      service_name       = "s3"
      vpc_endpoint_type  = "Gateway"
      route_table_names  = ["private_rt_az1", "private_rt_az2", "private_rt_az3"]
      tags = { Name = "s3-endpoint" }
    }

    ecr_api_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "eks_vpc"
      service_name         = "ecr.api"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["private_az1", "private_az2", "private_az3"]
      security_group_names = ["eks_node_sg"]
      private_dns_enabled  = true
      tags = { Name = "ecr-api-endpoint" }
    }

    ecr_dkr_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "eks_vpc"
      service_name         = "ecr.dkr"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["private_az1", "private_az2", "private_az3"]
      security_group_names = ["eks_node_sg"]
      private_dns_enabled  = true
      tags = { Name = "ecr-dkr-endpoint" }
    }
  }
}
```

---

## 5. Microservices Platform

**Use Case:** Microservices architecture with service mesh and API Gateway

**Components:**
- Service-oriented subnet tiers
- VPC Endpoints for AWS services (SQS, SNS, S3)
- API Gateway integration ready

### Configuration Highlights

```hcl
# Multiple private subnet tiers
subnet_parameters = {
  default = {
    # API Gateway tier
    api_subnet_az1 = {
      cidr_block = "10.0.1.0/24"
      vpc_name   = "microservices_vpc"
      az_index   = 0
      tags = { Tier = "api-gateway" }
    }

    # Service tier
    service_subnet_az1 = {
      cidr_block = "10.0.10.0/24"
      vpc_name   = "microservices_vpc"
      az_index   = 0
      tags = { Tier = "services" }
    }

    # Data tier
    data_subnet_az1 = {
      cidr_block = "10.0.20.0/24"
      vpc_name   = "microservices_vpc"
      az_index   = 0
      tags = { Tier = "data" }
    }
  }
}

# VPC Endpoints for AWS services
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region             = "ap-south-1"
      vpc_name           = "microservices_vpc"
      service_name       = "s3"
      vpc_endpoint_type  = "Gateway"
      route_table_names  = ["private_rt"]
      tags = { Purpose = "object-storage" }
    }

    sqs_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "microservices_vpc"
      service_name         = "sqs"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["service_subnet_az1"]
      security_group_names = ["service_sg"]
      private_dns_enabled  = true
      tags = { Purpose = "message-queue" }
    }

    sns_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "microservices_vpc"
      service_name         = "sns"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["service_subnet_az1"]
      security_group_names = ["service_sg"]
      private_dns_enabled  = true
      tags = { Purpose = "notifications" }
    }
  }
}
```

---

## 6. Data Processing Pipeline

**Use Case:** Big data processing with EMR/Glue

**Key Features:**
- Isolated data subnets
- S3 Gateway Endpoint (FREE - no NAT costs)
- Glue Interface Endpoint for ETL
- Larger subnets for scaling

### Configuration Highlights

```hcl
subnet_parameters = {
  default = {
    # Processing tier (EMR/Glue)
    processing_az1 = {
      cidr_block = "10.0.10.0/23"  # Larger subnet (/23 = 512 IPs)
      vpc_name   = "data_vpc"
      az_index   = 0
      tags = { Tier = "processing", Purpose = "emr-cluster" }
    }

    # Storage tier (data nodes)
    storage_az1 = {
      cidr_block = "10.0.20.0/24"
      vpc_name   = "data_vpc"
      az_index   = 0
      tags = { Tier = "storage", Purpose = "data-nodes" }
    }
  }
}

# S3 Gateway Endpoint (FREE - no NAT charges for S3 traffic)
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region             = "ap-south-1"
      vpc_name           = "data_vpc"
      service_name       = "s3"
      vpc_endpoint_type  = "Gateway"
      route_table_names  = ["processing_rt", "storage_rt"]
      tags = { Purpose = "data-lake-access" }
    }

    glue_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "data_vpc"
      service_name         = "glue"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["processing_az1"]
      security_group_names = ["glue_sg"]
      private_dns_enabled  = true
      tags = { Purpose = "etl-jobs" }
    }
  }
}
```

---

## 7. Hybrid Cloud Setup

**Use Case:** On-premises integration via VPN/Direct Connect

**Components:**
- VPC with routes to on-premises network
- VPN Gateway integration
- Separate CIDR ranges to avoid conflicts

### Configuration Highlights

```hcl
# Route table with VPN Gateway route
rt_parameters = {
  default = {
    hybrid_rt = {
      vpc_name = "hybrid_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_gateway"
        },
        {
          cidr_block  = "192.168.0.0/16"  # On-premises network
          target_type = "vgw"
          target_key  = "vgw-abc123def"   # VPN Gateway ID
        }
      ]
      tags = { Type = "hybrid", Purpose = "vpn-integration" }
    }
  }
}

# VPC with non-overlapping CIDR
vpc_parameters = {
  default = {
    hybrid_vpc = {
      cidr_block = "10.0.0.0/16"  # Does NOT overlap with on-prem 192.168.0.0/16
      tags = { Type = "hybrid-cloud" }
    }
  }
}
```

---

## 8. E-Commerce Platform

**Use Case:** Complete e-commerce infrastructure with all tiers

**Architecture:**
```
Internet → CloudFront → ALB → Web → API → (DB + Cache + Queue)
                                ↓
                           NAT Gateway
```

**Components:**
- Complete multi-tier setup
- Cache tier (ElastiCache)
- Message queues (SQS via VPC Endpoint)
- Database tier (isolated)

**Monthly Cost:** ~$72.10 (infrastructure only)

### Configuration

```hcl
# =============================================================================
# VPC
# =============================================================================
vpc_parameters = {
  default = {
    ecommerce_vpc = {
      cidr_block = "10.0.0.0/16"
      tags = {
        Environment = "production"
        Project     = "ecommerce"
        ManagedBy   = "terraform"
      }
    }
  }
}

# =============================================================================
# Subnets
# =============================================================================
subnet_parameters = {
  default = {
    # Public (ALB)
    public_lb_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "ecommerce_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Tier = "load-balancer", AZ = "az1" }
    }

    public_lb_az2 = {
      cidr_block              = "10.0.2.0/24"
      vpc_name                = "ecommerce_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Tier = "load-balancer", AZ = "az2" }
    }

    # Web Tier
    web_az1 = {
      cidr_block = "10.0.10.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 0
      tags = { Tier = "web", AZ = "az1" }
    }

    web_az2 = {
      cidr_block = "10.0.11.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 1
      tags = { Tier = "web", AZ = "az2" }
    }

    # API Tier
    api_az1 = {
      cidr_block = "10.0.20.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 0
      tags = { Tier = "api", AZ = "az1" }
    }

    api_az2 = {
      cidr_block = "10.0.21.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 1
      tags = { Tier = "api", AZ = "az2" }
    }

    # Database Tier
    db_az1 = {
      cidr_block = "10.0.30.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 0
      tags = { Tier = "database", AZ = "az1" }
    }

    db_az2 = {
      cidr_block = "10.0.31.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 1
      tags = { Tier = "database", AZ = "az2" }
    }

    # Cache Tier (ElastiCache)
    cache_az1 = {
      cidr_block = "10.0.40.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 0
      tags = { Tier = "cache", AZ = "az1" }
    }

    cache_az2 = {
      cidr_block = "10.0.41.0/24"
      vpc_name   = "ecommerce_vpc"
      az_index   = 1
      tags = { Tier = "cache", AZ = "az2" }
    }
  }
}

# =============================================================================
# Security Groups
# =============================================================================
security_group_parameters = {
  default = {
    alb_sg   = { name = "ecommerce-alb-sg", vpc_name = "ecommerce_vpc", tags = { Tier = "lb" } }
    web_sg   = { name = "ecommerce-web-sg", vpc_name = "ecommerce_vpc", tags = { Tier = "web" } }
    api_sg   = { name = "ecommerce-api-sg", vpc_name = "ecommerce_vpc", tags = { Tier = "api" } }
    db_sg    = { name = "ecommerce-db-sg", vpc_name = "ecommerce_vpc", tags = { Tier = "db" } }
    cache_sg = { name = "ecommerce-cache-sg", vpc_name = "ecommerce_vpc", tags = { Tier = "cache" } }
  }
}

# =============================================================================
# Security Group Rules - Ingress
# =============================================================================
ipv4_ingress_rule = {
  default = {
    alb_https      = { vpc_name = "ecommerce_vpc", sg_name = "alb_sg", from_port = 443, to_port = 443, protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
    web_from_alb   = { vpc_name = "ecommerce_vpc", sg_name = "web_sg", from_port = 3000, to_port = 3000, protocol = "TCP", source_security_group_name = "alb_sg" }
    api_from_web   = { vpc_name = "ecommerce_vpc", sg_name = "api_sg", from_port = 8080, to_port = 8080, protocol = "TCP", source_security_group_name = "web_sg" }
    db_from_api    = { vpc_name = "ecommerce_vpc", sg_name = "db_sg", from_port = 5432, to_port = 5432, protocol = "TCP", source_security_group_name = "api_sg" }
    cache_from_api = { vpc_name = "ecommerce_vpc", sg_name = "cache_sg", from_port = 6379, to_port = 6379, protocol = "TCP", source_security_group_name = "api_sg" }
  }
}

# =============================================================================
# Security Group Rules - Egress
# =============================================================================
ipv4_egress_rule = {
  default = {
    alb_egress   = { vpc_name = "ecommerce_vpc", sg_name = "alb_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    web_egress   = { vpc_name = "ecommerce_vpc", sg_name = "web_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    api_egress   = { vpc_name = "ecommerce_vpc", sg_name = "api_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    db_egress    = { vpc_name = "ecommerce_vpc", sg_name = "db_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    cache_egress = { vpc_name = "ecommerce_vpc", sg_name = "cache_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
  }
}

# =============================================================================
# NAT Gateways (Multi-AZ)
# =============================================================================
eip_parameters = {
  default = {
    nat_eip_az1 = { domain = "vpc", tags = { Name = "ecommerce-nat-eip-az1" } }
    nat_eip_az2 = { domain = "vpc", tags = { Name = "ecommerce-nat-eip-az2" } }
  }
}

nat_gateway_parameters = {
  default = {
    nat_az1 = {
      subnet_name                = "public_lb_az1"
      eip_name_for_allocation_id = "nat_eip_az1"
      tags = { Name = "ecommerce-nat-az1" }
    }

    nat_az2 = {
      subnet_name                = "public_lb_az2"
      eip_name_for_allocation_id = "nat_eip_az2"
      tags = { Name = "ecommerce-nat-az2" }
    }
  }
}

# =============================================================================
# VPC Endpoints
# =============================================================================
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region             = "ap-south-1"
      vpc_name           = "ecommerce_vpc"
      service_name       = "s3"
      vpc_endpoint_type  = "Gateway"
      route_table_names  = ["private_rt_az1", "private_rt_az2"]
      tags = { Purpose = "product-images" }
    }

    sqs_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "ecommerce_vpc"
      service_name         = "sqs"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["api_az1", "api_az2"]
      security_group_names = ["api_sg"]
      private_dns_enabled  = true
      tags = { Purpose = "order-queue" }
    }
  }
}
```

---

## Download Instructions

### Method 1: Copy Single Example

1. **Choose your architecture** from the examples above
2. **Create `terraform.tfvars`** in your project root
3. **Copy the entire configuration** for your chosen example
4. **Customize** CIDR blocks, names, and tags as needed
5. **Run terraform:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### Method 2: Create Complete Template

Create a comprehensive `terraform.tfvars` with all sections:

```hcl
# =============================================================================
# VPC Configuration
# =============================================================================
vpc_parameters = {
  # Copy from examples above
}

# =============================================================================
# Subnet Configuration
# =============================================================================
subnet_parameters = {
  # Copy from examples above
}

# =============================================================================
# Internet Gateway
# =============================================================================
igw_parameters = {
  # Copy from examples above
}

# =============================================================================
# Elastic IPs
# =============================================================================
eip_parameters = {
  # Copy from examples above
}

# =============================================================================
# NAT Gateways
# =============================================================================
nat_gateway_parameters = {
  # Copy from examples above
}

# =============================================================================
# Route Tables
# =============================================================================
rt_parameters = {
  # Copy from examples above
}

# =============================================================================
# Route Table Associations
# =============================================================================
rt_association_parameters = {
  # Copy from examples above
}

# =============================================================================
# Security Groups
# =============================================================================
security_group_parameters = {
  # Copy from examples above
}

# =============================================================================
# Security Group Rules - Ingress
# =============================================================================
ipv4_ingress_rule = {
  # Copy from examples above
}

# =============================================================================
# Security Group Rules - Egress
# =============================================================================
ipv4_egress_rule = {
  # Copy from examples above
}

# =============================================================================
# VPC Endpoints (Optional)
# =============================================================================
vpc_gateway_endpoint_parameters = {
  # Copy from examples above
}

# =============================================================================
# EKS Clusters (Optional)
# =============================================================================
eks_clusters = {
  # Copy from examples above if using EKS
}

# =============================================================================
# EKS Node Groups (Optional)
# =============================================================================
eks_nodegroups = {
  # Copy from examples above if using EKS
}
```

### Method 3: Workspace-Based Deployment

For multi-environment setups:

```bash
# 1. Initialize Terraform
terraform init

# 2. Create workspaces
terraform workspace new dev
terraform workspace new qe
terraform workspace new prod

# 3. Deploy to each environment
terraform workspace select dev
terraform apply

terraform workspace select qe
terraform apply

terraform workspace select prod
terraform apply

# 4. View current workspace
terraform workspace show

# 5. List all workspaces
terraform workspace list
```

---

## Customization Tips

### 1. Adjust CIDR Blocks

**Principle:** Plan your IP address space to avoid overlaps

```hcl
# Development: 10.10.0.0/16 (65,536 IPs)
# QE:          10.20.0.0/16 (65,536 IPs)
# Production:  10.30.0.0/16 (65,536 IPs)

# Within each VPC:
# Public:      x.x.1.0/24 - x.x.9.0/24
# Private App: x.x.10.0/24 - x.x.19.0/24
# Database:    x.x.20.0/24 - x.x.29.0/24
# Cache:       x.x.40.0/24 - x.x.49.0/24
```

### 2. Scale Subnet Sizes

```hcl
# Small subnets (for testing)
cidr_block = "10.0.1.0/27"  # 32 IPs (27 usable)

# Standard subnets (recommended)
cidr_block = "10.0.1.0/24"  # 256 IPs (251 usable)

# Large subnets (EKS, heavy compute)
cidr_block = "10.0.1.0/23"  # 512 IPs (507 usable)
cidr_block = "10.0.1.0/20"  # 4096 IPs (4091 usable)
```

### 3. Add More Availability Zones

```hcl
# Triple-AZ setup
subnet_parameters = {
  default = {
    public_az1 = { cidr_block = "10.0.1.0/24", az_index = 0, ... }
    public_az2 = { cidr_block = "10.0.2.0/24", az_index = 1, ... }
    public_az3 = { cidr_block = "10.0.3.0/24", az_index = 2, ... }
  }
}
```

### 4. Change AWS Region

Update region in VPC endpoint configurations:

```hcl
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region = "us-east-1"  # Change to your region
      # ...
    }
  }
}
```

### 5. Customize Tagging

```hcl
tags = {
  Environment    = "production"
  Project        = "my-project"
  Team           = "platform"
  CostCenter     = "engineering"
  ManagedBy      = "terraform"
  Owner          = "your-team@example.com"
  ComplianceReq  = "pci-dss"
  BackupRequired = "true"
}
```

### 6. Add Bastion Host Security Group

```hcl
security_group_parameters = {
  default = {
    # ... existing security groups ...
    
    bastion_sg = {
      name     = "bastion-sg"
      vpc_name = "my_vpc"
      tags = { Purpose = "ssh-access" }
    }
  }
}

ipv4_ingress_rule = {
  default = {
    # ... existing rules ...
    
    bastion_ssh = {
      vpc_name  = "my_vpc"
      sg_name   = "bastion_sg"
      from_port = 22
      to_port   = 22
      protocol  = "TCP"
      cidr_ipv4 = "203.0.113.0/24"  # Your office IP range
    }
  }
}
```

### 7. Enable VPC Flow Logs (Add to root module)

```hcl
# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 7
}

# Create IAM role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

# Enable VPC Flow Logs
resource "aws_flow_log" "main" {
  vpc_id          = module.my_vpc.vpcs["my_vpc"].id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
}
```

---

## Validation Checklist

After deploying any example, validate your infrastructure:

### Network Connectivity

```bash
# 1. Verify VPC created
terraform output | grep vpc

# 2. Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"

# 3. Verify NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"

# 4. Test internet connectivity (from private subnet instance)
curl -I https://google.com  # Should work via NAT

# 5. Verify VPC endpoints
aws ec2 describe-vpc-endpoints
```

### Security

```bash
# 1. Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxxxx"

# 2. Verify security group rules
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=sg-xxxxx"

# 3. Test bastion access (if configured)
ssh -i key.pem ec2-user@bastion-ip

# 4. Verify no public database access
aws ec2 describe-instances --filters "Name=subnet-id,Values=subnet-xxxxx" \
  --query 'Reservations[*].Instances[*].PublicIpAddress'
```

### Cost Verification

```bash
# Estimate monthly costs
# NAT Gateways: Count × $32.40
# Interface Endpoints: Count × $7.30
# EIPs (unattached): Count × $3.60

# Check for idle resources
aws ec2 describe-addresses --query 'Addresses[?AssociationId==`null`]'
```

---

## Troubleshooting Common Issues

### Issue 1: CIDR Block Conflicts

**Error:** `InvalidVpcRange: CIDR block overlaps with existing VPC`

**Solution:**
```hcl
# Ensure unique CIDR blocks per VPC
vpc_parameters = {
  default = { dev_vpc = { cidr_block = "10.10.0.0/16" } }
  qe      = { qe_vpc  = { cidr_block = "10.20.0.0/16" } }
  prod    = { prod_vpc = { cidr_block = "10.30.0.0/16" } }
}
```

### Issue 2: Subnet Not in VPC CIDR

**Error:** `InvalidSubnet.Range: Subnet CIDR is not within VPC CIDR`

**Solution:**
```hcl
# VPC: 10.0.0.0/16
subnet_parameters = {
  default = {
    my_subnet = {
      cidr_block = "10.0.1.0/24"  # ✅ Within VPC range
      # NOT "192.168.1.0/24"      # ❌ Outside VPC range
    }
  }
}
```

### Issue 3: Route Table Association Failed

**Error:** `Resource.AlreadyAssociated`

**Solution:** Each subnet can only be associated with one route table
```bash
# Check existing associations
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# Remove old association if needed
terraform state rm aws_route_table_association.old_assoc
```

### Issue 4: NAT Gateway Creation Timeout

**Error:** `Error waiting for NAT Gateway to become available`

**Solution:**
- NAT Gateway creation takes 5-10 minutes
- Ensure subnet is in a public subnet (has route to IGW)
- Verify EIP is available

---

## Migration Examples

### From Single NAT to Multi-AZ NAT

```hcl
# Before: Single NAT (dev setup)
eip_parameters = {
  default = {
    nat_eip = { domain = "vpc" }
  }
}

nat_gateway_parameters = {
  default = {
    single_nat = {
      subnet_name                = "public_az1"
      eip_name_for_allocation_id = "nat_eip"
    }
  }
}

# After: Multi-AZ NAT (production setup)
eip_parameters = {
  default = {
    nat_eip_az1 = { domain = "vpc" }
    nat_eip_az2 = { domain = "vpc" }
  }
}

nat_gateway_parameters = {
  default = {
    nat_az1 = {
      subnet_name                = "public_az1"
      eip_name_for_allocation_id = "nat_eip_az1"
    }

    nat_az2 = {
      subnet_name                = "public_az2"
      eip_name_for_allocation_id = "nat_eip_az2"
    }
  }
}

# Update route tables
rt_parameters = {
  default = {
    private_rt_az1 = {
      routes = [{ target_type = "nat", target_key = "nat_az1" }]
    }

    private_rt_az2 = {
      routes = [{ target_type = "nat", target_key = "nat_az2" }]
    }
  }
}
```

---

## Cost Comparison Table

| Architecture | NAT Gateways | VPC Endpoints | Monthly Cost | Use Case |
|--------------|--------------|---------------|--------------|----------|
| Basic Web App | 1 | 1 Gateway | ~$32 | Development |
| Three-Tier | 2 | 1 Gateway | ~$65 | QE/Staging |
| Multi-Env (All) | 6 (1+2+3) | - | ~$194 | Dev+QE+Prod |
| EKS HA | 3 | 3 (2 Interface + 1 Gateway) | ~$112 | Production K8s |
| E-Commerce | 2 | 2 (1 Interface + 1 Gateway) | ~$72 | Production Web |

**Note:** Costs exclude EC2 instances, RDS, and data transfer

---

## Next Steps

After deploying your chosen architecture:

1. **Configure kubectl** (for EKS examples)
   ```bash
   aws eks update-kubeconfig --name cluster-name --region ap-south-1
   ```

2. **Deploy applications**
   - EC2 instances in appropriate subnets
   - RDS databases in isolated database subnets
   - ElastiCache in cache subnets

3. **Set up monitoring**
   - Enable VPC Flow Logs
   - Configure CloudWatch alarms
   - Set up cost alerts

4. **Implement backup strategy**
   - Snapshot EBS volumes
   - Backup RDS databases
   - Document disaster recovery procedures

5. **Review security**
   - Audit security group rules
   - Enable GuardDuty
   - Configure AWS Config rules

---

## Additional Resources

- **Main Documentation:** [README.md](../README.md)
- **Networking Guide:** [NETWORKING.md](./NETWORKING.md)
- **Security Guide:** [NETWORK_SECURITY.md](./NETWORK_SECURITY.md)
- **VPC Endpoints:** [VPC_ENDPOINTS.md](./VPC_ENDPOINTS.md)
- **EKS Guide:** [EKS.md](./EKS.md)
- **Troubleshooting:** [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- **Cost Optimization:** [COST_OPTIMIZATION.md](./COST_OPTIMIZATION.md)

---

## Contributing

Found an issue or have a new architecture example? Please contribute:

1. Fork the repository
2. Add your example to this file
3. Include cost estimates and use case description
4. Submit a pull request

---

**Last Updated:** 2025-01-16  
**Version:** 1.0  
**Maintained By:** Infrastructure Team