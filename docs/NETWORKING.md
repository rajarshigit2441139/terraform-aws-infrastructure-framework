# Networking Guide

This guide covers all networking components in the Terraform framework: **VPCs, Subnets, Route Tables, Internet Gateways, NAT Gateways, and Elastic IPs**.

---

## Table of Contents

- [Overview](#overview)
- [Network Architecture Patterns](#network-architecture-patterns)
  - [Pattern 1: Basic Public-Private (Single AZ)](#pattern-1-basic-public-private-single-az)
  - [Pattern 2: Multi-AZ High Availability (Production)](#pattern-2-multi-az-high-availability-production)
  - [Pattern 3: Three-Tier Architecture](#pattern-3-three-tier-architecture)
- [VPC (Virtual Private Cloud)](#vpc-virtual-private-cloud)
- [Subnets](#subnets)
- [Internet Gateway](#internet-gateway)
- [Elastic IP](#elastic-ip)
- [NAT Gateway](#nat-gateway)
- [Route Tables](#route-tables)
- [Complete Examples](#complete-examples)
  - [Example 1: Small Startup (Single AZ, Cost-Optimized)](#example-1-small-startup-single-az-cost-optimized)
  - [Example 2: Production E-Commerce (Multi-AZ, HA)](#example-2-production-e-commerce-multi-az-ha)
- [Best Practices](#best-practices)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Validation Checklist](#validation-checklist)
- [Quick Reference](#quick-reference)
- [Additional Resources](#additional-resources)
- [Next Steps](#next-steps)

---

## Overview

### Network Flow

```text
Internet
   │
   ▼
┌──────────────────┐
│ Internet Gateway │ (FREE)
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│              VPC (10.0.0.0/16)              │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Public Subnet   │  │ Public Subnet   │  │
│  │ 10.0.1.0/24     │  │ 10.0.2.0/24     │  │
│  │ AZ1             │  │ AZ2             │  │
│  │                 │  │                 │  │
│  │ [NAT Gateway]   │  │ [NAT Gateway]   │  │
│  │ (uses EIP)      │  │ (uses EIP)      │  │
│  └────────┬────────┘  └────────┬────────┘  │
│           │                    │           │
│           ▼                    ▼           │
│  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Private Subnet  │  │ Private Subnet  │  │
│  │ 10.0.10.0/24    │  │ 10.0.11.0/24    │  │
│  │ AZ1             │  │ AZ2             │  │
│  │                 │  │                 │  │
│  │ [App Servers]   │  │ [App Servers]   │  │
│  └─────────────────┘  └─────────────────┘  │
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Database Subnet │  │ Database Subnet │  │
│  │ 10.0.20.0/24    │  │ 10.0.21.0/24    │  │
│  │ AZ1 (Isolated)  │  │ AZ2 (Isolated)  │  │
│  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────┘
```

### Component Summary

| Component | Purpose | Cost | Required |
|---|---|---:|:---:|
| VPC | Isolated network | FREE | ✅ Yes |
| Subnets | Network segments | FREE | ✅ Yes |
| Internet Gateway | Public internet access | FREE | ⚠️ For public resources |
| Elastic IP | Static public IPv4 | FREE* | ⚠️ For NAT Gateway |
| NAT Gateway | Private subnet internet | $32.40/mo + data | ⚠️ For private subnets |
| Route Tables | Traffic routing | FREE | ✅ Yes |

> **Note:** EIPs are free when attached, **$3.60/month when unattached**.

---

## Network Architecture Patterns

### Pattern 1: Basic Public-Private (Single AZ)

**Use Case:** Development, testing, small applications

```hcl
# terraform.tfvars
vpc_parameters = {
  default = {
    dev_vpc = {
      cidr_block = "10.10.0.0/16"
      tags = { Environment = "dev" }
    }
  }
}

subnet_parameters = {
  default = {
    public_subnet = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public" }
    }

    private_subnet = {
      cidr_block              = "10.10.10.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Type = "private" }
    }
  }
}

igw_parameters = {
  default = {
    dev_igw = {
      vpc_name = "dev_vpc"
      tags = { Purpose = "internet-access" }
    }
  }
}

eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags = { Purpose = "NAT Gateway" }
    }
  }
}

nat_gateway_parameters = {
  default = {
    dev_nat = {
      connectivity_type          = "public"
      subnet_name                = "public_subnet"
      eip_name_for_allocation_id = "nat_eip"
      tags = { Purpose = "private-internet" }
    }
  }
}

rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "dev_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "dev_igw"
        }
      ]
      tags = { Type = "public" }
    }

    private_rt = {
      vpc_name = "dev_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "dev_nat"
        }
      ]
      tags = { Type = "private" }
    }
  }
}

rt_association_parameters = {
  public_assoc = {
    subnet_name = "public_subnet"
    rt_name     = "public_rt"
  }

  private_assoc = {
    subnet_name = "private_subnet"
    rt_name     = "private_rt"
  }
}
```

**Monthly Cost:** `~$32.40` (1 NAT Gateway)

**Pros**
- ✅ Simple setup  
- ✅ Cost-effective for dev/test  
- ✅ Easy to understand  

**Cons**
- ⚠️ Single point of failure (1 NAT, 1 AZ)  
- ⚠️ Not suitable for production  

---

### Pattern 2: Multi-AZ High Availability (Production)

**Use Case:** Production applications requiring HA

```hcl
# terraform.tfvars
vpc_parameters = {
  prod = {
    prod_vpc = {
      cidr_block = "10.30.0.0/16"
      tags = { Environment = "prod" }
    }
  }
}

subnet_parameters = {
  prod = {
    # Public Subnets (for NAT Gateways, Load Balancers)
    public_subnet_az1 = {
      cidr_block              = "10.30.1.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az1" }
    }

    public_subnet_az2 = {
      cidr_block              = "10.30.2.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az2" }
    }

    # Private Subnets (for application servers)
    private_subnet_az1 = {
      cidr_block              = "10.30.10.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Type = "private", AZ = "az1" }
    }

    private_subnet_az2 = {
      cidr_block              = "10.30.11.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = { Type = "private", AZ = "az2" }
    }

    # Database Subnets (isolated)
    db_subnet_az1 = {
      cidr_block              = "10.30.20.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Type = "database", AZ = "az1" }
    }

    db_subnet_az2 = {
      cidr_block              = "10.30.21.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = { Type = "database", AZ = "az2" }
    }
  }
}

igw_parameters = {
  prod = {
    prod_igw = {
      vpc_name = "prod_vpc"
      tags = { Purpose = "internet-access" }
    }
  }
}

eip_parameters = {
  prod = {
    nat_eip_az1 = {
      domain = "vpc"
      tags = { Purpose = "NAT Gateway", AZ = "az1" }
    }

    nat_eip_az2 = {
      domain = "vpc"
      tags = { Purpose = "NAT Gateway", AZ = "az2" }
    }
  }
}

nat_gateway_parameters = {
  prod = {
    nat_az1 = {
      connectivity_type          = "public"
      subnet_name                = "public_subnet_az1"
      eip_name_for_allocation_id = "nat_eip_az1"
      tags = { AZ = "az1" }
    }

    nat_az2 = {
      connectivity_type          = "public"
      subnet_name                = "public_subnet_az2"
      eip_name_for_allocation_id = "nat_eip_az2"
      tags = { AZ = "az2" }
    }
  }
}

rt_parameters = {
  prod = {
    public_rt = {
      vpc_name = "prod_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "prod_igw"
        }
      ]
      tags = { Type = "public" }
    }

    private_rt_az1 = {
      vpc_name = "prod_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az1"
        }
      ]
      tags = { Type = "private", AZ = "az1" }
    }

    private_rt_az2 = {
      vpc_name = "prod_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az2"
        }
      ]
      tags = { Type = "private", AZ = "az2" }
    }

    db_rt = {
      vpc_name = "prod_vpc"
      routes   = []  # Isolated - no internet
      tags = { Type = "database" }
    }
  }
}

rt_association_parameters = {
  public_az1_assoc = {
    subnet_name = "public_subnet_az1"
    rt_name     = "public_rt"
  }

  public_az2_assoc = {
    subnet_name = "public_subnet_az2"
    rt_name     = "public_rt"
  }

  private_az1_assoc = {
    subnet_name = "private_subnet_az1"
    rt_name     = "private_rt_az1"
  }

  private_az2_assoc = {
    subnet_name = "private_subnet_az2"
    rt_name     = "private_rt_az2"
  }

  db_az1_assoc = {
    subnet_name = "db_subnet_az1"
    rt_name     = "db_rt"
  }

  db_az2_assoc = {
    subnet_name = "db_subnet_az2"
    rt_name     = "db_rt"
  }
}
```

**Monthly Cost:** `~$64.80` (2 NAT Gateways)

**Pros**
- ✅ High availability (survives AZ failure)  
- ✅ No cross-AZ data transfer charges (when routing stays in-AZ)  
- ✅ Production-grade  

**Cons**
- 💰 Higher cost (2× NAT Gateways)  

---

### Pattern 3: Three-Tier Architecture

**Use Case:** Web applications with clear tier separation

```text
┌──────────────────────────────────────────────────┐
│                 VPC 10.0.0.0/16                  │
├──────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────┐  │
│  │         Web Tier (Public)                  │  │
│  │  10.0.1.0/24, 10.0.2.0/24                  │  │
│  │  - Load Balancers                          │  │
│  │  - Public-facing web servers               │  │
│  └────────────────────────────────────────────┘  │
│                      │                           │
│                      ▼                           │
│  ┌────────────────────────────────────────────┐  │
│  │      Application Tier (Private)            │  │
│  │  10.0.10.0/24, 10.0.11.0/24                │  │
│  │  - API servers                             │  │
│  │  - Business logic                          │  │
│  └────────────────────────────────────────────┘  │
│                      │                           │
│                      ▼                           │
│  ┌────────────────────────────────────────────┐  │
│  │       Database Tier (Isolated)             │  │
│  │  10.0.20.0/24, 10.0.21.0/24                │  │
│  │  - RDS databases                           │  │
│  │  - ElastiCache                             │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

```hcl
subnet_parameters = {
  default = {
    # Web Tier - Public
    web_subnet_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Tier = "web" }
    }

    web_subnet_az2 = {
      cidr_block              = "10.0.2.0/24"
      vpc_name                = "app_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Tier = "web" }
    }

    # App Tier - Private
    app_subnet_az1 = {
      cidr_block              = "10.0.10.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Tier = "application" }
    }

    app_subnet_az2 = {
      cidr_block              = "10.0.11.0/24"
      vpc_name                = "app_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = { Tier = "application" }
    }

    # Database Tier - Isolated
    db_subnet_az1 = {
      cidr_block              = "10.0.20.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Tier = "database" }
    }

    db_subnet_az2 = {
      cidr_block              = "10.0.21.0/24"
      vpc_name                = "app_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = { Tier = "database" }
    }
  }
}

rt_parameters = {
  default = {
    # Web tier route table (public)
    web_rt = {
      vpc_name = "app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "app_igw"
        }
      ]
      tags = { Tier = "web" }
    }

    # App tier route table (private with NAT)
    app_rt_az1 = {
      vpc_name = "app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az1"
        }
      ]
      tags = { Tier = "application", AZ = "az1" }
    }

    app_rt_az2 = {
      vpc_name = "app_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az2"
        }
      ]
      tags = { Tier = "application", AZ = "az2" }
    }

    # Database tier route table (isolated - no routes)
    db_rt = {
      vpc_name = "app_vpc"
      routes   = []
      tags = { Tier = "database" }
    }
  }
}
```

---

## VPC (Virtual Private Cloud)

### Overview

A VPC is your isolated network in AWS. All other networking components exist within a VPC.

### Configuration

```hcl
vpc_parameters = {
  default = {
    my_vpc = {
      cidr_block           = "10.0.0.0/16"
      enable_dns_support   = true   # Always keep enabled
      enable_dns_hostnames = true   # Enable for public resources
      tags = {
        Environment = "dev"
        Project     = "my-project"
      }
    }
  }
}
```

### CIDR Planning Guide

| Environment | CIDR Block | Usable IPs | Use Case |
|---|---|---:|---|
| Development | 10.10.0.0/16 | 65,534 | Small-medium projects |
| QA/Staging | 10.20.0.0/16 | 65,534 | Testing environment |
| Production | 10.30.0.0/16 | 65,534 | Production workloads |

**Key Rules**
- ✅ Use `/16` for maximum flexibility  
- ✅ Plan for VPC peering (avoid overlaps)  
- ✅ Reserve space for future expansion  
- ⚠️ You cannot shrink/replace VPC CIDR in-place after creation (plan early)  

### DNS Settings

**`enable_dns_support` (Always `true`)**
- Required for VPC endpoints
- Provides DNS resolution at `VPC_CIDR + 2` (e.g., `10.0.0.2`)

**`enable_dns_hostnames` (Enable for public resources)**
- Assigns public DNS names to instances with public IPs
- Required for: ALBs/NLBs, public EC2 instances

---

## Subnets

### Overview

Subnets divide your VPC into smaller network segments. Use them to organize resources by tier and availability zone.

### Subnet Types

**Public Subnets**
- Purpose: Internet-facing resources (ALB/NLB, NAT gateways, bastion hosts)
- Route: `0.0.0.0/0 → Internet Gateway`
- Public IPs: `map_public_ip_on_launch = true`

**Private Subnets**
- Purpose: App servers, internal services
- Route: `0.0.0.0/0 → NAT Gateway`
- Public IPs: `map_public_ip_on_launch = false`

**Database Subnets (Isolated)**
- Purpose: Databases/caches
- Route: No internet route (isolated)
- Public IPs: `map_public_ip_on_launch = false`

### Configuration

```hcl
subnet_parameters = {
  default = {
    public_subnet_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0  # Resolves to first AZ in region
      map_public_ip_on_launch = true
      tags = {
        Type = "public"
        AZ   = "az1"
      }
    }

    private_subnet_az1 = {
      cidr_block              = "10.0.10.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = {
        Type = "private"
        AZ   = "az1"
      }
    }
  }
}
```

### Subnet Sizing

| Size | CIDR | Total IPs | Usable IPs | Use Case |
|---|---|---:|---:|---|
| Small | /27 | 32 | 27 | Testing |
| Standard | /24 | 256 | 251 | Recommended |
| Large | /23 | 512 | 507 | High-density |
| EKS | /20 | 4,096 | 4,091 | Large Kubernetes clusters |

AWS reserves **5 IPs per subnet**:
- `.0` Network address  
- `.1` VPC router  
- `.2` DNS server  
- `.3` Future use  
- `.255` Broadcast  

### Availability Zone Strategy

```hcl
# az_index maps to AZ names dynamically
# 0 → first AZ in region (example: ap-south-1a)
# 1 → second AZ
# 2 → third AZ

subnet_parameters = {
  default = {
    subnet_az1 = { az_index = 0, ... }  # First AZ
    subnet_az2 = { az_index = 1, ... }  # Second AZ
    subnet_az3 = { az_index = 2, ... }  # Third AZ
  }
}
```

**Best Practice:** Deploy across at least **2 AZs** for HA (3 AZs recommended for production).

---

## Internet Gateway

### Overview

Enables communication between VPC and the internet. Required for public subnets.

### Configuration

```hcl
igw_parameters = {
  default = {
    main_igw = {
      vpc_name = "my_vpc"
      tags = {
        Purpose = "internet-access"
      }
    }
  }
}
```

### Key Points
- Cost: **FREE**
- Limit: **1 IGW per VPC**
- Highly available by default (AWS-managed)
- Used in **public route tables**

### Common Mistake

❌ **Wrong (multiple IGWs for one VPC):**
```hcl
igw_parameters = {
  default = {
    igw1 = { vpc_name = "my_vpc" }
    igw2 = { vpc_name = "my_vpc" }  # ERROR!
  }
}
```

✅ **Correct:**
```hcl
igw_parameters = {
  default = {
    main_igw = { vpc_name = "my_vpc" }
  }
}
```

---

## Elastic IP

### Overview

Static public IPv4 addresses. Required for **NAT Gateways**.

### Configuration

```hcl
eip_parameters = {
  default = {
    nat_eip_az1 = {
      domain = "vpc"
      tags = {
        Purpose = "NAT Gateway"
        AZ      = "az1"
      }
    }

    nat_eip_az2 = {
      domain = "vpc"
      tags = {
        Purpose = "NAT Gateway"
        AZ      = "az2"
      }
    }
  }
}
```

### Cost

| State | Cost | Notes |
|---|---:|---|
| Attached to NAT Gateway | FREE | No charges |
| Attached to running instance | FREE | No charges |
| Unattached (idle) | $3.60/month | |
| Released | $0.00 | |

### Key Points
- Default limit: **5 EIPs per region** (quota can be increased)
- Release unused EIPs immediately
- Common uses: NAT Gateways, bastion hosts, NLB static IPs

---

## NAT Gateway

### Overview

Enables instances in private subnets to access the internet while preventing inbound connections.

### Configuration

```hcl
nat_gateway_parameters = {
  default = {
    nat_az1 = {
      connectivity_type          = "public"
      subnet_name                = "public_subnet_az1"
      eip_name_for_allocation_id = "nat_eip_az1"
      tags = {
        AZ = "az1"
      }
    }

    nat_az2 = {
      connectivity_type          = "public"
      subnet_name                = "public_subnet_az2"
      eip_name_for_allocation_id = "nat_eip_az2"
      tags = {
        AZ = "az2"
      }
    }
  }
}
```

### Cost

| Component | Cost | Calculation |
|---|---:|---|
| Hourly charge | $0.045/hour | $0.045 × 24 × 30 = **$32.40/month** |
| Data processing | $0.045/GB | Variable |

**Examples**
- Single NAT Gateway: `~$32.40/month`
- 2 NATs (2 AZ): `~$64.80/month`
- 3 NATs (3 AZ): `~$97.20/month`

### Placement

✅ NAT Gateway in **public subnet** (must have IGW route)

❌ NAT Gateway in private subnet (no internet access)

### High Availability Strategies

**Single NAT (Cost-Optimized)**
```text
Public AZ1 → NAT
   ↓
Private AZ1
Private AZ2 (cross-AZ to NAT)
```
- Cost: `~$32.40/month`
- Downside: Single point of failure + cross-AZ data charges

**Multi-AZ NAT (Production)**
```text
Public AZ1 → NAT1 → Private AZ1
Public AZ2 → NAT2 → Private AZ2
```
- Cost: `~$64.80/month`
- Benefit: AZ fault tolerance, avoids cross-AZ NAT traffic

---

## Route Tables

### Overview

Route tables control where network traffic is directed within your VPC.

### Public Route Table (IGW)

```hcl
rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "my_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "main_igw"
        }
      ]
      tags = { Type = "public" }
    }
  }
}
```

### Private Route Table (NAT)

```hcl
rt_parameters = {
  default = {
    private_rt_az1 = {
      vpc_name = "my_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_az1"
        }
      ]
      tags = { Type = "private", AZ = "az1" }
    }
  }
}
```

### Isolated Route Table (No Routes)

```hcl
rt_parameters = {
  default = {
    db_rt = {
      vpc_name = "my_vpc"
      routes   = []  # No routes
      tags = { Type = "database" }
    }
  }
}
```

### Route Table Associations

```hcl
rt_association_parameters = {
  public_assoc = {
    subnet_name = "public_subnet_az1"
    rt_name     = "public_rt"
  }

  private_assoc = {
    subnet_name = "private_subnet_az1"
    rt_name     = "private_rt_az1"
  }
}
```

### Target Types

| Type | Value | Example | Use Case |
|---|---|---|---|
| Internet Gateway | `igw` | `main_igw` | Public internet |
| NAT Gateway | `nat` | `nat_az1` | Private internet |
| VPC Peering | `pcx` | `pcx-analytics` | VPC-to-VPC |
| Transit Gateway | `tgw` | `tgw-core` | Multi-VPC hub |
| VPN Gateway | `vgw` | `vgw-onprem` | On-prem routing |

### Advanced Routing Example

```hcl
rt_parameters = {
  default = {
    hybrid_rt = {
      vpc_name = "my_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "main_igw"
        },
        {
          cidr_block  = "10.20.0.0/16"
          target_type = "pcx"
          target_key  = "pcx-analytics"
        },
        {
          cidr_block  = "192.168.0.0/16"
          target_type = "vgw"
          target_key  = "vgw-onprem"
        }
      ]
      tags = { Type = "hybrid" }
    }
  }
}
```

---

## Complete Examples

### Example 1: Small Startup (Single AZ, Cost-Optimized)

**Requirements**
- Development environment
- Single AZ acceptable
- Minimize costs

> Uses the same pattern as **Pattern 1**.  
**Monthly Cost:** `~$32.40` (1 NAT Gateway)

---

### Example 2: Production E-Commerce (Multi-AZ, HA)

**Requirements**
- High availability (multi-AZ)
- Three-tier architecture
- Production-grade

> Uses the same pattern as **Pattern 2** (Multi-AZ NAT + isolated DB subnets).  
**Monthly Cost:** `~$64.80` (2 NAT Gateways)

---

## Best Practices

### VPC Design

✅ **Do**
- Use `/16` CIDR for VPCs
- Avoid overlapping CIDRs across VPCs (peering)
- Keep `enable_dns_support = true`
- Enable `enable_dns_hostnames` for public resources
- Tag VPCs with Environment/Owner/Project

❌ **Don't**
- Use overlapping CIDR blocks across environments
- Disable DNS support (breaks endpoints & name resolution)
- Use tiny CIDRs for production
- Skip tagging

### Subnet Design

✅ **Do**
- Deploy across ≥ 2 AZs (3 for production)
- Use consistent CIDR tiers (`1.x` public, `10.x` private, `20.x` db)
- Use `/24` for most subnets
- Enable public IPs only for public subnets
- Name with purpose + AZ

❌ **Don't**
- Put all resources in one AZ
- Enable public IPs on database subnets
- Overlap subnets
- Mix tiers without clear intent/naming

### NAT Gateway Strategy

✅ **Do**
- Prod: one NAT per AZ
- Dev/Test: single NAT acceptable
- Keep NAT in public subnet
- Monitor NAT data processing
- Prefer VPC endpoints for AWS service traffic

❌ **Don't**
- Route all AZs through one NAT in prod (cross-AZ + SPOF)
- Place NAT in a private subnet
- Forget EIP allocations
- Use NAT for S3/DynamoDB (use gateway endpoints)

### Route Table Strategy

✅ **Do**
- Separate RTs by subnet type (public/private/db)
- One public RT per VPC (shared)
- One private RT per AZ (avoid cross-AZ NAT)
- Keep DB subnets isolated
- Document route purpose in tags

❌ **Don't**
- Mix IGW and NAT routes in the same RT for mixed subnet types
- Reuse private RTs across AZs in prod
- Add unnecessary routes
- Forget RT associations

---

## Cost Optimization

### Cost Breakdown

| Resource | Dev (Single AZ) | Prod (Multi-AZ) |
|---|---:|---:|
| VPC | FREE | FREE |
| Subnets | FREE | FREE |
| Internet Gateway | FREE | FREE |
| EIPs (attached) | FREE | FREE |
| NAT Gateway | $32.40/mo | $64.80/mo |
| NAT data processing | $0.045/GB | $0.045/GB |
| **Total base** | **~$32.40** | **~$64.80** |

### Optimization Tips

#### 1) Reduce NAT Gateway usage with VPC Endpoints

```hcl
# Add S3 Gateway Endpoint (FREE)
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region            = "ap-south-1"
      vpc_name          = "my_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt_az1", "private_rt_az2"]
    }
  }
}
```

✅ Saves NAT data processing charges for S3 traffic.

#### 2) Single NAT for non-production

Use 1 NAT for all private subnets in dev/test to save `~$32.40/month`.

#### 3) Monitor NAT data transfer

```bash
# NAT Gateway data processed
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-xxxxx \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-31T23:59:59Z \
  --period 2592000 \
  --statistics Sum
```

---

## Troubleshooting

### Issue: Cannot access internet from public subnet

**Symptoms**
- Instances in public subnet cannot reach internet
- `ping 8.8.8.8` fails

**Diagnosis**
```bash
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx
aws ec2 describe-internet-gateways --internet-gateway-ids igw-xxxxx
aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

**Fix**
- Ensure route table has `0.0.0.0/0 → IGW`
- Ensure RT is associated to subnet
- Ensure public IP assignment is enabled
- Check SG and NACL outbound rules

---

### Issue: Cannot access internet from private subnet

**Diagnosis**
```bash
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx --query 'NatGateways[0].State'
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx \
  --query 'NatGateways[0].NatGatewayAddresses[0].PublicIp'
```

**Fix**
- Ensure private RT has `0.0.0.0/0 → NAT`
- Ensure NAT state is `available`
- Ensure NAT is in a public subnet with IGW route
- Ensure NAT has an EIP attached

---

### Issue: High NAT Gateway costs

**Fix**
- Add S3/DynamoDB gateway endpoints
- Add interface endpoints for high-volume services
- Use NAT per AZ in prod to avoid cross-AZ NAT traffic
- Review app downloads/updates pulling large content

---

### Issue: Subnet out of IPs

**Diagnosis**
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].AvailableIpAddressCount'
```

**Fix**
- Use larger subnets (`/23` instead of `/24`)
- Add additional subnets
- Clean up unused ENIs
- Terminate unused instances

---

### Issue: VPC peering not working

**Fix**
- Add routes in both VPCs (bidirectional)
- Verify SG + NACL rules allow traffic
- Ensure CIDRs don’t overlap

---

### Issue: Cannot delete VPC (DependencyViolation)

Delete in order:
1) Instances/RDS/Load balancers  
2) NAT Gateways  
3) Internet Gateway  
4) Subnets  
5) Route tables (except main)  
6) Security groups (except default)  
7) VPC  

Or:
```bash
terraform destroy
```

---

## Validation Checklist

```bash
# ✅ VPC created
terraform output vpc_ids

# ✅ Subnets created
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"

# ✅ Internet Gateway attached
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-xxxxx"

# ✅ NAT Gateway available
aws ec2 describe-nat-gateways \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query 'NatGateways[*].[NatGatewayId,State]'

# ✅ Route tables associated
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-xxxxx"
```

Connectivity tests:
- Public subnet instance: `ping 8.8.8.8`
- Private subnet instance (via bastion/SSM): `curl ifconfig.me` (should show NAT EIP)

---

## Quick Reference

### Common CIDR Patterns

```text
VPC:        10.0.0.0/16

Public:     10.0.1.0/24   (AZ1)
            10.0.2.0/24   (AZ2)
            10.0.3.0/24   (AZ3)

Private:    10.0.10.0/24  (AZ1)
            10.0.11.0/24  (AZ2)
            10.0.12.0/24  (AZ3)

Database:   10.0.20.0/24  (AZ1)
            10.0.21.0/24  (AZ2)
            10.0.22.0/24  (AZ3)
```

### Route Table Patterns

| Subnet Type | Route | Target |
|---|---|---|
| Public | `0.0.0.0/0` | Internet Gateway |
| Private | `0.0.0.0/0` | NAT Gateway |
| Database | *(no routes)* | Isolated |

### Cost Quick Reference

| Setup | Monthly Cost |
|---|---:|
| Single NAT (Dev) | `~$32.40` |
| Multi-AZ NAT (2 AZs) | `~$64.80` |
| Multi-AZ NAT (3 AZs) | `~$97.20` |

---

## Additional Resources

- AWS VPC Documentation: https://docs.aws.amazon.com/vpc/
- Subnet Planning Calculator: https://www.davidc.net/sites/default/subnets/subnets.html
- NAT Gateway Pricing: https://aws.amazon.com/vpc/pricing/
- VPC Security Best Practices: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html

---

## Next Steps

- Security Groups Guide →
- VPC Endpoints Guide →
- EKS Networking →
