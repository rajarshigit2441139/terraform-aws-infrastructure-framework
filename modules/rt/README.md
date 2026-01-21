# Route Table Module

## Overview

This module creates AWS Route Tables and their associated routes. Route Tables control network traffic routing within VPCs, directing traffic to Internet Gateways, NAT Gateways, VPC Peering connections, Transit Gateways, and other network destinations.

## Module Purpose

- Creates route tables within VPCs
- Manages routes to various targets (IGW, NAT, VGW, TGW, etc.)
- Supports dynamic route creation with multiple destinations
- Enables flexible routing configurations for public and private subnets
- Provides outputs for route table associations

## Module Location

```text
modules/rt/
├── main.tf          # Route table resources
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **1 type of resource**:

1. **Route Tables with Routes** - `aws_route_table`

### Route Table Definition

```hcl
resource "aws_route_table" "example" {
  for_each = var.rt_parameters
  vpc_id   = each.value.vpc_id
  tags     = merge(each.value.tags, { Name : each.key })

  dynamic "route" {
    for_each = each.value.routes
    content {
      cidr_block = route.value.cidr_block

      gateway_id = (
        route.value.target_type == "igw" ? var.internet_gateway_ids[route.value.target_key] :
        route.value.target_type == "nat" ? var.nat_gateway_ids[route.value.target_key] :
        route.value.target_key
      )
    }
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}
```

## Inputs

### 1. `rt_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** `{}`

Map of route table configurations.

#### Object Structure

```hcl
{
  vpc_name = string                      # REQUIRED (for reference)
  vpc_id   = optional(string)            # REQUIRED (auto-injected)
  tags     = optional(map(string), {})   # OPTIONAL
  routes   = optional(list(object({      # OPTIONAL
    cidr_block  = string                 # REQUIRED
    target_type = string                 # REQUIRED: "igw", "nat", "vgw", "tgw", etc.
    target_key  = string                 # REQUIRED: gateway name or ID
  })), [])
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `vpc_name` | string | ✅ Yes | - | VPC key reference (converted to `vpc_id` by root) |
| `vpc_id` | string | ✅ Yes* | - | VPC ID (auto-injected by root module) |
| `tags` | map(string) | ❌ No | `{}` | Additional tags for the route table |
| `routes` | list(object) | ❌ No | `[]` | List of route definitions |

> **Note:** `vpc_id` is **auto-injected** by the parent module from `vpc_name`.

#### Route Object Structure

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cidr_block` | string | ✅ Yes | Destination CIDR block (e.g., `"0.0.0.0/0"`, `"10.0.0.0/16"`) |
| `target_type` | string | ✅ Yes | Type of gateway: `"igw"`, `"nat"`, `"vgw"`, `"tgw"`, or direct ID |
| `target_key` | string | ✅ Yes | Gateway key name (for `igw`/`nat`) or AWS resource ID |

**Supported Target Types**

| Target Type | Description | Example `target_key` |
|-------------|-------------|----------------------|
| `"igw"` | Internet Gateway | `"main_igw"` (module key) |
| `"nat"` | NAT Gateway | `"nat_gateway_1"` (module key) |
| `"vgw"` | Virtual Private Gateway | `"vgw-xxxxx"` (AWS ID) |
| `"tgw"` | Transit Gateway | `"tgw-xxxxx"` (AWS ID) |
| *other* | Direct AWS Resource ID | `"pcx-xxxxx"`, `"eni-xxxxx"` |

---

### 2. `internet_gateway_ids`

**Type:** `map(string)`  
**Required:** No  
**Default:** `{}`

Map from Internet Gateway keys to their AWS IDs. Used for resolving IGW references in routes.

**Example:**

```hcl
{
  "main_igw"   = "igw-0abc123def456"
  "backup_igw" = "igw-0def456abc789"
}
```

> **Note:** This is automatically provided by the parent module from `local.extract_internet_gateway_ids`.

---

### 3. `nat_gateway_ids`

**Type:** `map(string)`  
**Required:** No  
**Default:** `{}`

Map from NAT Gateway keys to their AWS IDs. Used for resolving NAT references in routes.

**Example:**

```hcl
{
  "nat_az1" = "nat-0abc123def456"
  "nat_az2" = "nat-0def456abc789"
}
```

> **Note:** This is automatically provided by the parent module from `local.extract_nat_gateway_ids`.

## Outputs

### `route_table_ids`

**Type:** `map(string)`  
**Description:** Map of route table IDs indexed by route table name (key)

#### Output Structure

```hcl
{
  "" = "rtb-xxxxx"
}
```

#### Output Example

```hcl
{
  "public_rt"  = "rtb-0abc123def456"
  "private_rt" = "rtb-0def456abc789"
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| key | string | Route table name from config | `"public_rt"` |
| value | string | AWS Route Table ID | `"rtb-0abc123def456"` |

## Usage in Root Module

### Called From

`02_vpc.tf` in the root module

### Module Call

```hcl
module "chat_app_rt" {
  source               = "./modules/rt"
  rt_parameters        = lookup(local.generated_rt_parameters, terraform.workspace, {} )
  internet_gateway_ids = local.extract_internet_gateway_ids
  nat_gateway_ids      = local.extract_nat_gateway_ids

  depends_on = [module.chat_app_vpc, module.chat_app_ig, module.chat_app_nat]
}
```

### Dynamic Parameter Generation

#### Route Tables with VPC ID Injection

```hcl
locals {
  generated_rt_parameters = {
    for workspace, rts in var.rt_parameters :
    workspace => {
      for name, rt in rts :
      name => merge(
        rt,
        { vpc_id = local.vpc_id_by_name[rt.vpc_name] }
      )
    }
  }
}
```

**What this does:**

1. Iterates through all workspaces in `var.rt_parameters`
2. For each route table in each workspace
3. Merges the original configuration with the resolved VPC ID
4. Looks up VPC ID using `vpc_name` from `local.vpc_id_by_name`

### Gateway ID Extraction

#### Internet Gateway IDs

```hcl
locals {
  extract_internet_gateway_ids = {
    for name, igw_obj in module.chat_app_ig.igws :
    name => igw_obj.id
  }
}
```

#### NAT Gateway IDs

```hcl
locals {
  extract_nat_gateway_ids = {
    for name, nat in module.chat_app_nat.nat_ids :
    name => nat.id
  }
}
```

### Route Table Associations

After creating route tables, they must be associated with subnets:

```hcl
locals {
  generated_rt_association_parameters = {
    for name, item in var.rt_association_parameters :
    name => merge(
      item,
      {
        subnet_id      = local.subnet_id_by_name[item.subnet_name]
        route_table_id = local.rt_id_by_name[item.rt_name]
      }
    )
  }
}

resource "aws_route_table_association" "chat_app_rt_association" {
  for_each       = local.generated_rt_association_parameters
  subnet_id      = each.value.subnet_id
  route_table_id = each.value.route_table_id
  depends_on     = [module.chat_app_subnet, module.chat_app_rt]
}
```

## Configuration Examples

### Example 1: Basic Public Route Table (IGW)

```hcl
rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "main_igw"
        }
      ]
      tags = {
        Type = "public"
      }
    }
  }
}
```

**Use Case:** Route all internet-bound traffic from public subnets to Internet Gateway.

---

### Example 2: Basic Private Route Table (NAT)

```hcl
rt_parameters = {
  default = {
    private_rt = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_gateway_az1"
        }
      ]
      tags = {
        Type = "private"
      }
    }
  }
}
```

**Use Case:** Route internet-bound traffic from private subnets through NAT Gateway.

---

### Example 3: Multi-AZ Private Route Tables

```hcl
rt_parameters = {
  default = {
    private_rt_az1 = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_gateway_az1"
        }
      ]
      tags = {
        Type = "private"
        AZ   = "az1"
      }
    }

    private_rt_az2 = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_gateway_az2"
        }
      ]
      tags = {
        Type = "private"
        AZ   = "az2"
      }
    }
  }
}
```

**Use Case:** High availability — each AZ has its own NAT Gateway to prevent cross-AZ data transfer charges.

---

### Example 4: Route Table with Multiple Routes

```hcl
rt_parameters = {
  default = {
    hybrid_rt = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "main_igw"
        },
        {
          cidr_block  = "10.20.0.0/16"
          target_type = "pcx"
          target_key  = "pcx-abc123def"  # VPC Peering Connection
        },
        {
          cidr_block  = "192.168.0.0/16"
          target_type = "vgw"
          target_key  = "vgw-xyz789abc"  # Virtual Private Gateway (VPN)
        }
      ]
      tags = {
        Type = "hybrid"
      }
    }
  }
}
```

**Use Case:** Complex routing with internet access, VPC peering, and VPN connections.

---

### Example 5: Transit Gateway Route Table

```hcl
rt_parameters = {
  default = {
    tgw_rt = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_gateway_az1"
        },
        {
          cidr_block  = "10.0.0.0/8"
          target_type = "tgw"
          target_key  = "tgw-0abc123def456"  # Transit Gateway
        }
      ]
      tags = {
        Type = "transit-gateway"
      }
    }
  }
}
```

**Use Case:** Route internal traffic through Transit Gateway while internet traffic goes through NAT.

---

### Example 6: Isolated Route Table (No Routes)

```hcl
rt_parameters = {
  default = {
    isolated_rt = {
      vpc_name = "main_vpc"
      routes   = []  # No routes defined
      tags = {
        Type = "isolated"
      }
    }
  }
}
```

**Use Case:** Completely isolated subnets with no external connectivity (e.g., database backups).

---

### Example 7: Multi-Environment Route Tables

```hcl
rt_parameters = {
  # Development Environment
  default = {
    dev_public_rt = {
      vpc_name = "dev_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "dev_igw"
        }
      ]
      tags = {
        Environment = "dev"
        Type        = "public"
      }
    }

    dev_private_rt = {
      vpc_name = "dev_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "dev_nat"
        }
      ]
      tags = {
        Environment = "dev"
        Type        = "private"
      }
    }
  }

  # Production Environment
  prod = {
    prod_public_rt = {
      vpc_name = "prod_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "prod_igw"
        }
      ]
      tags = {
        Environment = "prod"
        Type        = "public"
      }
    }

    prod_private_rt_az1 = {
      vpc_name = "prod_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "prod_nat_az1"
        }
      ]
      tags = {
        Environment = "prod"
        Type        = "private"
        AZ          = "az1"
      }
    }

    prod_private_rt_az2 = {
      vpc_name = "prod_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "prod_nat_az2"
        }
      ]
      tags = {
        Environment = "prod"
        Type        = "private"
        AZ          = "az2"
      }
    }
  }
}
```

---

### Example 8: VPC Endpoint Gateway Route Table

```hcl
rt_parameters = {
  default = {
    private_rt_with_s3 = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "nat_gateway_az1"
        }
      ]
      tags = {
        Type             = "private"
        VPCEndpointReady = "true"  # Will be associated with S3 endpoint
      }
    }
  }
}

# In vpc_endpoint_parameters
vpc_endpoint_parameters = {
  default = {
    s3_endpoint = {
      vpc_name          = "main_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt_with_s3"]  # Associates with this RT
    }
  }
}
```

**Use Case:** Private subnets access S3 via VPC Endpoint (no internet charges) while other traffic uses NAT.

## Route Table Association Configuration

Route tables must be associated with subnets to take effect:

```hcl
rt_association_parameters = {
  # Public subnet associations
  public_subnet_1_assoc = {
    subnet_name = "public_subnet_az1"
    rt_name     = "public_rt"
  }

  public_subnet_2_assoc = {
    subnet_name = "public_subnet_az2"
    rt_name     = "public_rt"
  }

  # Private subnet associations
  private_subnet_1_assoc = {
    subnet_name = "private_subnet_az1"
    rt_name     = "private_rt_az1"
  }

  private_subnet_2_assoc = {
    subnet_name = "private_subnet_az2"
    rt_name     = "private_rt_az2"
  }
}
```

## Route Target Types

### Internet Gateway (IGW)

```hcl
{
  cidr_block  = "0.0.0.0/0"
  target_type = "igw"
  target_key  = "main_igw"  # Key from igw_parameters
}
```

**Use Case:** Public subnets need internet access  
**Cost:** Free (no data processing charges)

---

### NAT Gateway

```hcl
{
  cidr_block  = "0.0.0.0/0"
  target_type = "nat"
  target_key  = "nat_gateway_az1"  # Key from nat_gateway_parameters
}
```

**Use Case:** Private subnets need outbound internet access  
**Cost:** $0.045/hour + $0.045/GB processed

---

### VPC Peering Connection

```hcl
{
  cidr_block  = "10.20.0.0/16"
  target_type = "pcx"
  target_key  = "pcx-abc123def456"  # AWS Peering Connection ID
}
```

**Use Case:** Route to another VPC  
**Cost:** Free (same region), data transfer charges (cross-region)

---

### Virtual Private Gateway (VPN)

```hcl
{
  cidr_block  = "192.168.0.0/16"
  target_type = "vgw"
  target_key  = "vgw-xyz789abc"  # AWS Virtual Private Gateway ID
}
```

**Use Case:** Route to on-premises network via VPN  
**Cost:** $0.05/hour per VPN connection

---

### Transit Gateway

```hcl
{
  cidr_block  = "10.0.0.0/8"
  target_type = "tgw"
  target_key  = "tgw-0abc123def456"  # AWS Transit Gateway ID
}
```

**Use Case:** Route to multiple VPCs/on-premises via central hub  
**Cost:** $0.05/hour + $0.02/GB processed

---

### Network Interface

```hcl
{
  cidr_block  = "172.16.0.0/16"
  target_type = "eni"
  target_key  = "eni-abc123def456"  # AWS Network Interface ID
}
```

**Use Case:** Route to specific EC2 instance (e.g., firewall appliance)  
**Cost:** Free

---

### VPC Endpoint

```hcl
{
  cidr_block  = "10.30.0.0/16"
  target_type = "vpce"
  target_key  = "vpce-abc123def456"  # AWS VPC Endpoint ID
}
```

**Use Case:** Route to VPC Interface Endpoint  
**Cost:** $0.01/hour + $0.01/GB processed

## Common Patterns

### Pattern 1: Standard Public-Private Architecture

```hcl
rt_parameters = {
  default = {
    # Public Route Table (1 per VPC)
    public_rt = {
      vpc_name = "main_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "igw"
        target_key  = "main_igw"
      }]
      tags = { Type = "public" }
    }

    # Private Route Table (1 per AZ for HA)
    private_rt_az1 = {
      vpc_name = "main_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "nat"
        target_key  = "nat_az1"
      }]
      tags = { Type = "private", AZ = "az1" }
    }

    private_rt_az2 = {
      vpc_name = "main_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "nat"
        target_key  = "nat_az2"
      }]
      tags = { Type = "private", AZ = "az2" }
    }
  }
}
```

**Architecture:**

```text
Public Subnet AZ1  ──┐
Public Subnet AZ2  ──┼──> Public RT ──> IGW ──> Internet
                     │
Private Subnet AZ1 ──┼──> Private RT AZ1 ──> NAT AZ1 ──> Internet
Private Subnet AZ2 ──┴──> Private RT AZ2 ──> NAT AZ2 ──> Internet
```

---

### Pattern 2: Hub-and-Spoke with Transit Gateway

```hcl
rt_parameters = {
  default = {
    # Spoke VPC Route Table
    spoke_rt = {
      vpc_name = "spoke_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "spoke_nat"
        },
        {
          cidr_block  = "10.0.0.0/8"     # All internal traffic
          target_type = "tgw"
          target_key  = "tgw-central"
        }
      ]
      tags = { Type = "spoke" }
    }
  }
}
```

**Architecture:**

```text
Spoke VPC 1 ──┐
Spoke VPC 2 ──┼──> Transit Gateway ──> Hub VPC ──> On-Premises
Spoke VPC 3 ──┘
```

---

### Pattern 3: Three-Tier Web Application

```hcl
rt_parameters = {
  default = {
    # Web Tier (Public)
    web_rt = {
      vpc_name = "app_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "igw"
        target_key  = "app_igw"
      }]
      tags = { Tier = "web" }
    }

    # App Tier (Private with NAT)
    app_rt = {
      vpc_name = "app_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "nat"
        target_key  = "app_nat"
      }]
      tags = { Tier = "app" }
    }

    # DB Tier (Isolated)
    db_rt = {
      vpc_name = "app_vpc"
      routes   = []  # No internet access
      tags = { Tier = "db" }
    }
  }
}
```

**Architecture:**

```text
Internet ──> Web RT (IGW) ──> App RT (NAT) ──> DB RT (isolated)
```

---

### Pattern 4: Hybrid Cloud (VPN + Internet)

```hcl
rt_parameters = {
  default = {
    hybrid_rt = {
      vpc_name = "hybrid_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "hybrid_igw"
        },
        {
          cidr_block  = "192.168.0.0/16"  # On-premises network
          target_type = "vgw"
          target_key  = "vgw-onprem"
        }
      ]
      tags = { Type = "hybrid" }
    }
  }
}
```

**Architecture:**

```text
                      ┌──> IGW ──> Internet
Hybrid Subnet ──> RT ─┤
                      └──> VGW ──> On-Premises
```

---

### Pattern 5: Cost-Optimized (Single NAT)

```hcl
rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "budget_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "igw"
        target_key  = "budget_igw"
      }]
      tags = { Type = "public" }
    }

    # Single private RT for all AZs (cost savings)
    private_rt = {
      vpc_name = "budget_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "nat"
        target_key  = "single_nat"  # Only 1 NAT Gateway
      }]
      tags = { Type = "private", CostOptimized = "true" }
    }
  }
}
```

**Cost Savings:** Single NAT (~$32.40/month) vs Multi-AZ NAT (~$64.80/month)  
**Trade-off:** ❌ Single point of failure, ✅ 50% cost reduction

## Best Practices

### Route Table Design

✅ **Do:**

- Create separate route tables for public and private subnets
- Use one public RT per VPC (can share across AZs)
- Use one private RT per AZ for high availability
- Name route tables clearly: `public_rt`, `private_rt_az1`
- Tag route tables with `Type`, `Environment`, `AZ`
- Keep route tables simple and purpose-specific

❌ **Don't:**

- Mix public and private routes in the same RT
- Reuse private RTs across AZs (creates cross-AZ dependencies)
- Create unnecessary route tables
- Use overly generic names like `rt1`, `rt2`

---

### Routing Rules

✅ **Do:**

- Use most specific routes first (AWS uses longest prefix match)
- Document the purpose of each route
- Prefer VPC endpoints over NAT for AWS services
- Use Transit Gateway for complex multi-VPC setups
- Test connectivity after route changes

❌ **Don't:**

- Create conflicting routes (same CIDR, different targets)
- Route all traffic through a single gateway (single point of failure)
- Forget to associate route tables with subnets
- Change production routes without testing

---

### High Availability

✅ **Do:**

```hcl
# One NAT Gateway per AZ
private_rt_az1 = {
  routes = [{ target_type = "nat", target_key = "nat_az1" }]
}
private_rt_az2 = {
  routes = [{ target_type = "nat", target_key = "nat_az2" }]
}
```

❌ **Don't:**

```hcl
# Single NAT for all AZs (single point of failure)
private_rt = {
  routes = [{ target_type = "nat", target_key = "single_nat" }]
}
```

---

### Cost Optimization

✅ **For Production:**

- Use NAT Gateway per AZ (high availability)
- Use VPC Endpoints for S3, DynamoDB (reduced NAT usage)
- Monitor data transfer costs

✅ **For Dev/Test:**

- Use single NAT Gateway (acceptable downtime risk)
- Use NAT Instance instead of NAT Gateway (cheaper)
- Turn off NAT when not in use

---

### Security

✅ **Do:**

- Isolate database subnets (no internet routes)
- Use VPC Endpoints to avoid internet routing
- Implement least-privilege routing
- Log route table changes

❌ **Don't:**

- Route database subnets to internet
- Use overly permissive routes
- Share route tables across security zones

## Dependencies

### This Module Depends On

- ✅ **VPC Module** — Must create VPC before route tables
- ✅ **Internet Gateway Module** (optional) — If using IGW routes
- ✅ **NAT Gateway Module** (optional) — If using NAT routes

### Modules That Depend On This

- ✅ **Subnet Associations** — Subnets must be associated with route tables
- ✅ **VPC Gateway Endpoints** — Gateway endpoints attach to route tables
- ⚠️ **EC2 Instances, EKS Nodes** — Indirectly via subnet associations

## Lifecycle Management

### Prevent Destroy

Default: `prevent_destroy = false`

To protect critical route tables:

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

### Replace Triggers

Changing these parameters will **replace** the route table:

- `vpc_id`
- Route `cidr_block` or `gateway_id`

Changing these will **update** in-place:

- `tags`

## Validation

### After Creation

```bash
# Verify route table creation
terraform output rt_ids

# Check route table details
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx

# List all route tables in VPC
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-xxxxx"

# Verify routes
aws ec2 describe-route-tables \
  --route-table-ids rtb-xxxxx \
  --query 'RouteTables[0].Routes'

# Check route table associations
aws ec2 describe-route-tables \
  --route-table-ids rtb-xxxxx \
  --query 'RouteTables[0].Associations'
```

### Test Connectivity

```bash
# From EC2 instance in associated subnet
ping 8.8.8.8  # Test internet connectivity via IGW/NAT

# Check effective routes
ip route show

# Trace route path
traceroute google.com

# Test VPC endpoint connectivity
aws s3 ls  # Should use VPC endpoint if configured
```

## Troubleshooting

### Issue: No Internet Connectivity from Public Subnet

**Symptoms:**

```text
Cannot reach internet from EC2 instances in public subnet
```

**Diagnosis:**

```bash
# Check route table
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx

# Verify IGW is attached
aws ec2 describe-internet-gateways --internet-gateway-ids igw-xxxxx
```

**Solution:**

1. Ensure route table has `0.0.0.0/0 → IGW` route
2. Verify route table is associated with subnet
3. Ensure subnet has `map_public_ip_on_launch = true`
4. Verify security group allows outbound traffic
5. Check Network ACLs

---

### Issue: No Internet Connectivity from Private Subnet

**Symptoms:**

```text
Cannot reach internet from EC2 instances in private subnet
```

**Diagnosis:**

```bash
# Check route table
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx

# Verify NAT Gateway
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx
```

**Solution:**

1. Ensure route table has `0.0.0.0/0 → NAT` route
2. Verify NAT Gateway is in `available` state
3. Check NAT Gateway is in public subnet
4. Verify NAT Gateway has Elastic IP
5. Check IGW is attached to VPC
6. Verify security groups and NACLs

---

### Issue: Route Table Not Created

**Symptoms:**

```text
Error: Error creating route table
```

**Solution:**

- Verify VPC exists and `vpc_id` is correct
- Check VPC is in correct workspace
- Ensure route table name is unique within workspace
- Verify AWS credentials and permissions

---

### Issue: Gateway ID Not Resolved

**Symptoms:**

```text
Error: Invalid gateway ID
```

**Solution:**

- Verify `target_key` matches IGW/NAT key exactly
- Check gateway exists: `terraform output igws_ids` or `terraform output nat_ids`
- Ensure `internet_gateway_ids` or `nat_gateway_ids` is passed to module
- Check `depends_on` includes gateway modules

---

### Issue: Conflicting Routes

**Symptoms:**

```text
Error: RouteAlreadyExists
```

**Solution:**

- Each CIDR can only have one route
- Check for duplicate `cidr_block` entries
- AWS uses longest prefix match (more specific routes override)

---

### Issue: Route Table Association Failed

**Symptoms:**

```text
Error: Resource.AlreadyAssociated
```

**Solution:**

- Each subnet can only be associated with one route table
- Check if subnet is already associated
- Use `terraform state list` to find existing associations
- Remove old association before creating new one

---

### Issue: Cross-AZ Data Transfer Charges

**Symptoms:** High AWS data transfer costs

**Fix:** Use one NAT Gateway per AZ.

```text
private_rt_az1 → nat_az1
private_rt_az2 → nat_az2
```

**Problem:** Single NAT for all AZs causes cross-AZ traffic.

```text
private_rt_az1 → nat_az1
private_rt_az2 → nat_az1  # AZ2 traffic goes to AZ1 NAT (cross-AZ)
```

---

### Issue: VPC Endpoint Routes Not Working

**Symptoms:**

```text
S3 traffic still going through NAT Gateway
```

**Solution:**

- Verify VPC Gateway Endpoint is associated with the route table
- Endpoint routes are automatically added — don't manually add them
- Verify endpoint policy allows access

```bash
# Check endpoint route table associations
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxx
```

## Real-World Example: Complete E-Commerce Application

```hcl
rt_parameters = {
  default = {
    # =================================================================
    # PUBLIC ROUTE TABLE
    # =================================================================
    # Used by: Load Balancer subnets, Bastion subnets
    # Purpose: Direct internet access via Internet Gateway
    # =================================================================
    public_rt = {
      vpc_name = "ecommerce_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "igw"
          target_key  = "ecommerce_igw"
        }
      ]
      tags = {
        Name        = "ecommerce-public-rt"
        Type        = "public"
        Environment = "production"
        ManagedBy   = "terraform"
      }
    }

    # =================================================================
    # PRIVATE ROUTE TABLES (Multi-AZ for High Availability)
    # =================================================================
    private_rt_az1 = {
      vpc_name = "ecommerce_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "ecommerce_nat_az1"
        },
        {
          cidr_block  = "10.20.0.0/16"  # Secondary VPC (analytics)
          target_type = "pcx"
          target_key  = "pcx-analytics"
        }
      ]
      tags = {
        Name        = "ecommerce-private-rt-az1"
        Type        = "private"
        AZ          = "ap-south-1a"
        Environment = "production"
      }
    }

    private_rt_az2 = {
      vpc_name = "ecommerce_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "ecommerce_nat_az2"
        },
        {
          cidr_block  = "10.20.0.0/16"  # Secondary VPC (analytics)
          target_type = "pcx"
          target_key  = "pcx-analytics"
        }
      ]
      tags = {
        Name        = "ecommerce-private-rt-az2"
        Type        = "private"
        AZ          = "ap-south-1b"
        Environment = "production"
      }
    }

    # =================================================================
    # DATABASE ROUTE TABLES (Isolated)
    # =================================================================
    database_rt_az1 = {
      vpc_name = "ecommerce_vpc"
      routes   = []  # No routes = isolated
      tags = {
        Name        = "ecommerce-database-rt-az1"
        Type        = "database"
        Isolated    = "true"
        AZ          = "ap-south-1a"
        Environment = "production"
      }
    }

    database_rt_az2 = {
      vpc_name = "ecommerce_vpc"
      routes   = []  # No routes = isolated
      tags = {
        Name        = "ecommerce-database-rt-az2"
        Type        = "database"
               Isolated    = "true"
        AZ          = "ap-south-1b"
        Environment = "production"
      }
    }

    # =================================================================
    # TRANSIT ROUTE TABLE (For Multi-Region)
    # =================================================================
    transit_rt = {
      vpc_name = "ecommerce_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"
          target_type = "nat"
          target_key  = "ecommerce_nat_az1"
        },
        {
          cidr_block  = "10.0.0.0/8"  # All corporate networks
          target_type = "tgw"
          target_key  = "tgw-global"
        }
      ]
      tags = {
        Name        = "ecommerce-transit-rt"
        Type        = "transit"
        Environment = "production"
      }
    }
  }
}

rt_association_parameters = {
  # Public Subnets → Public RT
  public_lb_az1_assoc = {
    subnet_name = "public_lb_az1"
    rt_name     = "public_rt"
  }
  public_lb_az2_assoc = {
    subnet_name = "public_lb_az2"
    rt_name     = "public_rt"
  }
  public_bastion_az1_assoc = {
    subnet_name = "public_bastion_az1"
    rt_name     = "public_rt"
  }

  # Private Subnets AZ1 → Private RT AZ1
  private_web_az1_assoc = {
    subnet_name = "private_web_az1"
    rt_name     = "private_rt_az1"
  }
  private_app_az1_assoc = {
    subnet_name = "private_app_az1"
    rt_name     = "private_rt_az1"
  }
  private_worker_az1_assoc = {
    subnet_name = "private_worker_az1"
    rt_name     = "private_rt_az1"
  }

  # Private Subnets AZ2 → Private RT AZ2
  private_web_az2_assoc = {
    subnet_name = "private_web_az2"
    rt_name     = "private_rt_az2"
  }
  private_app_az2_assoc = {
    subnet_name = "private_app_az2"
    rt_name     = "private_rt_az2"
  }
  private_worker_az2_assoc = {
    subnet_name = "private_worker_az2"
    rt_name     = "private_rt_az2"
  }

  # Database Subnets → Database RT (Isolated)
  database_az1_assoc = {
    subnet_name = "database_az1"
    rt_name     = "database_rt_az1"
  }
  database_az2_assoc = {
    subnet_name = "database_az2"
    rt_name     = "database_rt_az2"
  }
  database_cache_az1_assoc = {
    subnet_name = "cache_az1"
    rt_name     = "database_rt_az1"
  }
  database_cache_az2_assoc = {
    subnet_name = "cache_az2"
    rt_name     = "database_rt_az2"
  }
}
```

**Network Architecture:**

```text
┌─────────────────────────────────────────────────────────────────┐
│ VPC: 10.10.0.0/16                                               │
├─────────────────────────────────────────────────────────────────┤
│ PUBLIC TIER (Public RT → IGW)                                   │
│ ├─ ALB Subnets (AZ1, AZ2)                                       │
│ └─ Bastion Subnets (AZ1)                                        │
│                                                                 │
│ PRIVATE TIER (Private RT AZ1 → NAT AZ1, Private RT AZ2 → NAT AZ2)│
│ ├─ Web Subnets (AZ1, AZ2)                                       │
│ ├─ API Subnets (AZ1, AZ2)                                       │
│ └─ Worker Subnets (AZ1, AZ2)                                    │
│                                                                 │
│ DATABASE TIER (Isolated - No Routes)                             │
│ ├─ RDS Subnets (AZ1, AZ2)                                       │
│ └─ ElastiCache Subnets (AZ1, AZ2)                               │
│                                                                 │
│ CROSS-VPC (Via VPC Peering)                                     │
│ └─ Analytics VPC (10.20.0.0/16)                                 │
│                                                                 │
│ MULTI-REGION (Via Transit Gateway)                              │
│ └─ Corporate Networks (10.0.0.0/8)                              │
└─────────────────────────────────────────────────────────────────┘
```

## Cost Analysis

### Monthly Costs by Configuration

| Configuration | NAT Gateways | Monthly Cost | Use Case |
|--------------|--------------|--------------|----------|
| Single NAT | 1 | ~$32.40 | Dev/Test (acceptable downtime) |
| Multi-AZ NAT | 2 | ~$64.80 | Production (high availability) |
| Multi-AZ NAT (3 AZ) | 3 | ~$97.20 | Mission-critical (maximum HA) |

**Cost Breakdown:**

- NAT Gateway: $0.045/hour ≈ $32.40/month
- Data processing: $0.045/GB
- Cross-AZ data transfer: $0.01/GB (if using wrong NAT)

**Cost Optimization Tips:**

- Use VPC Endpoints for S3/DynamoDB (reduce NAT usage)
- Use single NAT for non-production
- Ensure each AZ uses its own NAT (avoid cross-AZ charges)
- Consider NAT Instance for very low traffic (<100GB/month)

## Advanced Configuration

### Dynamic Route Resolution

The module automatically resolves gateway keys to IDs:

```hcl
gateway_id = (
  route.value.target_type == "igw" ? var.internet_gateway_ids[route.value.target_key] :
  route.value.target_type == "nat" ? var.nat_gateway_ids[route.value.target_key] :
  route.value.target_key
)
```

**How it works:**

- If `target_type == "igw"` → Look up IGW ID from `internet_gateway_ids`
- If `target_type == "nat"` → Look up NAT ID from `nat_gateway_ids`
- Otherwise → Use `target_key` as direct AWS resource ID

### Conditional Routing

```hcl
# Example: Add VPN route only in production
routes = concat(
  [
    {
      cidr_block  = "0.0.0.0/0"
      target_type = "nat"
      target_key  = "prod_nat"
    }
  ],
  terraform.workspace == "prod" ? [
    {
      cidr_block  = "192.168.0.0/16"
      target_type = "vgw"
      target_key  = "vgw-onprem"
    }
  ] : []
)
```

### Tagging Strategy

```hcl
tags = merge(each.value.tags, {
  Name : each.key  # Automatically add Name tag from key
})
```

**Recommended Tags:**

```hcl
tags = {
  Name               = "Automatic (from key)"
  Type               = "public|private|database|transit"
  Environment        = "dev|qe|prod"
  AZ                 = "ap-south-1a|ap-south-1b"
  ManagedBy          = "terraform"
  CostCenter         = "engineering"
  Owner              = "platform-team"
  HighAvailability   = "true|false"
  DataClassification = "public|internal|confidential|restricted"
}
```

## Compliance Considerations

### PCI-DSS

```hcl
# Cardholder Data Environment (CDE) - Isolated
cde_rt = {
  vpc_name = "secure_vpc"
  routes   = []  # No internet access
  tags = {
    Compliance = "PCI-DSS"
    DataClass  = "cardholder-data"
  }
}
```

### HIPAA

```hcl
# Protected Health Information (PHI) - Restricted routing
phi_rt = {
  vpc_name = "healthcare_vpc"
  routes = [
    {
      cidr_block  = "10.0.0.0/8"  # Internal only
      target_type = "tgw"
      target_key  = "tgw-internal"
    }
  ]
  tags = {
    Compliance = "HIPAA"
    DataClass  = "protected-health-info"
  }
}
```

## Monitoring and Logging

### Enable VPC Flow Logs

```bash
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

### Route Table Change Notifications (AWS Config)

```bash
aws configservice put-config-rule \
  --config-rule file://route-table-changes.json
```

## Migration Guide

### From Default Route Table

**Before:** Subnets use VPC's default route table automatically

**After:** Explicit custom route table + subnet association

```hcl
rt_parameters = {
  default = {
    custom_rt = {
      vpc_name = "my_vpc"
      routes = [{ ... }]
    }
  }
}

rt_association_parameters = {
  subnet_assoc = {
    subnet_name = "my_subnet"
    rt_name     = "custom_rt"
  }
}
```

**Benefits:**

- ✅ Explicit control over routing
- ✅ Easier to understand infrastructure
- ✅ Better change tracking

### From Inline Routes to Dynamic Routes

**Before (inline):**

```hcl
resource "aws_route" "example" {
  route_table_id         = aws_route_table.example.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example.id
}
```

**After (dynamic):**

```hcl
dynamic "route" {
  for_each = each.value.routes
  content {
    cidr_block = route.value.cidr_block
    gateway_id = route.value.gateway_id
  }
}
```

**Benefits:**

- ✅ All routes in one configuration block
- ✅ Easier to manage multiple routes
- ✅ Consistent with other modules

## Testing

### Connectivity Tests

```bash
#!/bin/bash
# test-routes.sh

# Test from public subnet
PUBLIC_INSTANCE="i-xxxxx"
aws ssm start-session --target $PUBLIC_INSTANCE
curl -I https://google.com  # Should work via IGW

# Test from private subnet
PRIVATE_INSTANCE="i-yyyyy"
aws ssm start-session --target $PRIVATE_INSTANCE
curl -I https://google.com  # Should work via NAT

# Test database subnet (should fail)
DB_INSTANCE="i-zzzzz"
aws ssm start-session --target $DB_INSTANCE
curl -I https://google.com  # Should timeout (no route)
```

### Route Validation Script

```bash
#!/bin/bash
# validate-routes.sh

RT_ID="rtb-xxxxx"
EXPECTED_ROUTE="0.0.0.0/0"

ACTUAL_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids $RT_ID \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='$EXPECTED_ROUTE'].GatewayId" \
  --output text)

if [ -n "$ACTUAL_ROUTE" ]; then
  echo "✅ Route $EXPECTED_ROUTE exists with target $ACTUAL_ROUTE"
else
  echo "❌ Route $EXPECTED_ROUTE not found"
  exit 1
fi
```

## FAQ

**Q: How many route tables should I create?**  
A: Typical setup:

- 1 public RT per VPC
- 1–2 private RTs per AZ (depending on requirements)
- 1–2 database RTs per AZ (isolated)

**Q: Can I share a route table across multiple VPCs?**  
A: No. Route tables are VPC-specific.

**Q: What's the maximum number of routes per route table?**  
A: Default quota is often 50 routes per route table (can be increased via AWS Service Quotas).

**Q: Do route table associations cost money?**  
A: No. Route tables and associations are free. You only pay for the gateways they route to (NAT, VPN, TGW, etc.).

**Q: Can I have multiple routes to the same destination?**  
A: No. Each CIDR can only have one route. AWS uses longest prefix match for overlapping routes.

**Q: Should I use one or multiple NAT Gateways?**  
A:

- Production: Multiple (1 per AZ) for high availability
- Dev/Test: Single NAT acceptable (cost savings)

**Q: How do I troubleshoot routing issues?**  
A:

- Check route table configuration
- Verify route table associations
- Test gateway status (IGW, NAT, VPN)
- Check security groups and NACLs
- Use VPC Flow Logs for traffic analysis

**Q: Can I modify routes without recreating the route table?**  
A: Yes. Routes can be added/removed/modified without replacing the route table.

**Q: What happens if I delete a route table?**  
A: You cannot delete a route table if:

- It’s associated with subnets
- It’s the VPC’s main route table

Remove associations first, then delete.

**Q: How do VPC Endpoint routes work?**  
A: Gateway endpoints automatically add routes to associated route tables. You don't manually add these routes.


## Module Metadata

- **Author:** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Networking/Routing
- **Complexity:** Medium (dynamic route resolution)

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]
- [FAQ](#FAQ)


## AWS Resource Reference

- Resource Type: `aws_route_table`
- AWS Docs: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html
- Terraform Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table

[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139