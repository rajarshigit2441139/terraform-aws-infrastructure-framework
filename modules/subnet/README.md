# Subnet Module

## Overview

This module creates AWS Subnet resources within VPCs. Subnets divide your VPC into smaller network segments, allowing you to organize resources by tier (web, app, database) and availability zone for high availability.

## Module Purpose

- Creates subnets within existing VPCs
- Supports multiple subnets per VPC
- Configures availability zone placement
- Controls public IP assignment behavior
- Enables multi-AZ deployment strategies
- Provides outputs for resource linking in parent modules

## Module Location

```
modules/subnet/
├── main.tf          # Subnet resource definition
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resource Definition

The module uses `aws_subnet` resource with `for_each` meta-argument to create multiple subnets from a map of configurations:

```hcl
resource "aws_subnet" "example" {
  for_each                = var.subnet_parameters
  vpc_id                  = each.value.vpc_id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch
  tags = merge(each.value.tags, {
    Name : each.key
  })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}
```

## Inputs

### `subnet_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** `{}`

Map of subnet configurations where each key represents a unique subnet identifier.

#### Object Structure

```hcl
{
  cidr_block              = string                      # REQUIRED
  vpc_name                = string                      # REQUIRED (for reference)
  vpc_id                  = string                      # REQUIRED (auto-injected)
  availability_zone       = string                      # REQUIRED (auto-generated)
  az_index                = number                      # REQUIRED (user provides)
  map_public_ip_on_launch = optional(bool)              # OPTIONAL
  tags                    = optional(map(string), {})   # OPTIONAL
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `cidr_block` | string | ✅ Yes | - | IPv4 CIDR block for subnet (must be within VPC CIDR) |
| `vpc_name` | string | ✅ Yes* | - | VPC key reference (converted to vpc_id by root module) |
| `vpc_id` | string | ✅ Yes** | - | VPC ID (auto-injected by root module) |
| `availability_zone` | string | ✅ Yes* | - | AZ name (auto-injected from az_index) |
| `az_index` | number | ✅ Yes | - | AZ index (0, 1, 2, etc.) for data source lookup |
| `map_public_ip_on_launch` | bool | ❌ No | `false` | Auto-assign public IP to instances |
| `tags` | map(string) | ❌ No | `{}` | Additional tags for the subnet |

> **Note:** `vpc_id` and `availability_zone` are **injected automatically** by the parent module from `vpc_name` and `az_index`.

## Outputs

### `subnets`

**Type:** `map(object)`  
**Description:** Map of subnet outputs indexed by subnet name (key)

#### Output Structure

```hcl
{
  "<subnet_key>" = {
    cidr_block = string  # Subnet CIDR block
    id         = string  # Subnet ID (subnet-xxxxx)
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `cidr_block` | string | Subnet CIDR block | "10.10.1.0/24" |
| `id` | string | AWS Subnet ID | "subnet-0abc123def456" |

**Note:** The subnet name is used as the map key in the output.

## Usage in Root Module

### Called From

`02_vpc.tf` in the root module

### Module Call

```hcl
module "chat_app_subnet" {
  source            = "./modules/subnet"
  subnet_parameters = lookup(local.generated_subnet_parameters, terraform.workspace, {} )
  depends_on        = [module.chat_app_vpc]
}
```

### Dynamic Parameter Generation

Subnet parameters are **not passed directly** from `var.subnet_parameters`. Instead, they're enriched with VPC IDs and AZ information in `02_vpc.tf`:

```hcl
# AZ Data Source
data "aws_availability_zones" "available" {}

# Generate subnet parameters with injected IDs
locals {
  generated_subnet_parameters = {
    for workspace, subnets in var.subnet_parameters :
    workspace => {
      for name, subnet in subnets :
      name => merge(
        subnet,
        { 
          vpc_id            = local.vpc_id_by_name[subnet.vpc_name]
          availability_zone = data.aws_availability_zones.available.names[subnet.az_index]
        }
      )
    }
  }
}

module "chat_app_subnet" {
  source            = "./modules/subnet"
  subnet_parameters = lookup(local.generated_subnet_parameters, terraform.workspace, {} )
  depends_on        = [module.chat_app_vpc]
}
```

### Key Transformation

**User provides** (in terraform.tfvars):
```hcl
subnet_parameters = {
  default = {
    my_subnet = {
      cidr_block = "10.0.1.0/24"
      vpc_name   = "my_vpc"      # User-friendly reference
      az_index   = 0              # Index instead of actual AZ name
    }
  }
}
```

**Module receives** (after transformation in 02_vpc.tf):
```hcl
{
  cidr_block        = "10.0.1.0/24"
  vpc_id            = "vpc-0abc123..."        # Auto-injected
  availability_zone = "ap-south-1a"           # Auto-resolved
  # ... other parameters
}
```

## Configuration Examples

### Example 1: Basic Public and Private Subnets

```hcl
subnet_parameters = {
  default = {
    public_subnet = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public" }
    }
    
    private_subnet = {
      cidr_block              = "10.0.10.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Type = "private" }
    }
  }
}
```

**Result:**
- Public subnet with auto-assign public IP
- Private subnet without public IP assignment
- Both in the same Availability Zone

### Example 2: Multi-AZ High Availability

```hcl
subnet_parameters = {
  default = {
    public_subnet_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az1" }
    }
    
    public_subnet_az2 = {
      cidr_block              = "10.0.2.0/24"
      vpc_name                = "my_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Type = "public", AZ = "az2" }
    }
    
    private_subnet_az1 = {
      cidr_block              = "10.0.10.0/24"
      vpc_name                = "my_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Type = "private", AZ = "az1" }
    }
    
    private_subnet_az2 = {
      cidr_block              = "10.0.11.0/24"
      vpc_name                = "my_vpc"
      az_index                = 1
      map_public_ip_on_launch = false
      tags = { Type = "private", AZ = "az2" }
    }
  }
}
```

### Example 3: Three-Tier Architecture

```hcl
subnet_parameters = {
  default = {
    # Web Tier (Public)
    web_subnet_az1 = {
      cidr_block              = "10.0.1.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Tier = "web", AZ = "az1" }
    }
    
    # Application Tier (Private)
    app_subnet_az1 = {
      cidr_block              = "10.0.10.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Tier = "application", AZ = "az1" }
    }
    
    # Database Tier (Private)
    db_subnet_az1 = {
      cidr_block              = "10.0.20.0/24"
      vpc_name                = "app_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Tier = "database", AZ = "az1" }
    }
  }
}
```

### Example 4: Multi-Environment Subnets

```hcl
subnet_parameters = {
  # Development
  default = {
    dev_public_subnet = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Environment = "dev", Type = "public" }
    }
    
    dev_private_subnet = {
      cidr_block              = "10.10.10.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Environment = "dev", Type = "private" }
    }
  }
  
  # Production
  prod = {
    prod_public_subnet_az1 = {
      cidr_block              = "10.30.1.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Environment = "prod", Type = "public", AZ = "az1" }
    }
    
    prod_public_subnet_az2 = {
      cidr_block              = "10.30.2.0/24"
      vpc_name                = "prod_vpc"
      az_index                = 1
      map_public_ip_on_launch = true
      tags = { Environment = "prod", Type = "public", AZ = "az2" }
    }
  }
}
```

## Lifecycle Management

### Prevent Destroy

The module has `prevent_destroy = false`, meaning subnets **can be destroyed** during `terraform destroy`.

**To protect critical subnets:**

Modify `main.tf`:
```hcl
lifecycle {
  prevent_destroy = true  # Prevents accidental deletion
  ignore_changes  = [tags]
}
```

### Ignore Changes

The module ignores changes to tags after initial creation:

```hcl
ignore_changes = [tags]
```

**To allow tag updates:** Remove or comment out the `ignore_changes` block.

## Dependencies

### This Module Depends On
- ✅ **VPC Module** - Must create VPC before subnets
- ✅ **AWS Availability Zones Data Source** - Provides AZ information

### Modules That Depend On This
- `modules/rt` - Route table associations require subnet IDs
- `modules/nat_gw` - NAT Gateway placement requires subnet IDs
- EKS Clusters & Node Groups - Require subnet IDs for placement
- EC2 Instances - Require subnet IDs for placement

## Dynamic Resource Injection

### VPC ID Injection

The parent module automatically injects VPC IDs before passing to this module:

**In `02_vpc.tf`:**
```hcl
locals {
  generated_subnet_parameters = {
    for workspace, subnets in var.subnet_parameters :
    workspace => {
      for name, subnet in subnets :
      name => merge(
        subnet,
        { 
          vpc_id            = local.vpc_id_by_name[subnet.vpc_name]
          availability_zone = data.aws_availability_zones.available.names[subnet.az_index]
        }
      )
    }
  }
}

module "chat_app_subnet" {
  source            = "./modules/subnet"
  subnet_parameters = lookup(local.generated_subnet_parameters, terraform.workspace, {} )
  depends_on        = [module.chat_app_vpc]
}
```

### Availability Zone Resolution

AZs are dynamically resolved using `az_index`:

```hcl
data "aws_availability_zones" "available" {}

# az_index = 0 → data.aws_availability_zones.available.names[0] → ap-south-1a
# az_index = 1 → data.aws_availability_zones.available.names[1] → ap-south-1b
# az_index = 2 → data.aws_availability_zones.available.names[2] → ap-south-1c
```

## Output Usage by Other Modules

### In Route Table Associations

```hcl
# 02_vpc.tf
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
```

### In NAT Gateway Module

```hcl
# 05_gateway.tf
locals {
  generated_nat_gateway_parameters = {
    for workspace, nat_gateways in var.nat_gateway_parameters :
    workspace => {
      for name, nat_gateway in nat_gateways :
      name => merge(
        nat_gateway,
        { subnet_id = local.subnet_id_by_name[nat_gateway.subnet_name] }
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
          subnet_ids = [
            for sn in coalesce(ep.subnet_names, []) :
            lookup(local.subnet_id_by_name, sn)
          ]
        }
      )
    }
  }
}
```

## Tagging Strategy

### Automatic Tags

The module automatically adds a `Name` tag with the subnet key:

```hcl
tags = merge(each.value.tags, {
  Name : each.key
})
```

**Example:**
```hcl
subnet_parameters = {
  default = {
    my_public_subnet = {
      cidr_block = "10.0.1.0/24"
      vpc_name   = "my_vpc"
      az_index   = 0
      tags = {
        Type = "public"
      }
    }
  }
}

# Results in tags:
# Name = "my_public_subnet"
# Type = "public"
```

### Recommended Tag Schema

```hcl
tags = {
  Name        = "Automatic (from key)"
  Environment = "dev|qe|prod"
  Type        = "public|private|database"
  Tier        = "web|application|database"
  AZ          = "az1|az2|az3"
  Project     = "project-name"
  ManagedBy   = "terraform"
}
```

## Best Practices

### CIDR Planning

✅ **Do:**
- Reserve first few subnets for public use (e.g., 10.0.1.0/24, 10.0.2.0/24)
- Use middle ranges for private application subnets (e.g., 10.0.10.0/24)
- Use higher ranges for database subnets (e.g., 10.0.20.0/24)
- Keep subnet sizes consistent within tiers
- Use `/24` for most subnets (256 IPs, 251 usable)

❌ **Don't:**
- Create overlapping subnet CIDR blocks
- Use subnets larger than VPC can accommodate
- Mix subnet purposes without clear naming

### Availability Zone Distribution

✅ **Do:**
- Distribute critical resources across at least 2 AZs
- Use consistent AZ indexing (0, 1, 2)
- Place paired resources (e.g., web tier) in same AZs
- Test AZ availability in your region

❌ **Don't:**
- Put all resources in a single AZ (no fault tolerance)
- Use hardcoded AZ names (they vary by account)
- Ignore AZ capacity constraints

### Public IP Assignment

✅ **Do:**
- Enable for subnets hosting load balancers, NAT gateways, bastion hosts
- Disable for private application and database subnets
- Document which subnets are public vs private

❌ **Don't:**
- Enable public IPs on database subnets
- Disable on subnets meant for internet-facing resources

### Naming Convention

✅ **Do:**
- Include subnet type: `web_subnet`, `app_subnet`, `db_subnet`
- Include AZ designation: `web_subnet_az1`, `web_subnet_az2`
- Include environment: `dev_web_subnet_az1`
- Use consistent patterns across environments

❌ **Don't:**
- Use generic names: `subnet1`, `subnet2`
- Mix naming conventions
- Forget to indicate AZ in multi-AZ setups

### Subnet Sizing

| Use Case | Subnet Size | Usable IPs | Recommendation |
|----------|-------------|------------|----------------|
| Micro services | `/27` | 27 | Small dev environments |
| Standard tier | `/24` | 251 | **Recommended** for most use cases |
| Large deployments | `/23` | 507 | High-density compute |
| EKS clusters | `/20` | 4091 | Large Kubernetes clusters |

**AWS reserves 5 IPs per subnet:**
- `.0` - Network address
- `.1` - VPC router
- `.2` - DNS server
- `.3` - Future use
- `.255` - Broadcast address

## Subnet Patterns

### Pattern 1: Public-Private Pair

```
VPC: 10.0.0.0/16

Public:  10.0.1.0/24  (AZ1)
Private: 10.0.10.0/24 (AZ1)

Public:  10.0.2.0/24  (AZ2)
Private: 10.0.11.0/24 (AZ2)
```

### Pattern 2: Three-Tier

```
VPC: 10.0.0.0/16

Web:  10.0.1.0/24  (AZ1) - Public
App:  10.0.10.0/24 (AZ1) - Private
DB:   10.0.20.0/24 (AZ1) - Private

Web:  10.0.2.0/24  (AZ2) - Public
App:  10.0.11.0/24 (AZ2) - Private
DB:   10.0.21.0/24 (AZ2) - Private
```

### Pattern 3: Microservices

```
VPC: 10.0.0.0/16

LB:       10.0.1.0/24  (AZ1) - Public
Frontend: 10.0.10.0/24 (AZ1) - Private
Backend:  10.0.20.0/24 (AZ1) - Private
Data:     10.0.30.0/24 (AZ1) - Private
```

## Validation

### After Creation

```bash
# Verify subnet creation
terraform output subnet_id

# Check subnet details in AWS
aws ec2 describe-subnets --filters "Name=tag:Name,Values=my_public_subnet"

# Verify VPC association
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"

# Check available IPs
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].AvailableIpAddressCount'

# Verify AZ placement
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].AvailabilityZone'
```

## Troubleshooting

### Issue: Subnet Not Created

**Symptoms:**
```
Error: Error creating subnet: InvalidSubnet.Conflict
```

**Solution:**
- Verify CIDR block is within VPC CIDR range
- Check for overlapping subnet CIDR blocks
- Ensure VPC exists before creating subnets

### Issue: VPC ID Not Found

**Symptoms:**
```
Error: Invalid VPC ID: vpc not found
```

**Solution:**
- Verify `vpc_name` matches exactly with VPC key
- Check workspace: `terraform workspace show`
- Ensure VPC module ran successfully
- Check `terraform output vpc_ids`

### Issue: Availability Zone Not Available

**Symptoms:**
```
Error: Invalid Availability Zone
```

**Solution:**
- Check available AZs: `aws ec2 describe-availability-zones --region ap-south-1`
- Reduce `az_index` values to match available AZs
- Some regions have only 2 AZs (use az_index 0, 1 only)

### Issue: Insufficient IP Addresses

**Symptoms:**
```
Error: Insufficient IP addresses in subnet
```

**Solution:**
- Use larger subnet size (e.g., `/23` instead of `/24`)
- Create additional subnets
- Clean up unused ENIs in the subnet

### Issue: Subnet Reference Not Found

**Symptoms:**
```
Error: lookup(local.subnet_id_by_name, "my_subnet") - key not found
```

**Solution:**
- Verify subnet key matches exactly in other modules
- Check subnet was created: `terraform output subnet_id`
- Ensure you're in correct workspace

## Common CIDR Allocation Mistakes

### ❌ Wrong: Overlapping Subnets
```hcl
subnet1 = { cidr_block = "10.0.1.0/24" }  # 10.0.1.0 - 10.0.1.255
subnet2 = { cidr_block = "10.0.1.128/25" } # Overlaps with subnet1!
```

### ✅ Correct: Non-Overlapping Subnets
```hcl
subnet1 = { cidr_block = "10.0.1.0/24" }  # 10.0.1.0 - 10.0.1.255
subnet2 = { cidr_block = "10.0.2.0/24" }  # 10.0.2.0 - 10.0.2.255
```

### ❌ Wrong: Subnet Larger Than VPC
```hcl
# VPC: 10.0.0.0/16
subnet = { cidr_block = "10.0.0.0/8" }  # Larger than VPC!
```

### ✅ Correct: Subnet Within VPC
```hcl
# VPC: 10.0.0.0/16
subnet = { cidr_block = "10.0.1.0/24" }  # Within VPC range
```

## High Availability Considerations

### Single AZ (❌ Not Recommended for Production)
```
[AZ1: Public + Private]
[AZ2: Empty]
```
- Single point of failure
- Lower cost
- **Use only for dev/test**

### Multi-AZ (✅ Recommended for Production)
```
[AZ1: Public + Private]
[AZ2: Public + Private]
```
- Fault tolerant
- Higher cost
- **Required for production**

### Multi-AZ with NAT per AZ (✅ Highest Availability)
```
[AZ1: Public + NAT] → [AZ1: Private]
[AZ2: Public + NAT] → [AZ2: Private]
```
- Independent AZ failure
- Highest cost
- **Best for critical production**


## Module Metadata

- **Author** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15


## Support

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]

## AWS Resource Reference

- **Resource Type:** `aws_subnet`
- **AWS Documentation:** https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html
- **Terraform Documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet


[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139