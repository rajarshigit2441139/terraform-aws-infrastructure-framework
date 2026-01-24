# VPC Module

## Overview

This module creates AWS Virtual Private Cloud (VPC) resources. It serves as the **foundation** of your network infrastructure, providing an isolated virtual network environment for all your AWS resources.

## Module Purpose

- Creates VPCs with customizable CIDR blocks
- Configures DNS resolution and hostname settings
- Supports multiple VPCs per workspace
- Implements proper tagging strategy
- Provides outputs for resource linking in parent modules

## Module Location

```
modules/vpc/
├── main.tf          # VPC resource definition
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resource Definition

The module uses `aws_vpc` resource with `for_each` meta-argument to create multiple VPCs from a map of configurations:

```hcl
resource "aws_vpc" "vpc_module" {
  for_each             = var.vpc_parameters
  cidr_block           = each.value.cidr_block
  enable_dns_support   = each.value.enable_dns_support
  enable_dns_hostnames = each.value.enable_dns_hostnames
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

### `vpc_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** `{}`

Map of VPC configurations where each key represents a unique VPC identifier.

#### Object Structure

```hcl
{
  cidr_block           = string                      # REQUIRED
  enable_dns_support   = optional(bool, true)        # OPTIONAL
  enable_dns_hostnames = optional(bool, true)        # OPTIONAL
  tags                 = optional(map(string), {})   # OPTIONAL
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `cidr_block` | string | ✅ Yes | - | IPv4 CIDR block for the VPC (e.g., "10.0.0.0/16") |
| `enable_dns_support` | bool | ❌ No | `true` | Enable DNS resolution in the VPC |
| `enable_dns_hostnames` | bool | ❌ No | `true` | Enable DNS hostnames for EC2 instances |
| `tags` | map(string) | ❌ No | `{}` | Additional tags to apply to the VPC |

#### CIDR Block Guidelines

- **Minimum size:** `/28` (16 IP addresses)
- **Maximum size:** `/16` (65,536 IP addresses)
- **Recommended for production:** `/16` (provides maximum flexibility)
- **Common ranges:**
  - Development: `10.10.0.0/16`
  - QA/Staging: `10.20.0.0/16`
  - Production: `10.30.0.0/16`

#### DNS Configuration

**`enable_dns_support`:**
- Enables Amazon-provided DNS server at `VPC_CIDR_BASE + 2` (e.g., 10.0.0.2)
- Required for VPC endpoints and other AWS services
- **Recommendation:** Always keep enabled (`true`)

**`enable_dns_hostnames`:**
- Assigns public DNS hostnames to instances with public IPs
- Required for EC2 instances to receive public DNS names
- **Recommendation:** Enable for public-facing resources (`true`)

## Outputs

### `vpcs`

**Type:** `map(object)`  
**Description:** Map of VPC outputs indexed by VPC name (key)

#### Output Structure

```hcl
{
  "<vpc_key>" = {
    name       = string  # VPC name (same as key)
    id         = string  # VPC ID (vpc-xxxxx)
    cidr_block = string  # VPC CIDR block
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | VPC name from tags | "dev_vpc" |
| `id` | string | AWS VPC ID | "vpc-0abc123def456" |
| `cidr_block` | string | VPC CIDR block | "10.10.0.0/16" |

## Usage in Root Module

### Called From

`02_vpc.tf` in the root module

### Module Call

```hcl
module "chat_app_vpc" {
  source         = "./modules/vpc"
  vpc_parameters = lookup(var.vpc_parameters, terraform.workspace, {} )
}
```

### Workspace Selection

The module uses `lookup()` to retrieve workspace-specific VPC configurations:
- `terraform.workspace = "default"` → Uses `var.vpc_parameters.default`
- `terraform.workspace = "qe"` → Uses `var.vpc_parameters.qe`
- `terraform.workspace = "prod"` → Uses `var.vpc_parameters.prod`

### Resource Extraction

VPC IDs are extracted in `01_locals.tf`:

```hcl
locals {
  vpc_id_by_name = { 
    for name, vpc in module.chat_app_vpc.vpcs : name => vpc.id 
  }
}
```

This allows other modules to reference VPCs by name instead of hardcoded IDs.

## Configuration Examples

### Example 1: Single VPC (Basic)

```hcl
vpc_parameters = {
  default = {
    my_vpc = {
      cidr_block = "10.0.0.0/16"
    }
  }
}
```

**Result:**
- VPC with CIDR `10.0.0.0/16`
- DNS support: enabled (default)
- DNS hostnames: enabled (default)
- Name tag: "my_vpc"

### Example 2: VPC with Custom DNS Settings

```hcl
vpc_parameters = {
  default = {
    isolated_vpc = {
      cidr_block           = "172.16.0.0/16"
      enable_dns_support   = true
      enable_dns_hostnames = false
      tags = {
        Environment = "dev"
        Purpose     = "isolated-testing"
      }
    }
  }
}
```

### Example 3: Multi-Environment VPCs

```hcl
vpc_parameters = {
  # Development
  default = {
    dev_vpc = {
      cidr_block = "10.10.0.0/16"
      tags = {
        Environment = "dev"
        CostCenter  = "engineering"
      }
    }
  }
  
  # QA
  qe = {
    qe_vpc = {
      cidr_block = "10.20.0.0/16"
      tags = {
        Environment = "qe"
        CostCenter  = "qa-team"
      }
    }
  }
  
  # Production
  prod = {
    prod_vpc = {
      cidr_block = "10.30.0.0/16"
      tags = {
        Environment = "prod"
        CostCenter  = "production"
        Compliance  = "required"
      }
    }
  }
}
```

### Example 4: Multiple VPCs in Same Environment

```hcl
vpc_parameters = {
  default = {
    frontend_vpc = {
      cidr_block = "10.1.0.0/16"
      tags = {
        Purpose = "frontend-services"
      }
    }
    
    backend_vpc = {
      cidr_block = "10.2.0.0/16"
      tags = {
        Purpose = "backend-services"
      }
    }
    
    data_vpc = {
      cidr_block = "10.3.0.0/16"
      enable_dns_hostnames = false
      tags = {
        Purpose = "data-layer"
      }
    }
  }
}
```

## Lifecycle Management

### Prevent Destroy

The module has `prevent_destroy = false`, meaning VPCs **can be destroyed** during `terraform destroy`.

**To protect production VPCs:**

Modify `main.tf`:
```hcl
lifecycle {
  prevent_destroy = true  # Prevents accidental deletion
  ignore_changes  = [tags]
}
```

### Ignore Changes

The module ignores changes to tags after initial creation to prevent unnecessary updates:

```hcl
ignore_changes = [tags]
```

**To allow tag updates:**

Remove or comment out the `ignore_changes` block.

## Dependencies

### This Module Depends On
- **None** (VPC is a foundational resource)

### Modules That Depend On This
- `modules/subnet` - Requires VPC ID
- `modules/igw` - Requires VPC ID
- `modules/security_group` - Requires VPC ID
- `modules/vpc_endpoint` - Requires VPC ID

## Output Usage by Other Modules

### In Subnets Module

```hcl
# 02_vpc.tf
locals {
  generated_subnet_parameters = {
    for workspace, subnets in var.subnet_parameters :
    workspace => {
      for name, subnet in subnets :
      name => merge(
        subnet,
        { vpc_id = local.vpc_id_by_name[subnet.vpc_name] }
      )
    }
  }
}
```

### In Security Groups Module

```hcl
# 03_security_group.tf
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

## Tagging Strategy

### Automatic Tags

The module automatically adds a `Name` tag with the VPC key:

```hcl
tags = merge(each.value.tags, {
  Name : each.key
})
```

**Example:**
```hcl
vpc_parameters = {
  default = {
    my_vpc = {
      cidr_block = "10.0.0.0/16"
      tags = {
        Environment = "dev"
      }
    }
  }
}

# Results in tags:
# Name        = "my_vpc"
# Environment = "dev"
```

### Recommended Tag Schema

```hcl
tags = {
  Name        = "Automatic (from key)"
  Environment = "dev|qe|prod"
  Project     = "project-name"
  Owner       = "team-name"
  CostCenter  = "cost-center-id"
  ManagedBy   = "terraform"
  Workspace   = "workspace-name"
}
```

## Best Practices

### CIDR Planning

✅ **Do:**
- Plan CIDR blocks across all environments to avoid overlaps
- Use `/16` for production (maximum flexibility)
- Reserve space for future expansion
- Document CIDR allocation in a central registry

❌ **Don't:**
- Use overlapping CIDR blocks between VPCs you might need to peer
- Choose CIDR blocks that conflict with on-premises networks
- Use `/28` or smaller for production VPCs

### DNS Configuration

✅ **Do:**
- Keep `enable_dns_support = true` for AWS service integration
- Enable `enable_dns_hostnames` for public-facing resources
- Test DNS resolution after VPC creation

❌ **Don't:**
- Disable DNS support unless you have custom DNS infrastructure
- Forget to enable DNS hostnames for EC2 instances with public IPs

### Naming Convention

✅ **Do:**
- Use descriptive VPC keys: `dev_vpc`, `prod_frontend_vpc`
- Include environment in the name
- Keep names consistent across workspaces
- Use lowercase with underscores

❌ **Don't:**
- Use generic names: `vpc1`, `vpc2`
- Mix naming conventions
- Use spaces or special characters

### Multi-Environment Strategy

✅ **Do:**
- Use separate CIDR blocks per environment (10.x, 20.x, 30.x)
- Maintain consistent naming across environments
- Apply environment-specific tags
- Document VPC purpose and ownership

## Validation

### After Creation

```bash
# Verify VPC creation
terraform output vpc_ids

# Check VPC details in AWS
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=my_vpc"

# Verify DNS settings
aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsSupport
aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsHostnames
```

## Troubleshooting

### Issue: VPC Not Created

**Symptoms:**
```
Error: Error creating VPC: VpcLimitExceeded
```

**Solution:**
- Check VPC quota in your AWS account (default: 5 per region)
- Request quota increase via AWS Service Quotas
- Delete unused VPCs in the region

### Issue: CIDR Block Conflict

**Symptoms:**
```
Error: Invalid CIDR block: Overlaps with existing VPC
```

**Solution:**
- Verify CIDR blocks don't overlap with existing VPCs
- Check VPC peering requirements
- Adjust CIDR allocation

### Issue: Output Not Available

**Symptoms:**
```
Error: lookup(local.vpc_id_by_name, "my_vpc") - key not found
```

**Solution:**
- Ensure VPC key matches exactly in other modules
- Verify workspace is correct: `terraform workspace show`
- Check that VPC was created: `terraform output vpc_ids`

## Module Metadata

- **Author** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15

## Support

For issues or questions:

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]



## AWS Resource Reference

- **Resource Type:** `aws_vpc`
- **AWS Documentation:** https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html
- **Terraform Documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc

[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139
