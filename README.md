# AWS Infrastructure as Code - Terraform Framework

> **Multi-environment, workspace-based AWS infrastructure management with modular Terraform**

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Available Infrastructure](#available-infrastructure)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Variable Structure](#variable-structure)
- [Documentation](#documentation)
- [Examples](#examples)
- [Cost Considerations](#cost-considerations)
- [Contributing](#contributing)
- [Support](#support)

---

##  Overview

This Terraform framework provides a **comprehensive, production-ready infrastructure-as-code solution** for AWS. Built with modularity, scalability, and multi-environment support at its core, it enables teams to manage complex AWS architectures across development, QA, and production environments using a single codebase.

### Key Principles

- **Workspace-Based Multi-Environment** - Separate dev, QE, and prod using Terraform workspaces
- **DRY (Don't Repeat Yourself)** - Reusable modules with consistent interfaces
- **Dynamic Resource Resolution** - Automatic ID injection and reference resolution
- **Production-Ready** - Battle-tested patterns and best practices
- **Cost-Aware** - Built-in cost optimization strategies
- **Well-Documented** - Comprehensive documentation for every module

---

##  Features

### 🏗️ Infrastructure Components

- ✅ **VPC Networking** - Fully isolated virtual networks
- ✅ **Multi-AZ Subnets** - Public, private, and database tiers
- ✅ **Internet & NAT Gateways** - Managed internet connectivity
- ✅ **Route Tables** - Dynamic routing with automatic gateway resolution
- ✅ **Security Groups** - Firewall rules with SG-to-SG references
- ✅ **VPC Endpoints** - Private AWS service connectivity (Gateway & Interface)
- ✅ **EKS Clusters** - Managed Kubernetes control planes
- ✅ **EKS Node Groups** - Worker nodes with launch templates
- ✅ **Elastic IPs** - Static public IP addresses

### 🔧 Framework Features

- 🎯 **Workspace Isolation** - `terraform workspace` support for environment separation
- 🔗 **Automatic Resource Linking** - Modules reference each other by name, not ID
- 📦 **Modular Design** - Each resource type is a self-contained module
- 🏷️ **Consistent Tagging** - Automatic `Name` tags plus custom tag support
- 🔄 **State Management** - Designed for remote state with locking
- 📊 **Output Chaining** - Structured outputs for cross-module dependencies
- 🛡️ **Type Safety** - Strongly-typed variables with validation
- 📝 **Comprehensive Docs** - Module-level and root-level documentation

---

##  Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                        Terraform Root                           │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Workspace   │  │  Workspace   │  │  Workspace   │         │
│  │   default    │  │      qe      │  │     prod     │         │
│  │    (dev)     │  │  (staging)   │  │ (production) │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                  │
│         └─────────────────┴─────────────────┘                  │
│                           │                                     │
│         ┌─────────────────┴─────────────────┐                  │
│         │                                   │                  │
│    ┌────▼────┐                         ┌───▼────┐             │
│    │ VPC(s)  │                         │ EKS    │             │
│    │         │                         │Cluster │             │
│    │  ┌──────▼──────┐                  └───┬────┘             │
│    │  │   Subnets   │                      │                  │
│    │  │  Public /   │                  ┌───▼────────┐         │
│    │  │  Private    │                  │   Node     │         │
│    │  └──────┬──────┘                  │   Groups   │         │
│    │         │                         └────────────┘         │
│    │  ┌──────▼──────┐                                         │
│    │  │   Gateways  │                                         │
│    │  │  IGW / NAT  │                                         │
│    │  └──────┬──────┘                                         │
│    │         │                                                │
│    │  ┌──────▼──────┐                                         │
│    │  │Route Tables │                                         │
│    │  └──────┬──────┘                                         │
│    │         │                                                │
│    │  ┌──────▼──────┐                                         │
│    │  │  Security   │                                         │
│    │  │   Groups    │                                         │
│    │  └─────────────┘                                         │
│    └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
```

### Network Flow Example

```
                        Internet
                           │
                           ▼
                   ┌───────────────┐
                   │Internet Gateway│
                   └───────┬────────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
        ┌───▼─────┐                   ┌──▼──────┐
        │ Public  │                   │ Public  │
        │Subnet 1 │                   │Subnet 2 │
        │  (AZ1)  │                   │  (AZ2)  │
        └───┬─────┘                   └──┬──────┘
            │                             │
      ┌─────▼──────┐               ┌──────▼─────┐
      │NAT Gateway │               │NAT Gateway │
      │    (AZ1)   │               │    (AZ2)   │
      └─────┬──────┘               └──────┬─────┘
            │                             │
        ┌───▼─────┐                   ┌──▼──────┐
        │ Private │                   │ Private │
        │Subnet 1 │                   │Subnet 2 │
        │  (AZ1)  │                   │  (AZ2)  │
        └───┬─────┘                   └──┬──────┘
            │                             │
       ┌────▼────┐                   ┌───▼─────┐
       │   EKS   │                   │   EKS   │
       │  Nodes  │                   │  Nodes  │
       └─────────┘                   └─────────┘
```

---

##  Available Infrastructure

### Core Networking

| Module | Resource | AWS Cost | Purpose |
|--------|----------|----------|---------|
| **VPC** | `aws_vpc` | FREE | Isolated virtual network |
| **Subnet** | `aws_subnet` | FREE | Network segmentation (public/private) |
| **Internet Gateway** | `aws_internet_gateway` | FREE | Internet access for public subnets |
| **NAT Gateway** | `aws_nat_gateway` | $32.40/mo | Internet access for private subnets |
| **Route Table** | `aws_route_table` | FREE | Traffic routing rules |
| **Elastic IP** | `aws_eip` | FREE* | Static public IP addresses |

> *FREE when attached; $3.60/month when idle

### Security

| Module | Resource | AWS Cost | Purpose |
|--------|----------|----------|---------|
| **Security Group** | `aws_security_group` | FREE | Virtual firewall rules |
| **Security Rules** | `aws_vpc_security_group_*_rule` | FREE | Ingress/egress traffic control |

### VPC Connectivity

| Module | Resource | AWS Cost | Purpose |
|--------|----------|----------|---------|
| **Gateway Endpoint** | `aws_vpc_endpoint` (Gateway) | FREE | Private S3/DynamoDB access |
| **Interface Endpoint** | `aws_vpc_endpoint` (Interface) | $7.30/mo | Private AWS service access |

### Container Orchestration

| Module | Resource | AWS Cost | Purpose |
|--------|----------|----------|---------|
| **EKS Cluster** | `aws_eks_cluster` | $73/mo | Managed Kubernetes control plane |
| **EKS Node Group** | `aws_eks_node_group` | Variable* | Kubernetes worker nodes |

> *Node group cost = EC2 instance costs (e.g., t3.medium = $30/month)

### Complete Infrastructure Modules

```
modules/
├── vpc/                     # VPC creation
├── subnet/                  # Subnet management
├── igw/                     # Internet Gateway
├── nat_gw/                  # NAT Gateway
├── rt/                      # Route Tables
├── eip/                     # Elastic IPs
├── security_group/          # Security Groups & Rules
├── vpc_endpoint/            # VPC Endpoints
└── eks_mng/
    ├── eks_cluster/        # EKS Control Plane
    └── eks_nodegroups/     # EKS Worker Nodes
```

### Monthly Cost Estimates

**Development Environment:**
```
1 VPC                 = FREE
4 Subnets             = FREE
1 Internet Gateway    = FREE
1 NAT Gateway         = $32.40
2 Route Tables        = FREE
2 Security Groups     = FREE
1 EKS Cluster         = $73.00
2 t3.small nodes      = $30.00
─────────────────────────────
Total                 ≈ $135.40/month
```

**Production Environment (HA):**
```
1 VPC                 = FREE
9 Subnets (3 AZs)     = FREE
1 Internet Gateway    = FREE
3 NAT Gateways        = $97.20
5 Route Tables        = FREE
5 Security Groups     = FREE
3 EKS Clusters        = $219.00
10 t3.medium nodes    = $300.00
─────────────────────────────
Total                 ≈ $616.20/month
```

---

##  Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- AWS account with appropriate IAM permissions
- Basic understanding of AWS networking and Terraform

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd terraform-aws-infrastructure-framework

# Initialize Terraform
terraform init

# Create workspace for your environment
terraform workspace new dev
terraform workspace select dev
```

### Configuration

1. **Copy example configuration:**
```bash
cp examples/mini_test.tfvars terraform.tfvars
```

2. **Edit `terraform.tfvars`** with your configuration:

```hcl
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

```

### Deployment

```bash
# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply

# View outputs
terraform output
```

### Verification

```bash
# Check created resources
terraform show

# Verify VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=my_vpc"

# Verify subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"

# Check EKS cluster (if deployed)
aws eks describe-cluster --name <cluster-name>
```

---

##  Project Structure

```
.
├── README.md                          # This file 
├── CHANGELOG.md  
├── CONTRIBUTORS.md                          
├── SECURITY.md                        # Project security report 
├── LICENSE 
├── terraform.tfvars                   # User configuration (git-ignored)
├── variables.tf                       # Root variable definitions
├── outputs.tf                         # Root outputs
├── provider.tf                        # AWS provider configuration
│
├── 01_locals.tf                       # Local value transformations
├── 02_vpc.tf                          # VPC module calls
├── 03_subnet.tf                       # Subnet module calls
├── 04_rt.tf                           # Route Table module calls
├── 05_security_group.tf               # Security Group module calls
├── 06_eip.tf                          # Elastic IP module calls
├── 07_eks.tf                          # EKS Cluster module calls
├── 08_gateway.tf                      # IGW, NAT Gateway module calls
├── 09_vpc_endpoint.tf                 # VPC Endpoint module calls
│
├── backendfiles/                      # Backend configuration files
│   ├── backend.default.conf.demo
│   ├── backend.prod.conf
│   └── backend.qe.conf
│
├── docs/                              # Documentation
│   ├── GETTING_STARTED.md
│   ├── NETWORKING.md
│   ├── NETWORK_SECURITY.md
│   ├── VPC_ENDPOINTS.md
│   ├── EKS.md
│   ├── EXAMPLE.md
│   ├── TROUBLESHOOTING.md
│   └── COST_OPTIMIZATION.md
│ 
├── examples/
│    ├── all_example.tfvars
│    ├── mini_test.tfvars 
│    └── pub_test.tfvars 
│
└── modules/                           # Reusable modules
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── subnet/
    ├── rt/
    ├── igw/
    ├── nat_gw/
    ├── eip/
    ├── security_group/
    ├── vpc_endpoint/
    └── eks_mng/
        ├── eks_cluster/
        └── eks_nodegroups/

    
```

---

##  Variable Structure

### Overview: How Variables Work in This Framework

This framework uses a **three-layer variable architecture** with automatic resource ID injection and reference resolution:

```
┌─────────────────────────────────────────────────────────────────┐
│                    VARIABLE FLOW ARCHITECTURE                   │
└─────────────────────────────────────────────────────────────────┘

Layer 1: USER INPUT (terraform.tfvars)
├─ Workspace-scoped configuration
├─ Human-readable resource names (not IDs)
├─ Minimal required parameters
└─ Structure: map(map(object({...})))
           │
           ▼
Layer 2: ROOT TRANSFORMATION 
├─ Automatic ID injection
├─ Reference resolution (names → IDs)
├─ Dynamic parameter generation
├─ Workspace selection via lookup()
└─ Structure: Generated maps with injected IDs
           │
           ▼
Layer 3: MODULE CONSUMPTION (modules/*/main.tf)
├─ Receives fully-resolved parameters
├─ Creates AWS resources
├─ Returns outputs (IDs, ARNs, etc.)
└─ Structure: map(object({...})) with IDs
```

---

### Data Type Structure

#### Root Variables Pattern

**All root variables follow this structure:**

```hcl
variable "<resource>_parameters" {
  type = map(                           # Workspace level
    map(                                # Resource level
      object({                          # Configuration level
        # User-provided parameters (names, not IDs)
        <resource_name>   = string      # e.g., vpc_name, subnet_name
        <configuration>   = <type>      # Resource-specific config
        
        # Auto-injected by root (NOT provided by user)
        <resource_id>     = string      # e.g., vpc_id, subnet_ids
        
        tags = optional(map(string))
      })
    )
  )
}
```

**Structure Breakdown:**
- **First map:** Workspaces (`default`, `qe`, `prod`)
- **Second map:** Resource instances (unique identifiers)
- **Object:** Resource configuration (parameters + auto-injected IDs)

---

### Variable Transformation Pattern

#### Pattern 1: Simple ID Injection (VPC → Subnet)

```hcl
┌─────────────────────────────────────────────────────────────────┐
│ USER INPUT (terraform.tfvars)                                   │
└─────────────────────────────────────────────────────────────────┘

subnet_parameters = {
  default = {                          # ← Workspace
    my_subnet = {                      # ← Resource name
      cidr_block = "10.0.1.0/24"
      vpc_name   = "my_vpc"            # ← Human-readable reference
      az_index   = 0
    }
  }
}

          │
          │ Root Transformation
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ GENERATED PARAMETERS                                            │
└─────────────────────────────────────────────────────────────────┘

locals {
  generated_subnet_parameters = {
    for workspace, subnets in var.subnet_parameters :
    workspace => {
      for name, subnet in subnets :
      name => merge(subnet, {
        vpc_id            = local.vpc_id_by_name[subnet.vpc_name]
        # ────────────────  ──────────────────────────────────────
        #        ▲                          ▲
        #   Auto-injected            Lookup from VPC outputs
        
        availability_zone = data.aws_availability_zones.available.names[subnet.az_index]
        # ────────────────  ──────────────────────────────────────────────────────────
        #        ▲                                   ▲
        #   Auto-resolved                    AWS data source lookup
      })
    }
  }
}

          │
          │ Module Call (02_vpc.tf)
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ MODULE RECEIVES (modules/subnet)                            │
└─────────────────────────────────────────────────────────────────┘

{
  cidr_block        = "10.0.1.0/24"
  vpc_id            = "vpc-0abc123def456"      # ← Injected ID
  availability_zone = "ap-south-1a"            # ← Resolved AZ
}
```

---

#### Pattern 2: List ID Injection (Subnets → EKS Cluster)

```hcl
┌─────────────────────────────────────────────────────────────────┐
│ USER INPUT (terraform.tfvars)                                   │
└─────────────────────────────────────────────────────────────────┘

eks_clusters = {
  default = {
    my_cluster = {
      cluster_version = "1.34"
      vpc_name        = "my_vpc"               # ← VPC name
      subnet_name     = ["sub1", "sub2"]       # ← Subnet names (list)
      sg_name         = ["cluster_sg"]         # ← Security group names
    }
  }
}

          │
          │ Root Transformation (07_eks.tf)
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ GENERATED PARAMETERS                                            │
└─────────────────────────────────────────────────────────────────┘

locals {
  generated_cluster_config = {
    for workspace, clusters in var.eks_clusters :
    workspace => {
      for name, cluster in clusters :
      name => merge(cluster, {
        vpc_id = local.vpc_id_by_name[cluster.vpc_name]
        
        subnet_ids = [
          for sn in cluster.subnet_name :
          local.subnet_id_by_name[sn]          # ← Loop through list
        ]
        # ────────────  ────────────────────
        #       ▲                ▲
        #  List of IDs    Lookup each name
        
        security_group_ids = [
          for sg in cluster.sg_name :
          local.sgs_id_by_name[sg]
        ]
      })
    }
  }
}

          │
          │ Module Call
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ MODULE RECEIVES (modules/eks_mng/eks_cluster)              │
└─────────────────────────────────────────────────────────────────┘

{
  cluster_version    = "1.34"
  vpc_id             = "vpc-0abc123"
  subnet_ids         = ["subnet-111", "subnet-222"]  # ← Injected list
  security_group_ids = ["sg-0abc123"]                # ← Injected list
}
```

---

#### Pattern 3: Cross-Module Reference (SG → SG Rules)

```hcl
┌─────────────────────────────────────────────────────────────────┐
│ USER INPUT (terraform.tfvars)                                   │
└─────────────────────────────────────────────────────────────────┘

ipv4_ingress_rule = {
  default = {
    web_from_alb = {
      vpc_name                   = "my_vpc"
      sg_name                    = "web_sg"    # ← Target SG (name)
      source_security_group_name = "alb_sg"    # ← Source SG (name)
      from_port                  = 80
      protocol                   = "TCP"
    }
  }
}

          │
          │ Root Transformation (03_security_group.tf)
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ GENERATED PARAMETERS                                            │
└─────────────────────────────────────────────────────────────────┘

locals {
  generated_ipv4_ingress_parameters = {
    for workspace, rules in var.ipv4_ingress_rule :
    workspace => {
      for name, rule in rules :
      name => merge(rule, {
        security_group_id = local.sgs_id_by_name[rule.sg_name]
        # ───────────────  ───────────────────────────────────
        #         ▲                      ▲
        #   Target SG ID          Lookup target by name
        
        referenced_security_group_id = local.sgs_id_by_name[rule.source_security_group_name]
        # ──────────────────────────  ─────────────────────────────────────────────────────
        #            ▲                                    ▲
        #      Source SG ID                      Lookup source by name
      })
    }
  }
}

          │
          │ Module Call
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ MODULE RECEIVES (modules/security_group)                   │
└─────────────────────────────────────────────────────────────────┘

{
  security_group_id            = "sg-web123"   # ← Target SG ID
  referenced_security_group_id = "sg-alb456"   # ← Source SG ID
  from_port                    = 80
  protocol                     = "TCP"
}
```

---

### ID Extraction Pattern

**After module creates resources, IDs are extracted for use by other modules:**

```hcl
┌─────────────────────────────────────────────────────────────────┐
│ MODULE OUTPUT (modules/vpc/outputs.tf)                     │
└─────────────────────────────────────────────────────────────────┘

output "vpcs" {
  value = {
    for key, vpc in aws_vpc.example :
    key => {
      name       = vpc.tags["Name"]
      id         = vpc.id                      # ← VPC ID
      cidr_block = vpc.cidr_block
    }
  }
}

          │
          │ Root Extraction 
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ LOCAL VALUE EXTRACTION                                          │
└─────────────────────────────────────────────────────────────────┘

locals {
  vpc_id_by_name = {
    for name, vpc in module.chat_app_vpc.vpcs :
    name => vpc.id
    # ──  ──────
    #  ▲      ▲
    # Key   Value
  }
}

# Result:
# {
#   "my_vpc"   = "vpc-0abc123"
#   "prod_vpc" = "vpc-0def456"
# }

          │
          │ Used by other modules
          ▼

┌─────────────────────────────────────────────────────────────────┐
│ LOOKUP IN OTHER MODULES                                         │
└─────────────────────────────────────────────────────────────────┘

vpc_id = local.vpc_id_by_name[subnet.vpc_name]
         # ──────────────────  ────────────────
         #         ▲                  ▲
         #   Lookup map        User-provided name
```

---

### Complete Transformation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 END-TO-END VARIABLE FLOW                        │
└─────────────────────────────────────────────────────────────────┘

Step 1: USER CONFIGURATION
  terraform.tfvars
    - Workspace-scoped maps
    - Resource names (NOT IDs)
    - Minimal required parameters

Step 2: ROOT VARIABLE DEFINITIONS
  variables.tf
    - Type definitions
    - Workspace map structure
    - Validation rules

Step 3: MODULE OUTPUTS
  modules/*/outputs.tf
    - Export created resource IDs
    - Structured output maps

Step 4: LOCAL EXTRACTION
  01_locals.tf
    - Extract IDs from module outputs
    - Create name-to-ID lookup maps
    - Example: vpc_id_by_name, subnet_id_by_name

Step 5: LOCAL TRANSFORMATION
  01_locals.tf, 02_vpc.tf, etc.
    - Merge user config with auto-injected IDs
    - Resolve references (names → IDs)
    - Generate final module parameters

Step 6: MODULE CONSUMPTION
  modules/*/main.tf
    - Receive fully-resolved parameters
    - Create AWS resources with IDs
    - Return outputs for next iteration
```

---

### Key Concepts

#### Workspace Scoping

All variables use **workspace-based scoping**:

```hcl
variable "<resource>_parameters" {
  type = map(           # ← Workspace level
    map(                # ← Resource level
      object({...})     # ← Configuration
    )
  )
}

# Usage in root:
lookup(var.<resource>_parameters, terraform.workspace, {} )
#      ────────────────────────  ────────────────────
#              ▲                          ▲
#       Variable name              Current workspace
```

#### Two-Phase Module Calls

Some modules require **two separate calls**:

```hcl
# Phase 1: Create base resources (Security Groups)
module "security_group" {
  source = "./modules/security_group"
  security_group_parameters = lookup(...)
}

# Phase 2: Create dependent resources (Rules)
module "security_rules" {
  source            = "./modules/security_group"
  ipv4_ingress_rule = lookup(...)
  sg_name_to_id_map = local.sgs_id_by_name  # ← From Phase 1
  depends_on        = [module.security_group]
}
```

#### Dynamic vs Static Parameters

**User Provides (Static):**
- Resource names (`vpc_name`, `subnet_name`)
- Configuration values (`cidr_block`, `instance_type`)
- Tags, ports, protocols

**Framework Injects (Dynamic):**
- Resource IDs (`vpc_id`, `subnet_ids`)
- Resolved values (`availability_zone`)
- Cross-module references (`security_group_ids`)

---

### Variable Documentation

For **detailed variable schemas**, see:
- **Root variables:** [`variables.tf`](variables.tf) - Complete type definitions
- **Module variables:** `modules/*/variables.tf` - Module-specific inputs
- **Module README:** `modules/*/README.md` - Parameter descriptions and examples
- **Transformation logic:** `01_locals.tf`, `02_vpc.tf`, etc. - Dynamic generation code
- **Usage examples:** [`docs/EXAMPLES.md`](docs/EXAMPLES.md) - Real-world configurations

---

##  Documentation

### Quick Links

| Document | Description |
|----------|-------------|
| [Getting Started](docs/GETTING_STARTED.md) | Initial setup, deployment, workspace management |
| [Networking](docs/NETWORKING.md) | VPC, Subnets, Route Tables, Gateways |
| [Security](docs/NETWORK_SECURITY.md) | Security Groups, Rules, Best Practices |
| [VPC Endpoints](docs/VPC_ENDPOINTS.md) | Gateway & Interface Endpoints |
| [EKS](docs/EKS.md) | EKS Clusters & Node Groups |
| [Examples](docs/EXAMPLES.md) | Complete architecture examples |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Cost Optimization](docs/COST_OPTIMIZATION.md) | Cost-saving strategies |

### Module Documentation

Each module has comprehensive documentation:

- **Purpose & Use Cases**
- **Input Variables**
- **Output Values**
- **Configuration Examples**
- **Best Practices**
- **Troubleshooting**

See `modules/<module>/README.md` for module-specific docs.

---

##  Examples

### Example 1: Basic Development Environment

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
    }
    
    private_subnet = {
      cidr_block = "10.10.10.0/24"
      vpc_name   = "dev_vpc"
      az_index   = 0
    }
  }
}
```

**Result:** Single-AZ development VPC with public and private subnets.

### Example 2: Production Multi-AZ EKS

```hcl
# terraform.tfvars (simplified)
eks_clusters = {
  prod = {
    prod_cluster = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = ["pri_sub1", "pri_sub2", "pri_sub3"]
      sg_name                 = ["eks_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = { Environment = "prod" }
    }
  }
}

eks_nodegroups = {
  prod = {
    prod_cluster = {
      prod_nodes = {
        k8s_version    = "1.34"
        arch           = "arm64"
        min_size       = 3
        max_size       = 10
        desired_size   = 5
        instance_types = "t4g.medium"
        subnet_name    = ["pri_sub1", "pri_sub2", "pri_sub3"]
        node_security_group_names = ["eks_node_sg"]
        tags = { Tier = "application" }
      }
    }
  }
}
```

**Result:** Private EKS cluster with multi-AZ node groups using ARM instances.

### Example 3: VPC with S3 Endpoint

```hcl
vpc_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region            = "ap-south-1"
      vpc_name          = "my_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt"]
      tags = { Purpose = "S3-Private-Access" }
    }
  }
}
```

**Result:** Free S3 access from private subnets without NAT Gateway costs.

**See [docs/EXAMPLES.md](docs/EXAMPLES.md) for complete architecture examples.**

---

##  Cost Considerations

### Free Resources

- VPC, Subnets, Route Tables, Internet Gateway
- Security Groups and Rules
- Gateway Endpoints (S3, DynamoDB)
- Elastic IPs (when attached)

### Paid Resources

| Resource | Cost | Optimization Tip |
|----------|------|------------------|
| NAT Gateway | $32.40/mo + $0.045/GB | Use one per AZ (HA) or single for dev |
| EKS Cluster | $73/mo | Share clusters when possible |
| EC2 Nodes | Variable | Use ARM (t4g) for 20% savings |
| Interface Endpoints | $7.30/mo + $0.01/GB | Only for high-volume traffic |
| Idle Elastic IPs | $3.60/mo | Release immediately after use |

### Cost Optimization Strategies

1. **Development:** Single NAT Gateway, shared EKS cluster
2. **Production:** Multi-AZ NAT, separate EKS clusters per tier
3. **Use ARM instances** (t4g) instead of x86 (t3) for ~20% savings
4. **VPC Endpoints** for S3/DynamoDB (free Gateway endpoints)
5. **Cluster Autoscaler** to scale nodes based on demand

**See [docs/COST_OPTIMIZATION.md](docs/COST_OPTIMIZATION.md) for detailed strategies.**

---

##  Contributing

Contributions are welcome! Please follow these [guidelines](https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/blob/main/.github/CONTRIBUTING.md):

### How to Contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Update documentation
5. Test thoroughly
6. Submit a pull request

### Development Guidelines

- Follow existing code style
- Add tests for new features
- Update module README.md files
- Run `terraform fmt` before committing
- Add examples for new configurations

### Reporting Issues

- Use GitHub Issues
- Include Terraform version, AWS region, error messages
- Provide minimal reproducible example
- Check existing issues first

---

##  Support

### Getting Help

1. **Documentation:** Start with [docs/](https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/tree/main/docs) folder
2. **Module Docs:** Check `modules/<module>/README.md`
3. **Examples:** See [docs/EXAMPLES.md](docs/EXAMPLES.md)
4. **Troubleshooting:** Refer to [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
5. **Issues:** Submit a GitHub issue

### Useful Commands

```bash
# Workspace management
terraform workspace list
terraform workspace select <workspace>
terraform workspace new <workspace>

# Validation
terraform validate
terraform fmt -recursive
terraform plan

# Inspection
terraform state list
terraform show
terraform output

# Cleanup
terraform destroy
```

---

## 📄 License

This project is licensed under the Apache-2.0 license - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- AWS for comprehensive cloud services
- HashiCorp for Terraform
- Open-source community for best practices

---

## 📈 Roadmap

### Current Version (1.0)
- ✅ VPC, Subnets, Gateways(NAT,IGW), RoutTable, EIP
- ✅ Security Groups
- ✅ VPC Endpoints
- ✅ EKS Clusters & Node Groups

---

## 📊 Project Status

- **Project Owner:** [rajarshigit2441139][mygithub]
- **Status:** Active Development
- **Stability:** Production-Ready (core modules)
- **Maintenance:** Actively Maintained
- **Last Updated:** January 2026

---

**Built with ❤️ by the Infrastructure Team**

**Questions? Issues? Feedback?**
- Read Documents
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]



[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139