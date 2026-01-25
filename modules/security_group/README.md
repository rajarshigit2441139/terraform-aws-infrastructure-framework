# Security Group Module

## Overview

This module creates AWS Security Groups and their associated ingress/egress rules. Security Groups act as virtual firewalls controlling inbound and outbound traffic for AWS resources like EC2 instances, RDS databases, and EKS clusters.

## Module Purpose

- Creates security groups within VPCs
- Manages ingress (inbound) and egress (outbound) rules
- Supports both IPv4 and IPv6 traffic rules
- Enables security group-to-security group references
- Supports CIDR-based and referenced security group rules
- Provides outputs for resource linking in parent modules

## Module Location

```
modules/security_group/
├── main.tf          # Security group and rule resources
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **4 types of resources**:

1. **Security Groups** - `aws_security_group`
2. **IPv4 Ingress Rules** - `aws_vpc_security_group_ingress_rule`
3. **IPv4 Egress Rules** - `aws_vpc_security_group_egress_rule`
4. **IPv6 Ingress/Egress Rules** - `aws_vpc_security_group_ingress_rule` / `egress_rule`

### Security Group Definition

```hcl
resource "aws_security_group" "sg_module" {
  for_each = var.security_group_parameters
  name     = each.value.name
  vpc_id   = each.value.vpc_id

  tags = merge(each.value.tags, { Name : each.key })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}
```

### Ingress Rule Definition (IPv4)

```hcl
resource "aws_vpc_security_group_ingress_rule" "ipv4_ingress_example" {
  for_each = var.ipv4_ingress_rule != {} ? var.ipv4_ingress_rule : {}

  security_group_id = try(lookup(var.sg_name_to_id_map, each.value.sg_name), each.value.security_group_id)
  
  referenced_security_group_id = try(
    lookup(var.sg_name_to_id_map, each.value.source_security_group_name), 
    try(each.value.referenced_security_group_id, null)
  )
  
  cidr_ipv4   = try(each.value.cidr_ipv4, null)
  ip_protocol = each.value.protocol
  
  from_port = each.value.protocol == "-1" ? null : try(each.value.from_port, null)
  to_port   = each.value.protocol == "-1" ? null : try(each.value.to_port, null)
}
```

### Egress Rule Definition (IPv4)

```hcl
resource "aws_vpc_security_group_egress_rule" "ipv4_egress_example" {
  for_each = var.ipv4_egress_rule != {} ? var.ipv4_egress_rule : {}

  security_group_id = try(lookup(var.sg_name_to_id_map, each.value.sg_name), each.value.security_group_id)
  
  referenced_security_group_id = try(
    lookup(var.sg_name_to_id_map, each.value.source_security_group_name), 
    try(each.value.referenced_security_group_id, null)
  )
  
  cidr_ipv4   = try(each.value.cidr_ipv4, null)
  ip_protocol = each.value.protocol
  
  from_port = each.value.protocol == "-1" ? null : try(each.value.from_port, null)
  to_port   = each.value.protocol == "-1" ? null : try(each.value.to_port, null)
}
```

## Inputs

### 1. `security_group_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** `{}`

Map of security group configurations.

#### Object Structure

```hcl
{
  name     = string                      # REQUIRED
  vpc_name = string                      # REQUIRED (for reference)
  vpc_id   = string                      # REQUIRED (auto-injected)
  tags     = optional(map(string), {})   # OPTIONAL
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `name` | string | ✅ Yes | - | Security group name (must be unique within VPC) |
| `vpc_name` | string | ✅ Yes* | - | VPC key reference (converted to vpc_id by root) |
| `vpc_id` | string | ✅ Yes** | - | VPC ID (auto-injected by root module) |
| `tags` | map(string) | ❌ No | `{}` | Additional tags for the security group |

> **Note:** `vpc_id` is **auto-injected** by the parent module from `vpc_name`.

---

### 2. `ipv4_ingress_rule`

**Type:** `map(object)`  
**Required:** No  
**Default:** `{}`

Map of IPv4 ingress (inbound) rule configurations.

#### Object Structure

```hcl
{
  vpc_name                     = string              # REQUIRED (for reference)
  sg_name                      = string              # REQUIRED (target SG)
  security_group_id            = string              # REQUIRED (auto-injected)
  from_port                    = number              # REQUIRED (unless protocol = "-1")
  to_port                      = number              # REQUIRED (unless protocol = "-1")
  protocol                     = string              # REQUIRED
  cidr_ipv4                    = optional(string)    # OPTIONAL
  source_security_group_name   = optional(string)    # OPTIONAL
  referenced_security_group_id = optional(string)    # OPTIONAL (auto-injected)
}
```

#### Parameter Details

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `vpc_name` | string | ✅ Yes | VPC key reference |
| `sg_name` | string | ✅ Yes | Target security group key |
| `security_group_id` | string | ✅ Yes* | Target SG ID (auto-injected from sg_name) |
| `from_port` | number | ✅ Yes** | Start of port range (null if protocol = "-1") |
| `to_port` | number | ✅ Yes** | End of port range (null if protocol = "-1") |
| `protocol` | string | ✅ Yes | IP protocol: "TCP", "UDP", "ICMP", "-1" (all) |
| `cidr_ipv4` | string | ❌ No | IPv4 CIDR block (e.g., "0.0.0.0/0" or VPC CIDR) |
| `source_security_group_name` | string | ❌ No | Source SG key (for SG-to-SG rules) |
| `referenced_security_group_id` | string | ❌ No* | Source SG ID (auto-injected from source_security_group_name) |

> **Rule:** Either `cidr_ipv4` OR `source_security_group_name` must be provided, not both.

---

### 3. `ipv4_egress_rule`

**Type:** `map(object)`  
**Required:** No  
**Default:** `{}`

Map of IPv4 egress (outbound) rule configurations.

#### Object Structure

```hcl
{
  vpc_name                     = string              # REQUIRED (for reference)
  sg_name                      = string              # REQUIRED (source SG)
  security_group_id            = string              # REQUIRED (auto-injected)
  protocol                     = string              # REQUIRED
  cidr_ipv4                    = optional(string)    # OPTIONAL
  source_security_group_name   = optional(string)    # OPTIONAL
  referenced_security_group_id = optional(string)    # OPTIONAL (auto-injected)
}
```

#### Parameter Details

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `vpc_name` | string | ✅ Yes | VPC key reference |
| `sg_name` | string | ✅ Yes | Source security group key |
| `security_group_id` | string | ✅ Yes* | Source SG ID (auto-injected) |
| `protocol` | string | ✅ Yes | IP protocol: "TCP", "UDP", "ICMP", "-1" (all) |
| `cidr_ipv4` | string | ❌ No | IPv4 CIDR block |
| `source_security_group_name` | string | ❌ No | Destination SG key (for SG-to-SG rules) |
| `referenced_security_group_id` | string | ❌ No* | Destination SG ID (auto-injected) |

> **Common Pattern:** Most egress rules use `protocol = "-1"` and `cidr_ipv4 = "0.0.0.0/0"` (allow all outbound).

---

### 4. `sg_name_to_id_map`

**Type:** `map(string)`  
**Required:** No  
**Default:** `{}`

Map from security group keys to their AWS IDs. Used for resolving SG references in rules.

**Example:**
```hcl
{
  "web_sg"  = "sg-0abc123def456"
  "app_sg"  = "sg-0def456abc789"
  "db_sg"   = "sg-0ghi789jkl012"
}
```

> **Note:** This is automatically provided by the parent module from `local.sgs_id_by_name`.

---

### 5. `ipv6_ingress_rule` & `ipv6_egress_rule`

**Type:** `map(object)`  
**Required:** No  
**Default:** `{}`

IPv6 rules follow similar structure to IPv4 but use `cidr_ipv6` instead of `cidr_ipv4`.

## Outputs

### `sgs`

**Type:** `map(object)`  
**Description:** Map of security group outputs indexed by SG name (key)

#### Output Structure

```hcl
{
  "<sg_key>" = {
    name = string  # Security group name (same as key)
    id   = string  # Security group ID (sg-xxxxx)
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | SG name from tags | "web_sg" |
| `id` | string | AWS Security Group ID | "sg-0abc123def456" |

## Usage in Root Module

### Called From

`03_security_group.tf` in the root module

### Module Calls

The root module makes **TWO separate calls**:

1. **Create Security Groups**
2. **Create Security Group Rules**

#### 1. Create Security Groups

```hcl
module "chat_app_security_group" {
  source                    = "./modules/security_group"
  security_group_parameters = lookup(local.generated_sg_parameters, terraform.workspace, {} )
  depends_on                = [module.chat_app_vpc]
}
```

#### 2. Create Security Group Rules

```hcl
module "chat_app_security_rules" {
  source            = "./modules/security_group"
  ipv4_ingress_rule = lookup(local.generated_ipv4_ingress_parameters, terraform.workspace, {} )
  ipv4_egress_rule  = lookup(local.generated_ipv4_egress_parameters, terraform.workspace, {} )
  sg_name_to_id_map = local.sgs_id_by_name
  depends_on        = [module.chat_app_security_group]
}
```

### Dynamic Parameter Generation

#### Security Groups with VPC ID Injection

```hcl
locals {
  generated_sg_parameters = {
    for workspace, sgs in var.security_group_parameters :
    workspace => {
      for name, sg in sgs :
      name => merge(
        sg,
        { vpc_id = local.vpc_id_by_name[sg.vpc_name] }
      )
    }
  }
}
```

#### Ingress Rules with SG ID and CIDR Resolution

```hcl
locals {
  generated_ipv4_ingress_parameters = {
    for workspace, ings in var.ipv4_ingress_rule :
    workspace => {
      for name, ing in ings :
      name => (
        # CASE 1: SG → SG
        try(ing.source_security_group_name, null) != null
        ?
        merge(
          ing,
          {
            referenced_security_group_id = local.sgs_id_by_name[ing.source_security_group_name]
            cidr_ipv4                    = null
          }
        )
        :
        # CASE 2: CIDR rule (explicit cidr_ipv4 or fallback to VPC CIDR)
        merge(
          ing,
          {
            cidr_ipv4 = coalesce(
              try(ing.cidr_ipv4, null),
              lookup(local.vpc_cidr_by_name_from_var, ing.vpc_name, null)
            )
          }
        )
      )
    }
  }
}
```

#### Egress Rules with Similar Logic

```hcl
locals {
  generated_ipv4_egress_parameters = {
    for workspace, egrs in var.ipv4_egress_rule :
    workspace => {
      for name, egr in egrs :
      name => (
        try(egr.source_security_group_name, null) != null
        ?
        # SG → SG egress rule
        merge(
          egr,
          {
            referenced_security_group_id = local.sgs_id_by_name[egr.source_security_group_name]
            cidr_ipv4                    = null
          }
        )
        :
        # CIDR egress rule
        merge(
          egr,
          {
            cidr_ipv4 = try(
              egr.cidr_ipv4,
              lookup(local.vpc_cidr_by_name_from_var, egr.vpc_name, null)
            )
          }
        )
      )
    }
  }
}
```

## Configuration Examples

### Example 1: Basic Web Security Group

```hcl
# Security Groups
security_group_parameters = {
  default = {
    web_sg = {
      name     = "web-security-group"
      vpc_name = "my_vpc"
      tags = {
        Tier = "web"
      }
    }
  }
}

# Ingress Rules
ipv4_ingress_rule = {
  default = {
    web_http = {
      vpc_name  = "my_vpc"
      sg_name   = "web_sg"
      from_port = 80
      to_port   = 80
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"  # Allow from internet
    }
    
    web_https = {
      vpc_name  = "my_vpc"
      sg_name   = "web_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"  # Allow from internet
    }
  }
}

# Egress Rules
ipv4_egress_rule = {
  default = {
    web_egress = {
      vpc_name  = "my_vpc"
      sg_name   = "web_sg"
      protocol  = "-1"           # All protocols
      cidr_ipv4 = "0.0.0.0/0"    # Allow to anywhere
    }
  }
}
```

### Example 2: Three-Tier Architecture (SG-to-SG References)

```hcl
# Security Groups
security_group_parameters = {
  default = {
    web_sg = {
      name     = "web-sg"
      vpc_name = "app_vpc"
      tags = { Tier = "web" }
    }
    
    app_sg = {
      name     = "app-sg"
      vpc_name = "app_vpc"
      tags = { Tier = "application" }
    }
    
    db_sg = {
      name     = "db-sg"
      vpc_name = "app_vpc"
      tags = { Tier = "database" }
    }
  }
}

# Ingress Rules
ipv4_ingress_rule = {
  default = {
    # Web tier: Accept from internet
    web_http = {
      vpc_name  = "app_vpc"
      sg_name   = "web_sg"
      from_port = 80
      to_port   = 80
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    web_https = {
      vpc_name  = "app_vpc"
      sg_name   = "web_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    # App tier: Accept from web tier only
    app_from_web = {
      vpc_name                   = "app_vpc"
      sg_name                    = "app_sg"
      from_port                  = 8080
      to_port                    = 8080
      protocol                   = "TCP"
      source_security_group_name = "web_sg"  # SG-to-SG reference
    }
    
    # DB tier: Accept from app tier only
    db_from_app = {
      vpc_name                   = "app_vpc"
      sg_name                    = "db_sg"
      from_port                  = 5432
      to_port                    = 5432
      protocol                   = "TCP"
      source_security_group_name = "app_sg"  # SG-to-SG reference
    }
  }
}

# Egress Rules
ipv4_egress_rule = {
  default = {
    web_egress = {
      vpc_name  = "app_vpc"
      sg_name   = "web_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    app_egress = {
      vpc_name  = "app_vpc"
      sg_name   = "app_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    db_egress = {
      vpc_name  = "app_vpc"
      sg_name   = "db_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

### Example 3: EKS Cluster Security Groups

```hcl
# Security Groups
security_group_parameters = {
  default = {
    eks_cluster_sg = {
      name     = "eks-cluster-sg"
      vpc_name = "eks_vpc"
      tags = { Purpose = "EKS-Control-Plane" }
    }
    
    eks_node_sg = {
      name     = "eks-node-sg"
      vpc_name = "eks_vpc"
      tags = { Purpose = "EKS-Worker-Nodes" }
    }
  }
}

# Ingress Rules
ipv4_ingress_rule = {
  default = {
    # Cluster accepts HTTPS from nodes
    cluster_from_nodes = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_cluster_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "eks_node_sg"
    }
    
    # Nodes accept kubelet traffic from cluster
    node_kubelet_from_cluster = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      from_port                  = 10250
      to_port                    = 10250
      protocol                   = "TCP"
      source_security_group_name = "eks_cluster_sg"
    }
    
    # Nodes accept HTTPS from cluster
    node_https_from_cluster = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "eks_cluster_sg"
    }
    
    # Nodes accept NodePort range from cluster
    node_nodeport_from_cluster = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      from_port                  = 30000
      to_port                    = 32767
      protocol                   = "TCP"
      source_security_group_name = "eks_cluster_sg"
    }
    
    # Nodes accept all traffic from themselves
    node_self = {
      vpc_name                   = "eks_vpc"
      sg_name                    = "eks_node_sg"
      protocol                   = "-1"
      source_security_group_name = "eks_node_sg"
    }
  }
}

# Egress Rules
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
```

### Example 4: Multi-Environment Security Groups

```hcl
security_group_parameters = {
  # Development
  default = {
    dev_app_sg = {
      name     = "dev-app-sg"
      vpc_name = "dev_vpc"
      tags = { Environment = "dev" }
    }
  }
  
  # Production
  prod = {
    prod_app_sg = {
      name     = "prod-app-sg"
      vpc_name = "prod_vpc"
      tags = { Environment = "prod" }
    }
  }
}

ipv4_ingress_rule = {
  # Dev: Allow from specific IPs
  default = {
    dev_app_https = {
      vpc_name  = "dev_vpc"
      sg_name   = "dev_app_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "10.0.0.0/8"  # Internal only
    }
  }
  
  # Prod: Allow from anywhere
  prod = {
    prod_app_https = {
      vpc_name  = "prod_vpc"
      sg_name   = "prod_app_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"  # Public access
    }
  }
}
```

## Protocol Reference

### Common Protocols

| Protocol | Value | Description | Use Case |
|----------|-------|-------------|----------|
| TCP | `"TCP"` | Transmission Control Protocol | HTTP, HTTPS, SSH, RDP, Databases |
| UDP | `"UDP"` | User Datagram Protocol | DNS, NTP, VoIP |
| ICMP | `"ICMP"` | Internet Control Message Protocol | Ping, traceroute |
| All | `"-1"` | All protocols | Typically for egress rules |

### Common Port Numbers

| Service | Protocol | Port(s) | Usage |
|---------|----------|---------|-------|
| HTTP | TCP | 80 | Web traffic |
| HTTPS | TCP | 443 | Secure web traffic |
| SSH | TCP | 22 | Secure shell |
| RDP | TCP | 3389 | Remote Desktop |
| MySQL | TCP | 3306 | MySQL database |
| PostgreSQL | TCP | 5432 | PostgreSQL database |
| MongoDB | TCP | 27017 | MongoDB database |
| Redis | TCP | 6379 | Redis cache |
| Kubernetes API | TCP | 6443 | Kubernetes API server |
| Kubelet | TCP | 10250 | Kubernetes kubelet |
| NodePort | TCP | 30000-32767 | Kubernetes NodePort services |

## Rule Types

### 1. CIDR-Based Rules

Allow traffic from/to specific IP ranges:

```hcl
{
  vpc_name  = "my_vpc"
  sg_name   = "my_sg"
  from_port = 443
  to_port   = 443
  protocol  = "TCP"
  cidr_ipv4 = "10.0.0.0/16"  # Specific CIDR
}
```

**Common CIDR blocks:**
- `0.0.0.0/0` - All IPv4 addresses (internet)
- `10.0.0.0/8` - Private Class A
- `172.16.0.0/12` - Private Class B
- `192.168.0.0/16` - Private Class C
- VPC CIDR - Traffic within VPC

### 2. Security Group Reference Rules

Allow traffic from/to other security groups:

```hcl
{
  vpc_name                   = "my_vpc"
  sg_name                    = "target_sg"
  from_port                  = 443
  to_port                    = 443
  protocol                   = "TCP"
  source_security_group_name = "source_sg"  # Reference by name
}
```

**Benefits:**
- ✅ Dynamic - works even if source instances change
- ✅ Secure - no need to know IP addresses
- ✅ Scalable - automatically applies to all instances in source SG

### 3. Self-Referencing Rules

Allow traffic between instances in the same security group:

```hcl
{
  vpc_name                   = "my_vpc"
  sg_name                    = "cluster_sg"
  protocol                   = "-1"                    # All protocols
  source_security_group_name = "cluster_sg"           # Same as sg_name
}
```

**Use case:** Cluster nodes need to communicate with each other

### 4. All-Protocols Rules

Common for egress rules:

```hcl
{
  vpc_name  = "my_vpc"
  sg_name   = "my_sg"
  protocol  = "-1"           # All protocols
  cidr_ipv4 = "0.0.0.0/0"    # All destinations
}
```

**Note:** When `protocol = "-1"`, `from_port` and `to_port` are automatically set to `null`.

## Lifecycle Management

### Prevent Destroy

Default: `prevent_destroy = false`

To protect critical security groups:

```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes  = [tags]
}
```

### Ignore Changes

Tags are ignored by default to prevent unnecessary updates:

```hcl
ignore_changes = [tags]
```

## Dependencies

### This Module Depends On
- ✅ **VPC Module** - Must create VPC before security groups
- ✅ **Security Group IDs** - Rules depend on security groups being created first

### Modules That Depend On This
- EKS Clusters - Require security group IDs
- EKS Node Groups - Require security group IDs
- VPC Endpoints (Interface type) - Require security group IDs
- EC2 Instances - Require security group IDs
- RDS Databases - Require security group IDs
- Load Balancers - Require security group IDs

## Output Usage by Other Modules

### In EKS Cluster

```hcl
# 07_eks.tf
locals {
  generated_eks_cluster_parameters = {
    for workspace, clusters in var.eks_clusters :
    workspace => {
      for name, cluster in clusters :
      name => merge(
        cluster,
        {
          security_group_ids = [
            for sg_name in cluster.sg_name :
            local.sgs_id_by_name[sg_name]
          ]
        }
      )
    }
  }
}
```

### In VPC Endpoints

```hcl
# 06_vpc_endpoint.tf
locals {
  generated_vpc_endpoint_parameters = {
    for workspace, endpoints in var.vpc_endpoint_parameters :
    workspace => {
      for name, ep in endpoints :
      name => merge(
        ep,
        {
          security_group_ids = [
            for sg in coalesce(ep.security_group_names, []) :
            lookup(local.sgs_id_by_name, sg)
          ]
        }
      )
    }
  }
}
```

## Best Practices

### Security Group Design

✅ **Do:**
- Create separate SGs for each tier (web, app, db)
- Use descriptive names: `web-sg`, `app-sg`, `db-sg`
- Start with deny-all (AWS default) and add specific rules
- Use SG-to-SG references instead of CIDR when possible
- Document the purpose of each rule
- Keep production SGs restrictive

❌ **Don't:**
- Use a single SG for all resources
- Open all ports (`0-65535`)
- Use `0.0.0.0/0` for ingress unless necessary
- Create circular SG dependencies
- Mix purposes in a single SG

### Rule Management

✅ **Do:**
- Use meaningful rule keys: `web_http`, `app_from_web`
- Group related rules together
- Use protocol `-1` only for egress (outbound)
- Specify exact ports when possible
- Use SG references for internal traffic

❌ **Don't:**
- Use generic rule names: `rule1`, `rule2`
- Allow all protocols for ingress
- Use overly broad CIDR ranges
- Forget to add egress rules

### Egress Rules

✅ **Do:**
- Allow all egress by default (`protocol = "-1"`, `cidr_ipv4 = "0.0.0.0/0"`)
- Restrict egress for high-security environments
- Document any egress restrictions

❌ **Don't:**
- Forget egress rules (resources won't be able to respond)
- Over-restrict egress without careful planning

### Multi-Tier Architecture

✅ **Do:**
```
Internet → [Web SG] → [App SG] → [DB SG]
```
- Each tier only accepts from previous tier
- Database tier never directly accessible from internet
- Use SG-to-SG references between tiers

❌ **Don't:**
```
Internet → [Single SG for all tiers]
```
- Single SG for all resources
- Allow direct database access from internet

## Common Patterns

### Pattern 1: Load Balancer → Web → App → Database

```hcl
# LB SG: Accept from internet
lb_sg_https = {
  sg_name   = "lb_sg"
  from_port = 443
  protocol  = "TCP"
  cidr_ipv4 = "0.0.0.0/0"
}

# Web SG: Accept from LB only
web_from_lb = {
  sg_name                    = "web_sg"
  from_port                  = 8080
  protocol                   = "TCP"
  source_security_group_name = "lb_sg"
}

# App SG: Accept from Web only
app_from_web = {
  sg_name                    = "app_sg"
  from_port                  = 8080
  protocol                   = "TCP"
  source_security_group_name = "web_sg"
}

# DB SG: Accept from App only
db_from_app = {
  sg_name                    = "db_sg"
  from_port                  = 5432
  protocol                   = "TCP"
  source_security_group_name = "app_sg"
}
```

### Pattern 2: Bastion Host Access

```hcl
# Bastion SG: Accept SSH from specific IPs
bastion_ssh = {
  sg_name   = "bastion_sg"
  from_port = 22
  protocol  = "TCP"
  cidr_ipv4 = "203.0.113.0/24"  # Your office IP range
}

# Private instance SG: Accept SSH from bastion only
private_ssh_from_bastion = {
  sg_name                    = "private_sg"
  from_port                  = 22
  protocol                   = "TCP"
  source_security_group_name = "bastion_sg"
}
```

### Pattern 3: Microservices (All-to-All within VPC)

```hcl
# Service SG: Accept all from VPC CIDR
service_from_vpc = {
  sg_name   = "service_sg"
  protocol  = "-1"
  cidr_ipv4 = "10.0.0.0/16"  # Entire VPC
}
```

### Pattern 4: Database Replication

```hcl
# Primary DB accepts from replica
db_primary_from_replica = {
  sg_name                    = "db_primary_sg"
  from_port                  = 5432
  protocol                   = "TCP"
  source_security_group_name = "db_replica_sg"
}

# Replica DB accepts from primary
db_replica_from_primary = {
  sg_name                    = "db_replica_sg"
  from_port                  = 5432
  protocol                   = "TCP"
  source_security_group_name = "db_primary_sg"
}
```

## Validation

### After Creation

```bash
# Verify security group creation
terraform output sg_ids

# Check security group details
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=web_sg"

# List all rules for a security group
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-xxxxx"

# Verify ingress rules
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-xxxxx" "Name=is-egress,Values=false"

# Verify egress rules
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-xxxxx" "Name=is-egress,Values=true"
```

## Troubleshooting

### Issue: Security Group Not Created

**Symptoms:**
```
Error: Error creating Security Group: InvalidGroup.Duplicate
```

**Solution:**
- Security group names must be unique within a VPC
- Check for existing SGs with same name
- Use different names or delete existing SG

### Issue: Rule References Invalid Security Group

**Symptoms:**
```
Error: InvalidGroup.NotFound
```

**Solution:**
- Ensure `source_security_group_name` matches exactly with SG key
- Verify both SGs are in the same workspace
- Check that referenced SG was created successfully
- Ensure proper `depends_on` between modules

### Issue: CIDR Block Not Found

**Symptoms:**
```
Error: Neither cidr_ipv4 nor referenced_security_group_id provided
```

**Solution:**
- Provide either `cidr_ipv4` OR `source_security_group_name`
- Check VPC CIDR fallback is working
- Verify `vpc_name` is correct in rule definition

### Issue: Invalid Port Range

**Symptoms:**
```
Error: Invalid value for from_port/to_port
```

**Solution:**
- Port range: 0-65535
- `from_port` must be ≤ `to_port`
- Use `protocol = "-1"` for all ports (omits from_port/to_port)
- ICMP uses special port numbers (see AWS docs)

### Issue: Too Many Rules

**Symptoms:**
```
Error: You have reached the limit for number of rules
```

**Solution:**
- Default limit: 60 rules per security group (ingress + egress)
- Request quota increase via AWS Service Quotas
- Consolidate rules using CIDR ranges
- Split into multiple security groups

### Issue: Circular Dependency

**Symptoms:**
```
Error: Cycle: module.chat_app_security_group → module.chat_app_security_rules
```

**Solution:**
- This is expected! The framework handles it correctly
- Security groups are created first
- Rules are created second with `depends_on`
- Ensure you're making two separate module calls

### Issue: VPC ID Not Resolved

**Symptoms:**
```
Error: Invalid VPC ID
```

**Solution:**
- Verify `vpc_name` in security group definition matches VPC key
- Check VPC was created: `terraform output vpc_ids`
- Ensure you're in correct workspace
- Check `local.vpc_id_by_name` has the VPC

## Security Considerations

### Principle of Least Privilege

✅ **Good:**
```hcl
# Allow only specific port from specific source
{
  from_port                  = 443
  to_port                    = 443
  protocol                   = "TCP"
  source_security_group_name = "web_sg"
}
```

❌ **Bad:**
```hcl
# Allow all ports from anywhere
{
  protocol  = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}
```

### Database Security

✅ **Good:**
```hcl
# Database only accepts from app tier
{
  sg_name                    = "db_sg"
  from_port                  = 5432
  to_port                    = 5432
  protocol                   = "TCP"
  source_security_group_name = "app_sg"
}
```

❌ **Bad:**
```hcl
# Database accepts from internet
{
  sg_name   = "db_sg"
  from_port = 5432
  protocol  = "TCP"
  cidr_ipv4 = "0.0.0.0/0"  # NEVER DO THIS!
}
```

### SSH Access

✅ **Good:**
```hcl
# SSH only from bastion or specific IPs
{
  sg_name   = "app_sg"
  from_port = 22
  protocol  = "TCP"
  cidr_ipv4 = "203.0.113.0/24"  # Office IP only
}
```

❌ **Bad:**
```hcl
# SSH from anywhere
{
  sg_name   = "app_sg"
  from_port = 22
  protocol  = "TCP"
  cidr_ipv4 = "0.0.0.0/0"  # Security risk!
}
```

### Egress Restrictions

For highly secure environments:

```hcl
# Allow only HTTPS to specific endpoints
app_egress_https = {
  sg_name   = "app_sg"
  from_port = 443
  to_port   = 443
  protocol  = "TCP"
  cidr_ipv4 = "0.0.0.0/0"
}

# Allow only database connection
app_egress_db = {
  sg_name                    = "app_sg"
  from_port                  = 5432
  to_port                    = 5432
  protocol                   = "TCP"
  source_security_group_name = "db_sg"
}
```

## Performance Considerations

### Rule Evaluation

- Security groups are **stateful** - return traffic is automatically allowed
- Rules are evaluated as a **group** (not in order)
- Maximum: 60 rules per security group (default quota)
- No performance impact from number of rules (evaluated in parallel)

### Stateful vs Stateless

**Security Groups (Stateful):**
```hcl
# Only need ingress rule
ingress_https = {
  from_port = 443
  protocol  = "TCP"
  cidr_ipv4 = "0.0.0.0/0"
}
# Response traffic automatically allowed
```

**Network ACLs (Stateless - not covered in this module):**
```
# Need both ingress and egress rules
# Not applicable to this module
```

## Naming Conventions

### Security Group Names

✅ **Good:**
```
web-sg
app-sg
db-sg
eks-cluster-sg
eks-node-sg
bastion-sg
```

❌ **Bad:**
```
sg1
security_group_2
my-group
```

### Rule Names

✅ **Good:**
```
web_http
web_https
app_from_web
db_from_app
node_kubelet_from_cluster
bastion_ssh_from_office
```

❌ **Bad:**
```
rule1
ingress_rule
my_rule
```

## IPv6 Support

This module supports IPv6 rules (though less commonly used):

```hcl
ipv6_ingress_rule = {
  default = {
    web_ipv6 = {
      security_group_id = "sg-xxxxx"
      from_port         = 443
      to_port           = 443
      protocol          = "TCP"
      cidr_ipv6         = "::/0"  # All IPv6 addresses
    }
  }
}
```

**Note:** Most configurations use IPv4 only.

## Tagging Strategy

### Automatic Tags

```hcl
tags = merge(each.value.tags, {
  Name : each.key
})
```

### Recommended Tags

```hcl
tags = {
  Name        = "Automatic (from key)"
  Environment = "dev|qe|prod"
  Tier        = "web|app|db"
  Purpose     = "eks-cluster|rds|ec2"
  ManagedBy   = "terraform"
  Owner       = "team-name"
  CostCenter  = "cost-center-id"
}
```

## AWS Resource Reference

- **Resource Type:** `aws_security_group`, `aws_vpc_security_group_ingress_rule`, `aws_vpc_security_group_egress_rule`
- **AWS Documentation:** https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html
- **Terraform Documentation:** 
  - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
  - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
  - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule

## Advanced Configuration

### CIDR Fallback to VPC CIDR

If you omit `cidr_ipv4` in a rule, the framework automatically uses the VPC's CIDR block:

```hcl
# User provides (no cidr_ipv4)
ipv4_ingress_rule = {
  default = {
    app_from_vpc = {
      vpc_name  = "my_vpc"  # VPC with CIDR 10.0.0.0/16
      sg_name   = "app_sg"
      from_port = 8080
      to_port   = 8080
      protocol  = "TCP"
      # cidr_ipv4 omitted
    }
  }
}

# Framework injects (in 03_security_group.tf)
cidr_ipv4 = "10.0.0.0/16"  # Automatically uses VPC CIDR
```

**Use case:** Allow traffic from anywhere within the VPC without hardcoding CIDR.

### Dynamic SG Reference Resolution

The framework resolves security group names to IDs dynamically:

**In `03_security_group.tf`:**
```hcl
# Extract SG IDs
locals {
  sgs_id_by_name = { 
    for name, sg in module.chat_app_security_group.sgs : name => sg.id 
  }
}

# Pass to rules module
module "chat_app_security_rules" {
  source            = "./modules/security_group"
  sg_name_to_id_map = local.sgs_id_by_name  # <-- SG name-to-ID mapping
  # ...
}
```

**In module (main.tf):**
```hcl
# Resolve sg_name to security_group_id
security_group_id = try(
  lookup(var.sg_name_to_id_map, each.value.sg_name), 
  each.value.security_group_id
)

# Resolve source_security_group_name to referenced_security_group_id
referenced_security_group_id = try(
  lookup(var.sg_name_to_id_map, each.value.source_security_group_name), 
  try(each.value.referenced_security_group_id, null)
)
```

### Protocol "-1" Handling

When `protocol = "-1"` (all protocols), ports are automatically set to `null`:

```hcl
from_port = each.value.protocol == "-1" ? null : try(each.value.from_port, null)
to_port   = each.value.protocol == "-1" ? null : try(each.value.to_port, null)
```

**Why:** AWS doesn't allow port specifications with protocol "-1".

## Migration Guide

### From Inline Rules to Separate Rules

**Old approach (inline rules - not used in this framework):**
```hcl
resource "aws_security_group" "sg_module" {
  name   = "my-sg"
  vpc_id = vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**This framework (separate rule resources):**
```hcl
# Security Group (no inline rules)
resource "aws_security_group" "sg_module" {
  name   = each.value.name
  vpc_id = each.value.vpc_id
}

# Separate rule resource
resource "aws_vpc_security_group_ingress_rule" "ipv4_ingress_example" {
  security_group_id = security_group_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}
```

**Benefits:**
- ✅ Can manage rules independently
- ✅ Easier to add/remove rules without recreating SG
- ✅ Better state management
- ✅ Supports complex rule scenarios

### From Hardcoded IDs to Name References

**Before:**
```hcl
ingress {
  security_groups = ["sg-0abc123def456"]  # Hardcoded ID
}
```

**With this framework:**
```hcl
{
  source_security_group_name = "web_sg"  # Name reference
}
```

**Benefits:**
- ✅ More readable configuration
- ✅ No manual ID lookups
- ✅ Works across environments
- ✅ Automatic ID resolution

## Real-World Example: Complete E-Commerce Application

```hcl
# =============================================================================
# Security Groups
# =============================================================================
security_group_parameters = {
  default = {
    # Internet-facing load balancer
    alb_sg = {
      name     = "ecommerce-alb-sg"
      vpc_name = "ecommerce_vpc"
      tags = { Tier = "load-balancer", Public = "true" }
    }
    
    # Web tier (frontend)
    web_sg = {
      name     = "ecommerce-web-sg"
      vpc_name = "ecommerce_vpc"
      tags = { Tier = "web" }
    }
    
    # API tier (backend)
    api_sg = {
      name     = "ecommerce-api-sg"
      vpc_name = "ecommerce_vpc"
      tags = { Tier = "api" }
    }
    
    # Database tier
    db_sg = {
      name     = "ecommerce-db-sg"
      vpc_name = "ecommerce_vpc"
      tags = { Tier = "database" }
    }
    
    # Redis cache
    cache_sg = {
      name     = "ecommerce-cache-sg"
      vpc_name = "ecommerce_vpc"
      tags = { Tier = "cache" }
    }
    
    # Admin bastion
    bastion_sg = {
      name     = "ecommerce-bastion-sg"
      vpc_name = "ecommerce_vpc"
      tags = { Purpose = "bastion" }
    }
  }
}

# =============================================================================
# Ingress Rules
# =============================================================================
ipv4_ingress_rule = {
  default = {
    # ALB: Accept HTTPS from internet
    alb_https = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "alb_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    alb_http = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "alb_sg"
      from_port = 80
      to_port   = 80
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    # Web: Accept from ALB only
    web_from_alb = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "web_sg"
      from_port                  = 3000
      to_port                    = 3000
      protocol                   = "TCP"
      source_security_group_name = "alb_sg"
    }
    
    # API: Accept from Web tier
    api_from_web = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "api_sg"
      from_port                  = 8080
      to_port                    = 8080
      protocol                   = "TCP"
      source_security_group_name = "web_sg"
    }
    
    # API: Accept from ALB (direct API access)
    api_from_alb = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "api_sg"
      from_port                  = 8080
      to_port                    = 8080
      protocol                   = "TCP"
      source_security_group_name = "alb_sg"
    }
    
    # Database: Accept from API only
    db_from_api = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "db_sg"
      from_port                  = 5432
      to_port                    = 5432
      protocol                   = "TCP"
      source_security_group_name = "api_sg"
    }
    
    # Cache: Accept from API only
    cache_from_api = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "cache_sg"
      from_port                  = 6379
      to_port                    = 6379
      protocol                   = "TCP"
      source_security_group_name = "api_sg"
    }
    
    # Bastion: SSH from office IP only
    bastion_ssh = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "bastion_sg"
      from_port = 22
      to_port   = 22
      protocol  = "TCP"
      cidr_ipv4 = "203.0.113.0/24"  # Office IP range
    }
    
    # Web: SSH from bastion
    web_ssh_from_bastion = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "web_sg"
      from_port                  = 22
      to_port                    = 22
      protocol                   = "TCP"
      source_security_group_name = "bastion_sg"
    }
    
    # API: SSH from bastion
    api_ssh_from_bastion = {
      vpc_name                   = "ecommerce_vpc"
      sg_name                    = "api_sg"
      from_port                  = 22
      to_port                    = 22
      protocol                   = "TCP"
      source_security_group_name = "bastion_sg"
    }
  }
}

# =============================================================================
# Egress Rules
# =============================================================================
ipv4_egress_rule = {
  default = {
    # All SGs: Allow all outbound
    alb_egress = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "alb_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    web_egress = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "web_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    api_egress = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "api_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    db_egress = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "db_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    cache_egress = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "cache_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
    
    bastion_egress = {
      vpc_name  = "ecommerce_vpc"
      sg_name   = "bastion_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

**Traffic Flow:**
```
Internet → [ALB SG] → [Web SG] → [API SG] → [DB SG]
                   ↘                      ↘
                    [Web SG]              [Cache SG]

SSH: Office → [Bastion SG] → [Web/API SG]
```

## Compliance and Auditing

### PCI-DSS Compliance

For payment processing environments:

```hcl
# Cardholder Data Environment (CDE)
cde_sg = {
  name     = "pci-cde-sg"
  vpc_name = "secure_vpc"
  tags = {
    Compliance = "PCI-DSS"
    DataClass  = "cardholder-data"
  }
}

# CDE: No direct internet access
cde_ingress_from_app = {
  sg_name                    = "cde_sg"
  from_port                  = 443
  protocol                   = "TCP"
  source_security_group_name = "app_sg"  # Only from app tier
}
```

### HIPAA Compliance

For healthcare data:

```hcl
# Protected Health Information (PHI)
phi_sg = {
  name     = "hipaa-phi-sg"
  vpc_name = "healthcare_vpc"
  tags = {
    Compliance = "HIPAA"
    DataClass  = "protected-health-info"
  }
}

# PHI: Encrypted connections only
phi_ingress = {
  sg_name   = "phi_sg"
  from_port = 443
  protocol  = "TCP"
  cidr_ipv4 = "10.0.0.0/16"  # Internal VPC only
}
```

### Audit Logging

Enable VPC Flow Logs for security group traffic analysis:

```bash
# Create flow log for security group monitoring
aws ec2 create-flow-logs \
  --resource-type NetworkInterface \
  --resource-ids eni-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

## Testing Security Groups

### Connectivity Testing

```bash
# Test from source instance
aws ec2-instance-connect send-ssh-public-key \
  --instance-id i-xxxxx \
  --instance-os-user ec2-user \
  --ssh-public-key file://~/.ssh/id_rsa.pub

# Test port connectivity
nc -zv target-host 443

# Test from specific security group
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=sg-xxxxx" \
  --query 'NetworkInterfaces[*].Association.PublicIp'
```

### Rule Validation Script

```bash
#!/bin/bash
# validate-sg-rules.sh

SG_ID="sg-xxxxx"
EXPECTED_RULES=5

ACTUAL_RULES=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$SG_ID" \
  --query 'length(SecurityGroupRules)')

if [ "$ACTUAL_RULES" -eq "$EXPECTED_RULES" ]; then
  echo "✅ Security group has correct number of rules"
else
  echo "❌ Expected $EXPECTED_RULES rules, found $ACTUAL_RULES"
  exit 1
fi
```

## Performance Optimization

### Rule Consolidation

**Before (inefficient):**
```hcl
# Separate rules for each port
rule_80  = { from_port = 80,  to_port = 80,  protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
rule_443 = { from_port = 443, to_port = 443, protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
rule_8080 = { from_port = 8080, to_port = 8080, protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
```

**After (optimized):**
```hcl
# Single rule with port range
web_ports = { from_port = 80, to_port = 8080, protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
```

**Note:** Only consolidate if ports are truly related and security requirements allow.

### SG-to-SG vs CIDR Performance

Both have **equal performance** - security groups evaluate rules in parallel. However:

- **SG-to-SG:** Better for dynamic environments (IP addresses change)
- **CIDR:** Better for static external sources

## Cost Considerations

Security groups themselves are **FREE**. However, they affect costs indirectly:

### VPC Flow Logs
- Capturing security group traffic: **$0.50 per GB ingested**
- Consider for compliance/auditing only

### Data Transfer
- Rules allowing internet traffic incur **data transfer costs**:
  - Outbound: $0.09 per GB
  - Inbound: Free

### Best Practice
- Review egress rules to minimize unnecessary outbound traffic
- Use VPC endpoints to avoid NAT gateway costs
- Monitor with CloudWatch for cost optimization

## Disaster Recovery

### Backup Strategy

```bash
# Export security group configuration
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --output json > sg-backup.json

# Document rule changes
git commit -m "Add rule: Allow API from Web tier"
```

### Recovery Procedure

1. **Identify missing/incorrect rules**
2. **Update terraform.tfvars**
3. **Run terraform plan to verify changes**
4. **Apply changes with terraform apply**
5. **Validate connectivity**

## FAQ

### Q: Why are security groups and rules created separately?

**A:** To avoid circular dependencies. Security groups must exist before rules can reference them by ID.

### Q: Can I reference a security group from another workspace?

**A:** No. Security groups are workspace-specific. Use VPC peering and explicit CIDR rules for cross-workspace access.

### Q: What happens if I delete a security group that's referenced by rules?

**A:** Terraform will fail. You must first remove all rules referencing the security group, then delete the group.

### Q: How many rules can a security group have?

**A:** Default: 60 rules (ingress + egress combined). Request quota increase if needed.

### Q: Do I need to specify return traffic rules?

**A:** No. Security groups are **stateful** - return traffic is automatically allowed.

### Q: Can I use both CIDR and SG reference in the same rule?

**A:** No. AWS allows only one source type per rule. The framework enforces this.

### Q: What's the difference between `protocol = "TCP"` and `protocol = "tcp"`?

**A:** Both work, but be consistent. This framework uses **uppercase** for clarity.

### Q: Should I allow all egress by default?

**A:** **Yes** for most environments. Restrict egress only for high-security requirements (PCI-DSS, HIPAA, etc.).

### Q: How do I allow ICMP (ping)?

**A:** Use `protocol = "ICMP"` and see AWS documentation for ICMP type/code as port numbers.

### Q: Can I attach multiple security groups to one resource?

**A:** Yes. EC2 instances, EKS nodes, etc. can have multiple security groups. The framework supports this through list inputs.


## Change Log

### Version 1.0 (2025-01-13)
- Initial release
- Support for IPv4 and IPv6 rules
- Dynamic SG-to-SG reference resolution
- CIDR fallback to VPC CIDR
- Separate rule resources for better state management



## Module Metadata

- **Author** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Networking/Security
- **Complexity:** High (SG references, dynamic resolution)

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]
- [FAQ](#FAQ)



[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139