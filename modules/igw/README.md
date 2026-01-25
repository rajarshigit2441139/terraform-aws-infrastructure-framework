# Internet Gateway Module

## Overview

This module creates AWS Internet Gateways (IGW). An Internet Gateway is a horizontally scaled, redundant, and highly available VPC component that allows communication between instances in your VPC and the internet. It provides a target in your VPC route tables for internet-routable traffic.

## Module Purpose

- Creates Internet Gateways attached to VPCs
- Enables internet connectivity for public subnets
- Provides gateway IDs for route table configuration
- Supports tagging and lifecycle management
- Manages IGW–VPC attachments automatically

## Module Location

```text
modules/igw/
├── main.tf          # Internet Gateway resources
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **1 type of resource**:

1. **Internet Gateway** — `aws_internet_gateway`

### Internet Gateway Definition

```hcl
resource "aws_internet_gateway" "igw_module" {
  for_each = var.igw_parameters
  vpc_id   = each.value.vpc_id
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

### `igw_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** `{}`

Map of Internet Gateway configurations.

#### Object Structure

```hcl
{
  vpc_name = string                      # REQUIRED (for reference)
  vpc_id   = string                      # REQUIRED (auto-injected)
  tags     = optional(map(string), {})   # OPTIONAL
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `vpc_name` | string | ✅ Yes | - | VPC key reference (converted to `vpc_id` by root) |
| `vpc_id` | string | ✅ Yes* | - | VPC ID (auto-injected by root module) |
| `tags` | map(string) | ❌ No | `{}` | Additional tags for the Internet Gateway |

> **Note:** `vpc_id` is **auto-injected** by the parent module from `vpc_name`.

## Outputs

### `igws`

**Type:** `map(object)`  
**Description:** Map of Internet Gateway outputs indexed by IGW name (key)

#### Output Structure

```hcl
{
  "" = {
    id = string  # Internet Gateway ID (igw-xxxxx)
  }
}
```

#### Output Example

```hcl
{
  "main_igw" = {
    id = "igw-0abc123def456789"
  }
  "backup_igw" = {
    id = "igw-0def456abc789012"
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | AWS Internet Gateway ID | `"igw-0abc123def456789"` |

## Usage in Root Module

### Called From

`05_ig.tf` in the root module (create this file if it doesn't exist)

### Module Call

```hcl
module "chat_app_ig" {
  source         = "./modules/igw"
  igw_parameters = lookup(local.generated_igw_parameters, terraform.workspace, {} )
  depends_on     = [module.chat_app_vpc]
}
```

### Dynamic Parameter Generation

#### Internet Gateway with VPC ID Injection

```hcl
# In root module (05_ig.tf)
locals {
  generated_igw_parameters = {
    for workspace, igws in var.igw_parameters :
    workspace => {
      for name, igw in igws :
      name => merge(
        igw,
        { vpc_id = local.vpc_id_by_name[igw.vpc_name] }
      )
    }
  }
}
```

**What this does:**

1. Iterates through all workspaces in `var.igw_parameters`
2. For each IGW in each workspace
3. Merges the original configuration with the resolved VPC ID
4. Looks up VPC ID using `vpc_name` from `local.vpc_id_by_name`

### IGW ID Extraction for Route Tables

```hcl
# In 01_locals.tf
locals {
  extract_internet_gateway_ids = {
    for name, igw_obj in module.chat_app_ig.igws :
    name => igw_obj.id
  }
}

# Used in route table module
module "chat_app_rt" {
  source               = "./modules/rt"
  internet_gateway_ids = local.extract_internet_gateway_ids
  # ...
}
```

## Configuration Examples

### Example 1: Basic Internet Gateway

```hcl
igw_parameters = {
  default = {
    main_igw = {
      vpc_name = "main_vpc"
      tags = {
        Environment = "production"
        Purpose     = "internet-access"
      }
    }
  }
}
```

**Use Case:** Single IGW for a VPC with public subnets.

---

### Example 2: Multi-Environment Internet Gateways

```hcl
igw_parameters = {
  # Development
  default = {
    dev_igw = {
      vpc_name = "dev_vpc"
      tags = {
        Environment = "dev"
        Team        = "platform"
      }
    }
  }

  # QE/Staging
  qe = {
    qe_igw = {
      vpc_name = "qe_vpc"
      tags = {
        Environment = "qe"
        Team        = "platform"
      }
    }
  }

  # Production
  prod = {
    prod_igw = {
      vpc_name = "prod_vpc"
      tags = {
        Environment = "prod"
        Team        = "platform"
        Critical    = "true"
      }
    }
  }
}
```

**Use Case:** Separate IGWs for each environment workspace.

---

### Example 3: Multiple VPCs with Internet Gateways

```hcl
igw_parameters = {
  default = {
    app_vpc_igw = {
      vpc_name = "app_vpc"
      tags = {
        VPC  = "application"
        Type = "public-access"
      }
    }

    mgmt_vpc_igw = {
      vpc_name = "mgmt_vpc"
      tags = {
        VPC  = "management"
        Type = "admin-access"
      }
    }
  }
}
```

**Use Case:** Multiple VPCs in same environment, each with its own IGW.

---

### Example 4: Tagged for Cost Allocation

```hcl
igw_parameters = {
  default = {
    ecommerce_igw = {
      vpc_name = "ecommerce_vpc"
      tags = {
        Environment    = "production"
        Application    = "ecommerce"
        CostCenter     = "engineering"
        Owner          = "platform-team"
        ManagedBy      = "terraform"
        BusinessUnit   = "retail"
        ComplianceReq  = "pci-dss"
      }
    }
  }
}
```

**Use Case:** Comprehensive tagging for cost tracking and compliance.

---

### Example 5: Internet Gateway for EKS VPC

```hcl
igw_parameters = {
  default = {
    eks_cluster_igw = {
      vpc_name = "eks_vpc"
      tags = {
        Environment               = "production"
        Purpose                   = "eks-cluster"
        "kubernetes.io/role/elb"  = "1"  # For EKS load balancers
      }
    }
  }
}
```

**Use Case:** IGW for EKS cluster with public load balancers.

---

### Example 6: Disaster Recovery Setup

```hcl
igw_parameters = {
  default = {
    primary_igw = {
      vpc_name = "primary_vpc"
      tags = {
        Environment = "production"
        Region      = "ap-south-1"
        Role        = "primary"
      }
    }

    dr_igw = {
      vpc_name = "dr_vpc"
      tags = {
        Environment = "production"
        Region      = "ap-south-1"
        Role        = "disaster-recovery"
      }
    }
  }
}
```

**Use Case:** Separate VPCs for primary and DR environments.

## Complete Usage Example

### Root Module Files

#### `05_ig.tf`

```hcl
# -------------- Internet Gateway Module -------------- #

# Inject VPC IDs for Internet Gateways
locals {
  generated_igw_parameters = {
    for workspace, igws in var.igw_parameters :
    workspace => {
      for name, igw in igws :
      name => merge(
        igw,
        { vpc_id = local.vpc_id_by_name[igw.vpc_name] }
      )
    }
  }
}

module "chat_app_ig" {
  source         = "./modules/igw"
  igw_parameters = lookup(local.generated_igw_parameters, terraform.workspace, {} )
  depends_on     = [module.chat_app_vpc]
}
```

#### `01_locals.tf`

```hcl
# Extract Internet Gateway IDs
locals {
  extract_internet_gateway_ids = {
    for name, igw_obj in module.chat_app_ig.igws :
    name => igw_obj.id
  }
}
```

#### `terraform.tfvars`

```hcl
# -------------- IGW Parameters -------------- #
igw_parameters = {
  default = {
    chat_app_dev_igw = {
      vpc_name = "chat_app_dev_vpc1"
      tags = {
        Environment = "dev"
        Purpose     = "public-internet-access"
      }
    }
  }

  qe = {
    chat_app_qe_igw = {
      vpc_name = "chat_app_qe_vpc1"
      tags = {
        Environment = "qe"
        Purpose     = "public-internet-access"
      }
    }
  }

  prod = {
    chat_app_prod_igw = {
      vpc_name = "chat_app_prod_vpc1"
      tags = {
        Environment = "prod"
        Purpose     = "public-internet-access"
      }
    }
  }
}
```

#### `variables.tf`

```hcl
# -------------- IGW Parameters -------------- #
variable "igw_parameters" {
  description = "IGW parameters"
  type = map(map(object({
    vpc_name = string
    tags     = optional(map(string), {})
  })))
  default = {}
}
```

## Integration with Route Tables

Once the Internet Gateway is created, it must be referenced in route tables:

```hcl
# Route table pointing to IGW
rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "main_vpc"
      routes = [
        {
          cidr_block  = "0.0.0.0/0"     # All internet traffic
          target_type = "igw"           # Internet Gateway
          target_key  = "main_igw"      # IGW key (resolved to ID)
        }
      ]
      tags = { Type = "public" }
    }
  }
}
```

## Network Architecture Patterns

### Pattern 1: Basic Public-Private Architecture

```text
┌─────────────────────────────────────────┐
│ VPC: 10.0.0.0/16                        │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────┐                    │
│ │ Internet Gateway│                    │
│ └────────┬────────┘                    │
│          │                             │
│          ▼                             │
│ ┌─────────────────┐                    │
│ │ Public Route    │                    │
│ │ Table           │                    │
│ │ 0.0.0.0/0 → IGW │                    │
│ └────────┬────────┘                    │
│          │                             │
│          ▼                             │
│ ┌─────────────────┐                    │
│ │ Public Subnets  │                    │
│ │ - Load Balancer │                    │
│ │ - Bastion       │                    │
│ └─────────────────┘                    │
│                                         │
│ ┌─────────────────┐                    │
│ │ NAT Gateway     │                    │
│ └────────┬────────┘                    │
│          │                             │
│          ▼                             │
│ ┌─────────────────┐                    │
│ │ Private Subnets │                    │
│ │ - Application   │                    │
│ │ - Database      │                    │
│ └─────────────────┘                    │
└─────────────────────────────────────────┘
```

---

### Pattern 2: Multi-Tier Web Application

```text
Internet
   │
   ▼
┌─────────────────┐
│ Internet Gateway│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Application     │
│ Load Balancer   │◄── Public Subnet (10.0.1.0/24)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Web Tier        │◄── Private Subnet (10.0.2.0/24)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ API Tier        │◄── Private Subnet (10.0.3.0/24)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Database Tier   │◄── Private Subnet (10.0.4.0/24)
└─────────────────┘
```

---

### Pattern 3: High Availability Multi-AZ

```text
                Internet
                   │
                   ▼
        ┌──────────────────────┐
        │  Internet Gateway    │
        └──────────┬───────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
         ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│  Public Subnet  │  │  Public Subnet  │
│      AZ1        │  │      AZ2        │
│ ┌─────────────┐ │  │ ┌─────────────┐ │
│ │ NAT Gateway │ │  │ │ NAT Gateway │ │
│ └──────┬──────┘ │  │ └──────┬──────┘ │
└────────┼────────┘  └────────┼────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│ Private Subnet  │  │ Private Subnet  │
│      AZ1        │  │      AZ2        │
└─────────────────┘  └─────────────────┘
```

## Best Practices

### Internet Gateway Design

✅ **Do:**

- Create one IGW per VPC (AWS enforces this)
- Attach IGW immediately after VPC creation
- Use descriptive names: `prod_igw`, `dev_igw`, `app_vpc_igw`
- Tag with Environment, Purpose, Team
- Include IGW in disaster recovery planning
- Document IGW dependencies

❌ **Don't:**

- Try to share IGW across VPCs (not possible)
- Delete IGW while route tables reference it
- Forget to create routes pointing to IGW
- Mix IGW names across environments

---

### Security Considerations

✅ **Do:**

- Use security groups to control inbound traffic
- Implement Network ACLs as additional layer
- Use VPC Flow Logs to monitor traffic
- Limit public subnet resources to minimum
- Use bastion hosts for SSH access
- Implement WAF for web applications

❌ **Don't:**

- Expose databases directly to internet
- Rely solely on IGW for security
- Allow unrestricted inbound rules
- Forget to monitor internet-bound traffic

---

### Tagging Strategy

✅ **Recommended Tags:**

```hcl
tags = {
  Name           = "Automatic (from key)"
  Environment    = "dev|qe|prod"
  VPC            = "vpc-name"
  Purpose        = "internet-access"
  ManagedBy      = "terraform"
  Team           = "platform|devops"
  CostCenter     = "cost-center-id"
  ComplianceReq  = "pci-dss|hipaa|none"
  BackupRequired = "true|false"
}
```

---

### High Availability

✅ **IGW is Highly Available by Default:**

- AWS manages IGW redundancy automatically
- Horizontally scaled across multiple AZs
- No single point of failure
- No user maintenance required

**However, you still need:**

- Multi-AZ NAT Gateways (1 per AZ)
- Multi-AZ application deployment
- Multi-AZ route tables

## Cost Analysis

### Internet Gateway Costs

| Component | Cost | Notes |
|-----------|------|-------|
| Internet Gateway | **FREE** | No hourly charges |
| IGW Data Processing | **FREE** | No per-GB charges |
| Data Transfer OUT | **$0.09/GB** | Internet egress |
| Data Transfer IN | **FREE** | Internet ingress |

**Cost Optimization Tips:**

1. ✅ IGW itself is free — no need to optimize
2. ✅ Focus on reducing data transfer OUT
3. ✅ Use VPC Endpoints for AWS services (saves NAT costs)
4. ✅ Implement CloudFront for static content (cheaper egress)
5. ✅ Compress data before sending

### Comparison with Other Gateways

| Gateway Type | Hourly Cost | Data Processing | Use Case |
|--------------|-------------|-----------------|----------|
| Internet Gateway | $0.00 | $0.00/GB | Public subnets |
| NAT Gateway | $0.045 | $0.045/GB | Private subnets |
| Transit Gateway | $0.05 | $0.02/GB | Multi-VPC/on-prem |
| VPN Gateway | $0.05 | $0.00/GB | VPN connections |

**Key Insight:** IGW is the most cost-effective option for internet connectivity.

## Dependencies

### This Module Depends On

- ✅ **VPC Module** — Must create VPC before Internet Gateway

### Modules That Depend On This

- ✅ **Route Table Module** — RTs reference IGW IDs for internet routes
- ✅ **NAT Gateway Module** — NAT must be in subnet with IGW route
- ⚠️ **Public Subnets** — Indirectly via route tables

### Dependency Chain

```text
VPC → IGW → Route Table → Subnet Association → EC2/EKS
```

## Lifecycle Management

### Prevent Destroy

Default: `prevent_destroy = false`

To protect critical Internet Gateways:

```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes  = [tags]
}
```

**Use for:** Production IGWs, critical infrastructure

### Ignore Changes

Tags are ignored by default to prevent unnecessary updates:

```hcl
ignore_changes = [tags]
```

### Replace Triggers

Changing these parameters will **replace** the Internet Gateway:

- `vpc_id`

Changing these will **update** in-place:

- `tags`

## Validation

### After Creation

```bash
# Verify IGW creation
terraform output igws_ids

# Check IGW details
aws ec2 describe-internet-gateways --internet-gateway-ids igw-xxxxx

# List all IGWs in your account
aws ec2 describe-internet-gateways

# Verify IGW is attached to VPC
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-xxxxx"

# Check IGW state
aws ec2 describe-internet-gateways \
  --internet-gateway-ids igw-xxxxx \
  --query 'InternetGateways[0].Attachments[0].State'
```

### Test Connectivity

```bash
# From EC2 instance in public subnet
ping 8.8.8.8  # Should work if route table configured

# Check route to IGW exists
aws ec2 describe-route-tables \
  --filters "Name=route.gateway-id,Values=igw-xxxxx"

# Verify public IP assignment
aws ec2 describe-instances \
  --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

## Troubleshooting

### Issue: Internet Gateway Not Attached

**Symptoms:**

```text
Error: resource aws_internet_gateway not found
```

**Diagnosis:**

```bash
aws ec2 describe-internet-gateways --internet-gateway-ids igw-xxxxx
```

**Solution:**

1. Verify VPC exists: `terraform output vpc_ids`
2. Check `vpc_id` is correct in IGW configuration
3. Ensure VPC is in correct workspace
4. Verify AWS credentials and permissions

---

### Issue: Cannot Delete Internet Gateway

**Symptoms:**

```text
Error: DependencyViolation - The internetGateway has dependencies
```

**Solution:**

1. Remove routes pointing to IGW from all route tables
2. Terminate instances with Elastic IPs in public subnets
3. Delete NAT Gateways
4. Remove IGW from route table associations
5. Then delete IGW

```bash
# Find route tables using this IGW
aws ec2 describe-route-tables \
  --filters "Name=route.gateway-id,Values=igw-xxxxx"

# Remove routes
aws ec2 delete-route \
  --route-table-id rtb-xxxxx \
  --destination-cidr-block 0.0.0.0/0
```

---

### Issue: No Internet Connectivity Despite IGW

**Symptoms:**

```text
Instances in public subnet cannot reach internet
```

**Diagnosis Checklist:**

- [ ] IGW attached to VPC
- [ ] Route table has `0.0.0.0/0 → IGW` route
- [ ] Route table associated with subnet
- [ ] Subnet has `map_public_ip_on_launch = true`
- [ ] Instance has public IP or Elastic IP
- [ ] Security group allows outbound traffic
- [ ] Network ACL allows outbound traffic

**Solution:**

```bash
# 1. Verify IGW attachment
aws ec2 describe-internet-gateways --internet-gateway-ids igw-xxxxx

# 2. Check route table
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx

# 3. Verify subnet association
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# 4. Check instance has public IP
aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# 5. Test from instance
curl -I https://google.com
```

---

### Issue: VPC ID Not Resolved

**Symptoms:**

```text
Error: Invalid VPC ID
```

**Solution:**

- Verify `vpc_name` in IGW definition matches VPC key exactly
- Check VPC was created: `terraform output vpc_ids`
- Ensure you're in correct workspace: `terraform workspace show`
- Verify `local.vpc_id_by_name` has the VPC
- Check `depends_on = [module.chat_app_vpc]`

---

### Issue: Multiple IGWs Error

**Symptoms:**

```text
Error: A VPC may have no more than one Internet Gateway attached at a time
```

**Solution:**

- AWS allows only **ONE** IGW per VPC
- Check existing IGWs:

  ```bash
  aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=vpc-xxxxx"
  ```

- Use the existing IGW or detach it before creating a new one
- Review your configuration for duplicate IGW definitions



## Module Metadata

- **Author:** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Networking/Gateway
- **Complexity:** Low (simple, single-purpose resource)

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]

## AWS Resource Reference

- **Resource Type:** `aws_internet_gateway`
- **AWS Documentation:** https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html
- **Terraform Documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
- **AWS Service Limits:** https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html


[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139
