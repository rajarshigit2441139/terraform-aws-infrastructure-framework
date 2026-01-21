# Elastic IP (EIP) Module

## Overview

This module creates and manages AWS Elastic IP (EIP) addresses. Elastic IPs are static, public IPv4 addresses designed for dynamic cloud computing. They allow you to mask instance or network interface failures by rapidly remapping addresses to other instances in your account.

## Module Purpose

- Allocates static public IPv4 addresses
- Associates EIPs with EC2 instances or network interfaces
- Supports NAT Gateway allocations
- Enables predictable public IP addressing for resources
- Provides outputs for resource linking in parent modules
- Manages EIP lifecycle and tagging

## Module Location

```
modules/eip/
├── main.tf          # EIP resource definitions
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **1 type of resource**:

1. **Elastic IP Addresses** - `aws_eip`

### EIP Definition

```hcl
resource "aws_eip" "example" {
  for_each                  = var.eip_parameters
  domain                    = each.value.domain
  network_interface         = each.value.network_interface
  associate_with_private_ip = each.value.associate_with_private_ip
  instance                  = each.value.instance
  public_ipv4_pool          = each.value.public_ipv4_pool
  ipam_pool_id              = each.value.ipam_pool_id

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

### `eip_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** N/A

Map of Elastic IP configurations.

#### Object Structure

```hcl
{
  domain                    = optional(string)      # OPTIONAL
  network_interface         = optional(string)      # OPTIONAL
  associate_with_private_ip = optional(string)      # OPTIONAL
  instance                  = optional(string)      # OPTIONAL
  public_ipv4_pool          = optional(string)      # OPTIONAL
  ipam_pool_id              = optional(string)      # OPTIONAL
  tags                      = map(string)           # REQUIRED
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `domain` | string | ❌ No | `"vpc"` | Indicates if this EIP is for use in VPC (`"vpc"`) or EC2-Classic (`"standard"`) |
| `network_interface` | string | ❌ No | `null` | Network interface ID to associate with |
| `associate_with_private_ip` | string | ❌ No | `null` | Private IP address to associate with the EIP |
| `instance` | string | ❌ No | `null` | EC2 instance ID to associate with |
| `public_ipv4_pool` | string | ❌ No | `null` | EC2 IPv4 address pool identifier |
| `ipam_pool_id` | string | ❌ No | `null` | Amazon-provided IPv6 CIDR block ID |
| `tags` | map(string) | ✅ Yes | - | Tags to apply to the EIP |

#### Domain Values

- `"vpc"` - For use in VPC (default, recommended)
- `"standard"` - For use in EC2-Classic (legacy)

**Note:** Most modern AWS accounts use VPC domain. EC2-Classic is deprecated.

#### Association Methods

You can associate an EIP in multiple ways:

1. **No Association** - Just allocate, associate later
2. **Instance Association** - Provide `instance` ID
3. **Network Interface Association** - Provide `network_interface` ID
4. **NAT Gateway** - Reference EIP in NAT Gateway resource (most common in this framework)

## Outputs

### `eips`

**Type:** `map(object)`  
**Description:** Map of Elastic IP outputs indexed by EIP name (key)

#### Output Structure

```hcl
{
  "<eip_key>" = {
    id                = string  # EIP ID (eipalloc-xxxxx)
    public_ip         = string  # Public IPv4 address
    private_ip        = string  # Private IP if associated
    public_dns        = string  # Public DNS name
    network_interface = string  # Associated network interface ID
    instance          = string  # Associated instance ID
    allocation_id     = string  # Allocation ID (same as id)
    association_id    = string  # Association ID if associated
    domain            = string  # "vpc" or "standard"
    tags              = map     # All tags including Name
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | EIP allocation ID | "eipalloc-0abc123def456" |
| `public_ip` | string | Allocated public IPv4 address | "203.0.113.25" |
| `private_ip` | string | Associated private IP address | "10.0.1.50" |
| `public_dns` | string | Public DNS hostname | "ec2-203-0-113-25.compute-1.amazonaws.com" |
| `network_interface` | string | Network interface ID | "eni-0abc123def" |
| `instance` | string | EC2 instance ID | "i-0abc123def456" |
| `allocation_id` | string | EIP allocation ID (same as id) | "eipalloc-0abc123def456" |
| `association_id` | string | Association ID if attached | "eipassoc-0xyz789" |
| `domain` | string | VPC or standard | "vpc" |
| `tags` | map(string) | All resource tags | `{ Name = "nat_eip", Environment = "prod" }` |

## Usage in Root Module

### Called From

`04_eip.tf` in the root module

### Module Call

```hcl
module "chat_app_eip" {
  source         = "./modules/eip"
  eip_parameters = lookup(var.eip_parameters, terraform.workspace, {} )
}
```

### Dynamic Parameter Generation

EIP parameters are workspace-scoped directly from variables:

**In `variables.tf` (root):**
```hcl
variable "eip_parameters" {
  type = map(map(object({
    domain                    = optional(string)
    network_interface         = optional(string)
    associate_with_private_ip = optional(string)
    instance                  = optional(string)
    public_ipv4_pool          = optional(string)
    ipam_pool_id              = optional(string)
    tags                      = map(string)
  })))
}
```

**In `terraform.tfvars`:**
```hcl
eip_parameters = {
  default = {
    chat_app_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "dev"
        Purpose     = "NAT Gateway"
      }
    }
  }
  
  prod = {
    prod_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        Purpose     = "NAT Gateway"
      }
    }
  }
}
```

### EIP ID Extraction

EIP allocation IDs are extracted in `01_locals.tf`:

```hcl
locals {
  eip_id_by_name = { 
    for name, eip in module.chat_app_eip.eips : 
    name => eip.id 
  }
}
```

### Usage by NAT Gateway Module

EIPs are primarily used for NAT Gateways in this framework:

**In `05_gateway.tf`:**
```hcl
locals {
  generated_nat_gateway_parameters = {
    for workspace, nat_gateways in var.nat_gateway_parameters :
    workspace => {
      for name, nat_gateway in nat_gateways :
      name => merge(
        nat_gateway,
        { 
          subnet_id     = local.subnet_id_by_name[nat_gateway.subnet_name]
          allocation_id = local.eip_id_by_name[nat_gateway.eip_name_for_allocation_id]
        }
      )
    }
  }
}

module "chat_app_nat" {
  source                 = "./modules/nat_gw"
  nat_gateway_parameters = lookup(local.generated_nat_gateway_parameters, terraform.workspace, {} )
  depends_on             = [module.chat_app_eip, module.chat_app_ig]
}
```

## Configuration Examples

### Example 1: Basic EIP for NAT Gateway

```hcl
eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags = {
        Name        = "nat-gateway-eip"
        Environment = "dev"
        Purpose     = "NAT Gateway"
      }
    }
  }
}
```

**Result:**
- Allocates a VPC Elastic IP
- Not associated immediately
- Used later by NAT Gateway resource

### Example 2: Multiple EIPs for Multi-AZ NAT Gateways

```hcl
eip_parameters = {
  default = {
    nat_eip_az1 = {
      domain = "vpc"
      tags = {
        Name        = "nat-gateway-eip-az1"
        Environment = "dev"
        AZ          = "us-east-1a"
        Purpose     = "NAT Gateway"
      }
    }
    
    nat_eip_az2 = {
      domain = "vpc"
      tags = {
        Name        = "nat-gateway-eip-az2"
        Environment = "dev"
        AZ          = "us-east-1b"
        Purpose     = "NAT Gateway"
      }
    }
    
    nat_eip_az3 = {
      domain = "vpc"
      tags = {
        Name        = "nat-gateway-eip-az3"
        Environment = "dev"
        AZ          = "us-east-1c"
        Purpose     = "NAT Gateway"
      }
    }
  }
}
```

**Use Case:** High-availability NAT Gateways in multiple availability zones

### Example 3: EIP Associated with EC2 Instance

```hcl
eip_parameters = {
  default = {
    bastion_eip = {
      domain   = "vpc"
      instance = "i-0abc123def456789"  # Bastion host instance ID
      tags = {
        Name        = "bastion-host-eip"
        Environment = "dev"
        Purpose     = "Bastion Host"
      }
    }
  }
}
```

**Use Case:** Static public IP for bastion/jump host

### Example 4: EIP Associated with Network Interface

```hcl
eip_parameters = {
  default = {
    lb_eip = {
      domain                    = "vpc"
      network_interface         = "eni-0xyz789abc123"
      associate_with_private_ip = "10.0.1.100"
      tags = {
        Name        = "load-balancer-eip"
        Environment = "dev"
        Purpose     = "Network Load Balancer"
      }
    }
  }
}
```

**Use Case:** Network Load Balancer with static IP

### Example 5: EIP from Custom IP Pool

```hcl
eip_parameters = {
  default = {
    custom_pool_eip = {
      domain           = "vpc"
      public_ipv4_pool = "ipv4pool-ec2-012345abcdef"
      tags = {
        Name        = "custom-pool-eip"
        Environment = "prod"
        IPSource    = "BYOIP"
      }
    }
  }
}
```

**Use Case:** Using Bring Your Own IP (BYOIP) address pool

### Example 6: Multi-Environment EIPs

```hcl
eip_parameters = {
  # Development
  default = {
    dev_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "dev"
        CostCenter  = "engineering"
      }
    }
  }
  
  # QE/Staging
  qe = {
    qe_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "qe"
        CostCenter  = "qa"
      }
    }
  }
  
  # Production
  prod = {
    prod_nat_eip_az1 = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        AZ          = "us-east-1a"
        CostCenter  = "production"
      }
    }
    
    prod_nat_eip_az2 = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        AZ          = "us-east-1b"
        CostCenter  = "production"
      }
    }
  }
}
```

**Pattern:** Different EIP configurations per environment

## EIP Use Cases

### 1. NAT Gateway (Most Common)

**Scenario:** Private subnet instances need internet access

```hcl
# Step 1: Allocate EIP
eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags   = { Purpose = "NAT" }
    }
  }
}

# Step 2: Create NAT Gateway (in NAT module)
nat_gateway_parameters = {
  default = {
    main_nat = {
      subnet_name                = "public_subnet"
      eip_name_for_allocation_id = "nat_eip"  # References EIP
    }
  }
}
```

**Traffic Flow:**
```
Private Subnet → NAT Gateway (using EIP) → Internet Gateway → Internet
```

### 2. Bastion/Jump Host

**Scenario:** Secure SSH access to private instances

```hcl
eip_parameters = {
  default = {
    bastion_eip = {
      domain   = "vpc"
      instance = aws_instance.bastion.id
      tags     = { Purpose = "Bastion" }
    }
  }
}
```

**Benefits:**
- ✅ Consistent SSH endpoint
- ✅ Can whitelist in firewalls
- ✅ Survives instance replacements (if reassociated)

### 3. Network Load Balancer

**Scenario:** Static IPs required for NLB

```hcl
eip_parameters = {
  default = {
    nlb_eip_az1 = {
      domain = "vpc"
      tags   = { Purpose = "NLB", AZ = "az1" }
    }
    nlb_eip_az2 = {
      domain = "vpc"
      tags   = { Purpose = "NLB", AZ = "az2" }
    }
  }
}
```

**Use Case:**
- Firewall whitelisting
- DNS A-record pointing
- Compliance requirements

### 4. VPN Endpoint

**Scenario:** Customer-managed VPN with static IP

```hcl
eip_parameters = {
  default = {
    vpn_eip = {
      domain   = "vpc"
      instance = aws_instance.vpn_server.id
      tags     = { Purpose = "VPN" }
    }
  }
}
```

### 5. BYOIP (Bring Your Own IP)

**Scenario:** Use organization's owned IP range

```hcl
eip_parameters = {
  default = {
    byoip_eip = {
      domain           = "vpc"
      public_ipv4_pool = "ipv4pool-ec2-012345"
      tags             = { Source = "BYOIP" }
    }
  }
}
```

## Lifecycle Management

### Prevent Destroy

Default: `prevent_destroy = false`

To protect critical EIPs (e.g., production NAT):

```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes  = [tags]
}
```

**When to use:**
- Production NAT Gateway EIPs
- EIPs referenced in DNS records
- EIPs whitelisted in external systems

### Ignore Changes

Tags are ignored by default to prevent unnecessary updates:

```hcl
ignore_changes = [tags]
```

### EIP Release

When you destroy an EIP:
- ✅ EIP is released back to AWS pool
- ✅ Public IP becomes unavailable
- ⚠️ Any resources using it will lose connectivity
- ⚠️ You may get a different IP if you recreate

## Dependencies

### This Module Depends On
- None - EIPs are foundational and can be created independently

### Modules That Depend On This
- ✅ **NAT Gateway Module** - Requires EIP allocation IDs
- ECS/EKS tasks with public IPs (less common)
- EC2 instances requiring static public IPs

## Output Usage by Other Modules

### In NAT Gateway Module

**In `05_gateway.tf`:**
```hcl
# Extract EIP allocation IDs
locals {
  eip_id_by_name = { 
    for name, eip in module.chat_app_eip.eips : 
    name => eip.id 
  }
}

# Inject into NAT Gateway parameters
locals {
  generated_nat_gateway_parameters = {
    for workspace, nat_gateways in var.nat_gateway_parameters :
    workspace => {
      for name, nat_gateway in nat_gateways :
      name => merge(
        nat_gateway,
        { 
          allocation_id = local.eip_id_by_name[nat_gateway.eip_name_for_allocation_id]
        }
      )
    }
  }
}
```

### Direct Reference Example

```hcl
# Output EIP public IP for documentation
output "nat_gateway_ip" {
  value = module.chat_app_eip.eips["nat_eip"].public_ip
}

# Use in scripts or external systems
output "bastion_public_ip" {
  value       = module.chat_app_eip.eips["bastion_eip"].public_ip
  description = "SSH to this IP to access bastion host"
}
```

## Best Practices

### EIP Allocation

✅ **Do:**
- Allocate EIPs before NAT Gateways
- Use descriptive names: `nat_eip_az1`, `bastion_eip`
- Tag with purpose and environment
- Document which EIPs are used where
- Use workspace-specific EIP counts (dev: 1, prod: 3)

❌ **Don't:**
- Over-allocate EIPs (AWS has account limits)
- Use generic names: `eip1`, `eip2`
- Forget to tag EIPs
- Allocate EIPs without associating them (costs money)
- Use the same EIP for multiple environments

### Cost Optimization

✅ **Do:**
- Release unused EIPs immediately
- Share NAT Gateways when possible
- Monitor EIP usage with AWS Cost Explorer
- Use VPC Endpoints instead of NAT for AWS services

❌ **Don't:**
- Keep unattached EIPs (charged even when not in use)
- Create more NAT Gateways than needed
- Use EIPs for resources that don't need static IPs

### High Availability

✅ **Do:**
```hcl
# Good: Multi-AZ NAT with separate EIPs
eip_parameters = {
  default = {
    nat_eip_az1 = { domain = "vpc", tags = { AZ = "az1" } }
    nat_eip_az2 = { domain = "vpc", tags = { AZ = "az2" } }
    nat_eip_az3 = { domain = "vpc", tags = { AZ = "az3" } }
  }
}
```

❌ **Don't:**
```hcl
# Bad: Single NAT for entire VPC (single point of failure)
eip_parameters = {
  default = {
    single_nat_eip = { domain = "vpc", tags = {} }
  }
}
```

### Tagging Strategy

✅ **Good:**
```hcl
tags = {
  Name        = "prod-nat-gateway-az1"
  Environment = "prod"
  Purpose     = "NAT Gateway"
  AZ          = "us-east-1a"
  ManagedBy   = "terraform"
  CostCenter  = "networking"
  Team        = "infrastructure"
}
```

❌ **Bad:**
```hcl
tags = {
  Name = "eip"  # Not descriptive enough
}
```

## Common Patterns

### Pattern 1: Single NAT Gateway (Dev/Test)

```hcl
# terraform.tfvars
eip_parameters = {
  default = {
    dev_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "dev"
        Purpose     = "NAT Gateway"
        CostSaving  = "single-nat"
      }
    }
  }
}
```

**Characteristics:**
- 💰 Cost-effective for dev/test
- ⚠️ Single point of failure
- 🔧 Acceptable for non-production

### Pattern 2: Multi-AZ NAT (Production)

```hcl
# terraform.tfvars
eip_parameters = {
  prod = {
    prod_nat_eip_az1 = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        Purpose     = "NAT Gateway"
        AZ          = "us-east-1a"
      }
    }
    
    prod_nat_eip_az2 = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        Purpose     = "NAT Gateway"
        AZ          = "us-east-1b"
      }
    }
    
    prod_nat_eip_az3 = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        Purpose     = "NAT Gateway"
        AZ          = "us-east-1c"
      }
    }
  }
}
```

**Characteristics:**
- ✅ High availability
- ✅ AZ failure tolerance
- 💰 Higher cost (multiple NAT Gateways)

### Pattern 3: Bastion + NAT

```hcl
eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags   = { Purpose = "NAT Gateway" }
    }
    
    bastion_eip = {
      domain = "vpc"
      tags   = { Purpose = "Bastion Host" }
    }
  }
}
```

**Use Case:** Separate public IPs for infrastructure and management access

### Pattern 4: Per-Project EIPs

```hcl
# web-project.tfvars
eip_parameters = {
  default = {
    web_nat_eip = {
      domain = "vpc"
      tags = {
        Project     = "web-application"
        Environment = "dev"
      }
    }
  }
}

# backend-project.tfvars
eip_parameters = {
  default = {
    backend_nat_eip = {
      domain = "vpc"
      tags = {
        Project     = "backend-api"
        Environment = "dev"
      }
    }
  }
}
```

## Validation

### After Creation

```bash
# List all EIPs in your account
aws ec2 describe-addresses

# Check specific EIP
terraform output eips_id

# Verify EIP allocation
aws ec2 describe-addresses --allocation-ids eipalloc-xxxxx

# Check EIP association
aws ec2 describe-addresses --filters "Name=instance-id,Values=i-xxxxx"

# List unattached EIPs (costing money!)
aws ec2 describe-addresses --query 'Addresses[?AssociationId==`null`]'
```

### Testing EIP

```bash
# Get public IP from output
PUBLIC_IP=$(terraform output -json eips | jq -r '.nat_eip.public_ip')

# Verify NAT is using this IP
curl -s ifconfig.me  # From instance behind NAT, should return EIP
```

## Troubleshooting

### Issue: EIP Allocation Limit Reached

**Symptoms:**
```
Error: Error allocating EIP: AddressLimitExceeded
The maximum number of addresses has been reached.
```

**Solution:**
- Default limit: 5 EIPs per region
- Release unused EIPs
- Request quota increase via AWS Service Quotas
- Consolidate infrastructure to use fewer EIPs

```bash
# Check current EIP count
aws ec2 describe-addresses --query 'length(Addresses)'

# Find unused EIPs
aws ec2 describe-addresses --query 'Addresses[?AssociationId==`null`].AllocationId'

# Request limit increase
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --desired-value 10
```

### Issue: EIP Already Associated

**Symptoms:**
```
Error: Error associating EIP: Resource.AlreadyAssociated
```

**Solution:**
- EIP is already attached to another resource
- Disassociate first, then reassociate
- Check for duplicate configurations

```bash
# Check what EIP is associated with
aws ec2 describe-addresses --allocation-ids eipalloc-xxxxx

# Disassociate if needed
aws ec2 disassociate-address --association-id eipassoc-xxxxx
```

### Issue: Cannot Release EIP

**Symptoms:**
```
Error: Error releasing EIP: InvalidAddress.NotFound
```

**Solution:**
- EIP is still associated with a resource
- Destroy NAT Gateway or instance first
- Check `prevent_destroy` lifecycle setting

```bash
# Find what's using the EIP
aws ec2 describe-addresses --allocation-ids eipalloc-xxxxx

# Check NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=nat-gateway-id,Values=nat-xxxxx"
```

### Issue: Wrong Domain Type

**Symptoms:**
```
Error: InvalidParameterValue: Domain vpc not supported for this operation
```

**Solution:**
- Ensure `domain = "vpc"` for VPC EIPs
- EC2-Classic accounts use `domain = "standard"` (deprecated)
- Most modern accounts only support `domain = "vpc"`

### Issue: EIP Not Showing in Outputs

**Symptoms:**
```
terraform output eips
# Returns empty or missing expected EIP
```

**Solution:**
- Check workspace: `terraform workspace show`
- Verify EIP is in correct workspace block in `.tfvars`
- Run `terraform refresh`
- Check module was applied: `terraform state list | grep eip`

```bash
# Verify workspace
terraform workspace show

# Check state
terraform state list | grep aws_eip

# Refresh outputs
terraform refresh
terraform output eips
```

### Issue: Charges for Unused EIP

**Symptoms:**
- AWS bill shows EIP charges
- EIP is not attached to any resource

**Solution:**
- Unassociated EIPs are charged $0.005/hour (~$3.60/month)
- Associate EIP or release it
- Monitor with AWS Cost Explorer

```bash
# Find unattached EIPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].[AllocationId, PublicIp, Tags]' \
  --output table

# Release unused EIP
terraform destroy -target=module.chat_app_eip.aws_eip.example[\"unused_eip\"]
```

## Cost Considerations

### EIP Pricing

| Scenario | Cost | Details |
|----------|------|---------|
| **Attached EIP** | FREE | When associated with running instance/NAT |
| **Unattached EIP** | $0.005/hour | ~$3.60/month per unused EIP |
| **Additional EIPs** | $0.005/hour | For instances with >1 EIP |
| **Remap** | FREE | No charge for reassociating EIPs |

### Cost Optimization Tips

✅ **Do:**
1. Release EIPs immediately after resource deletion
2. Use VPC Endpoints instead of NAT for AWS services
3. Share NAT Gateways across subnets when possible
4. Monitor unused EIPs weekly

❌ **Don't:**
1. Allocate EIPs "just in case"
2. Keep unattached EIPs
3. Create separate NAT Gateways per subnet unnecessarily

### Cost Example: Single vs Multi-AZ NAT

**Single NAT Gateway (Dev):**
```
1 EIP (attached): $0/month
1 NAT Gateway: $32.40/month
Data transfer: $0.045/GB

Monthly cost: ~$32.40 + data transfer
```

**Multi-AZ NAT Gateway (Prod):**
```
3 EIPs (attached): $0/month
3 NAT Gateways: $97.20/month
Data transfer: $0.045/GB

Monthly cost: ~$97.20 + data transfer
```

### Monitoring Costs

```bash
# AWS CLI - Find EIP costs
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://filter.json

# filter.json
{
  "Dimensions": {
    "Key": "USAGE_TYPE",
    "Values": ["ElasticIP:IdleAddress"]
  }
}
```

## Security Considerations

### Public IP Exposure

✅ **Good Practice:**
```hcl
# Use EIP for NAT Gateway (private instances get internet via NAT)
eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags   = { Purpose = "NAT" }
    }
  }
}

# Private instances don't need EIPs
# They use NAT Gateway's EIP for outbound traffic
```

❌ **Bad Practice:**
```hcl
# Don't assign EIPs directly to private instances
# This defeats the purpose of private subnets
```

### IP Whitelisting

When using EIPs for whitelisting:

```hcl
# Document EIP in DNS or config management
eip_parameters = {
  default = {
    api_gateway_eip = {
      domain = "vpc"
      tags = {
        Purpose      = "API Gateway"
        WhitelistIn  = "partner-firewall,customer-vpn"
        DNSRecord    = "api.example.com"
      }
    }
  }
}
```

### Compliance

For PCI-DSS, HIPAA, or other compliance:

```hcl
eip_parameters = {
  prod = {
    compliant_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        Compliance  = "PCI-DSS"
        DataClass   = "cardholder-data-egress"
        Monitored   = "true"
      }
    }
  }
}
```

**Enable VPC Flow Logs for EIP traffic monitoring:**
```bash
aws ec2 create-flow-logs \
  --resource-type NetworkInterface \
  --resource-ids eni-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs
```

## Advanced Configuration

### BYOIP (Bring Your Own IP)

If you have your own IPv4 address range:

```hcl
# Step 1: Provision IP pool (one-time setup via AWS CLI)
aws ec2 provision-byoip-cidr --cidr 203.0.113.0/24

# Step 2: Use in EIP
eip_parameters = {
  prod = {
    byoip_eip = {
      domain           = "vpc"
      public_ipv4_pool = "ipv4pool-ec2-012345abcdef"
      tags = {
        Source      = "BYOIP"
        IPRange     = "203.0.113.0/24"
        Owner       = "organization"
      }
    }
  }
}
```

**Benefits:**
- ✅ Use your organization's IP addresses
- ✅ Maintain IP reputation
- ✅ Easier migration to AWS

**Limitations:**
- ⚠️ Requires Route Origin Authorization (ROA)
- ⚠️ /24 CIDR minimum
- ⚠️ Must be globally routable

### Dynamic EIP Association

Associate EIP after resource creation:

```hcl
# Step 1: Create unattached EIP
resource "aws_eip" "dynamic" {
  domain = "vpc"
}

# Step 2: Associate with instance
resource "aws_eip_association" "dynamic_assoc" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.dynamic.id
}
```

**Note:** This framework typically handles associations via NAT Gateway module.

## Real-World Example: Complete Infrastructure

```hcl
# =============================================================================
# Multi-Environment EIP Configuration
# =============================================================================

eip_parameters = {
  # =================
  # DEVELOPMENT
  # =================
  default = {
    # Single NAT for cost savings
    dev_nat_eip = {
      domain = "vpc"
      tags = {
        Environment = "dev"
        Purpose     = "NAT Gateway"
        CostCenter  = "engineering"
        ManagedBy   = "terraform"
      }
    }
    
    # Bastion host for SSH access
    dev_bastion_eip = {
      domain = "vpc"
      tags = {
        Environment = "dev"
        Purpose     = "Bastion Host"
        CostCenter  = "engineering"
      }
    }
  }
  
  # =================
  # QE/STAGING
  # =================
  qe = {
    # Dual-AZ NAT for testing HA
    qe_nat_eip_az1 = {
      domain = "vpc"
      tags = {
        Environment = "qe"
        Purpose     = "NAT Gateway"
        AZ          = "ap-south-1a"
        CostCenter  = "qa"
      }
    }
    
    qe_nat_eip_az2 = {
      domain = "vpc"
      tags = {
        Environment = "qe"
        Purpose     = "NAT Gateway"
        AZ          = "ap-south-1b"
        CostCenter  = "qa"
      }
    }
    
    # Staging bastion
    qe_bastion_eip = {
      domain = "vpc"
      tags = {
        Environment = "qe"
        Purpose     = "Bastion Host"
      }
    }
  }
  
  # =================
  # PRODUCTION
  # =================
  prod = {
    # Multi-AZ NAT for high availability
    prod_nat_eip_az1 = {
      domain = "vpc"
      tags = {
        Environment  = "prod"
        Purpose      = "NAT Gateway"
        AZ           = "ap-south-1a"
        CostCenter   = "production"
        Compliance   = "required"
        BackupStatus = "monitored"
      }
    }
    
    prod_nat_eip_az2 = {
      domain = "vpc"
      tags = {
        Environment  = "prod"
        Purpose      = "NAT Gateway"
        AZ           = "ap-south-1b"
        CostCenter   = "production"
        Compliance   = "required"
        BackupStatus = "monitored"
      }
    }
    
    prod_nat_eip_az3 = {
      domain = "vpc"
      tags = {
        Environment  = "prod"
        Purpose      = "NAT Gateway"
        AZ           = "ap-south-1c"
        CostCenter   = "production"
        Compliance   = "required"
        BackupStatus = "monitored"
      }
    }
    
    # Production bastion (highly restricted)
    prod_bastion_eip = {
      domain = "vpc"
      tags = {
        Environment    = "prod"
        Purpose        = "Bastion Host"
        AccessControl  = "strict"
        MonitoringTier = "critical"
      }
    }
    
    # VPN endpoint
    prod_vpn_eip = {
      domain = "vpc"
      tags = {
        Environment = "prod"
        Purpose     = "VPN Server"
        DNSRecord   = "vpn.company.com"
      }
    }
  }
}
```

**Architecture:**
```
Development:
  └── 1 NAT Gateway (1 EIP) + 1 Bastion (1 EIP)
      Cost: ~$35/month + data transfer

QE/Staging:
  └── 2 NAT Gateways (2 EIPs) + 1 Bastion (1 EIP)
      Cost: ~$68/month + data transfer

Production:
  └── 3 NAT Gateways (3 EIPs) + 1 Bastion (1 EIP) + 1 VPN (1 EIP)
      Cost: ~$130/month + data transfer
```

## Testing EIP Configuration

### Verify EIP Allocation

```bash
# Apply configuration
terraform apply -target=module.chat_app_eip

# Check outputs
terraform output eips_id

# Verify in AWS
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId, PublicIp, Tags]'
```

### Test NAT Connectivity

```bash
# From instance in private subnet
curl -s ifconfig.me
# Should return NAT Gateway's EIP

# Verify it matches
terraform output -json eips | jq -r '.nat_eip.public_ip'
```

### Test Bastion Access

```bash
# Get bastion public IP
BASTION_IP=$(terraform output -json eips | jq -r '.bastion_eip.public_ip')

# SSH to bastion
ssh -i key.pem ec2-user@$BASTION_IP

# From bastion, access private instances
ssh -i key.pem ec2-user@<private-ip>
```

## Migration Guide

### From Manual EIP to Terraform

```bash
# Step 1: Import existing EIP
terraform import 'module.chat_app_eip.aws_eip.example["existing_eip"]' eipalloc-xxxxx

# Step 2: Add to terraform.tfvars
eip_parameters = {
  default = {
    existing_eip = {
      domain = "vpc"
      tags = {
        Name = "imported-eip"
        MigratedFrom = "manual"
      }
    }
  }
}

# Step 3: Verify plan (should show no changes)
terraform plan

# Step 4: Update tags or configuration as needed
terraform apply
```

### Changing EIP Associations

```bash
# Scenario: Moving EIP from old NAT to new NAT

# Step 1: Destroy old NAT Gateway (releases EIP association)
terraform destroy -target=module.chat_app_nat.aws_nat_gateway.example[\"old_nat\"]

# Step 2: Create new NAT Gateway (reuses same EIP)
terraform apply -target=module.chat_app_nat.aws_nat_gateway.example[\"new_nat\"]

# EIP allocation_id remains the same, just reassociated
```

## Disaster Recovery

### Backup Strategy

```bash
# Document EIP allocation IDs
terraform output -json eips > eip_backup.json

# Export current configuration
terraform show -json > infrastructure_state.json

# Store in version control
git add eip_backup.json
git commit -m "Backup EIP allocation IDs - $(date +%Y-%m-%d)"
```

### Recovery Procedure

If EIPs are accidentally released:

1. **Check if still allocated:**
```bash
aws ec2 describe-addresses --allocation-ids eipalloc-xxxxx
```

2. **If released, allocate new EIP:**
```bash
terraform apply -target=module.chat_app_eip
```

3. **Update dependent resources (NAT Gateways):**
```bash
terraform apply -target=module.chat_app_nat
```

4. **Update DNS/firewall rules with new IPs**

**Note:** You cannot recover the exact same public IP once released.

## Monitoring and Alerting

### CloudWatch Metrics

EIPs don't have direct CloudWatch metrics, but monitor associated resources:

```bash
# NAT Gateway metrics (uses EIP)
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-xxxxx \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-14T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Cost Alerts

```bash
# Create billing alarm for idle EIPs
aws cloudwatch put-metric-alarm \
  --alarm-name idle-eip-alert \
  --alarm-description "Alert on idle EIP charges" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

### Automation Script

```bash
#!/bin/bash
# check-idle-eips.sh - Find and alert on unattached EIPs

IDLE_EIPS=$(aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].AllocationId' \
  --output text)

if [ -n "$IDLE_EIPS" ]; then
  echo "WARNING: Found idle EIPs costing money:"
  for eip in $IDLE_EIPS; do
    aws ec2 describe-addresses --allocation-ids $eip
  done
  
  # Send alert (SNS, Slack, etc.)
  aws sns publish \
    --topic-arn arn:aws:sns:region:account:alerts \
    --message "Idle EIPs detected: $IDLE_EIPS"
fi
```

## FAQ

### Q: What's the difference between EIP domain "vpc" and "standard"?

**A:** 
- `"vpc"` - For VPCs (modern AWS, use this)
- `"standard"` - For EC2-Classic (deprecated, legacy only)

Unless you have a very old AWS account, always use `domain = "vpc"`.

### Q: Do I get charged for attached EIPs?

**A:** No. EIPs are FREE when associated with a running instance or NAT Gateway. You're only charged for:
- Unattached EIPs (~$3.60/month each)
- Additional EIPs on instances with >1 EIP

### Q: Can I move an EIP between instances?

**A:** Yes. EIPs can be reassociated freely:

```bash
# Disassociate from old instance (automatic if using Terraform)
aws ec2 disassociate-address --association-id eipassoc-xxxxx

# Associate with new instance
aws ec2 associate-address --instance-id i-new --allocation-id eipalloc-xxxxx
```

Terraform handles this automatically when you change associations.

### Q: How many EIPs can I have per account?

**A:** Default limit is **5 EIPs per region**. You can request increases via AWS Service Quotas.

```bash
# Check limit
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-0263D0A3

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --desired-value 10
```

### Q: What happens to my EIP if I stop an instance?

**A:** 
- **Associated EIP:** Remains associated, continues to point to instance
- **Cost:** Still FREE (attached to stopped instance)
- **Reboot:** EIP stays attached

**But:** If you TERMINATE the instance, EIP is disassociated (and starts costing money if not released).

### Q: Can I choose a specific IP address?

**A:** No, AWS assigns EIPs from their pool randomly. Use BYOIP if you need specific IPs.

### Q: Should I use EIP for load balancers?

**A:** 
- **Application Load Balancer (ALB):** No, uses dynamic IPs with DNS
- **Network Load Balancer (NLB):** Yes, can use EIPs for static IPs
- **Classic Load Balancer:** No, uses dynamic IPs

### Q: What's the difference between EIP and public IP?

| Feature | Elastic IP (EIP) | Public IP |
|---------|------------------|-----------|
| **Static** | ✅ Yes | ❌ No (changes on stop/start) |
| **Reassignable** | ✅ Yes | ❌ No |
| **Cost when unattached** | 💰 $3.60/month | N/A |
| **Use case** | NAT, bastion, NLB | Basic internet access |

### Q: Can I use the same EIP in multiple regions?

**A:** No. EIPs are region-specific. Each region needs its own EIP allocation.

### Q: How do I whitelist my NAT Gateway's IP?

**A:** 

```bash
# Get NAT Gateway's EIP
terraform output -json eips | jq -r '.nat_eip.public_ip'

# Provide this IP to partner/vendor for whitelisting
# Document in tags:
tags = {
  Purpose       = "NAT Gateway"
  WhitelistedIn = "partner-firewall, vendor-api"
}
```

## Performance Considerations

### Network Performance

- EIPs don't impact network performance
- Performance depends on associated resource:
  - NAT Gateway: Up to 45 Gbps
  - EC2 instance: Based on instance type
  - NLB: Based on traffic pattern

### Remap Speed

- EIP reassociation: ~Few seconds
- DNS propagation: 60-300 seconds (depends on TTL)
- No performance penalty for remapping

### Burst Handling

- EIPs have no burst limits
- Associated resource limits apply (e.g., NAT Gateway bandwidth)

## Compliance and Auditing

### Audit Trail

```bash
# CloudTrail events for EIP operations
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::EC2::EIP \
  --max-results 50

# Who allocated/released EIPs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AllocateAddress

# Who associated/disassociated EIPs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssociateAddress
```

### Compliance Tagging

```hcl
eip_parameters = {
  prod = {
    compliant_eip = {
      domain = "vpc"
      tags = {
        Environment    = "prod"
        Compliance     = "PCI-DSS,HIPAA"
        DataClass      = "public-egress"
        MonitoringTier = "critical"
        Owner          = "security-team"
        ReviewDate     = "2025-Q2"
      }
    }
  }
}
```

### Reporting

```bash
#!/bin/bash
# eip-audit-report.sh - Generate EIP usage report

echo "EIP Audit Report - $(date)"
echo "================================"

# Total EIPs
TOTAL=$(aws ec2 describe-addresses --query 'length(Addresses)')
echo "Total EIPs: $TOTAL"

# Attached vs Unattached
ATTACHED=$(aws ec2 describe-addresses --query 'length(Addresses[?AssociationId!=`null`])')
UNATTACHED=$(aws ec2 describe-addresses --query 'length(Addresses[?AssociationId==`null`])')
echo "Attached: $ATTACHED"
echo "Unattached (costing money): $UNATTACHED"

# Cost estimate
IDLE_COST=$(echo "$UNATTACHED * 3.60" | bc)
echo "Estimated monthly cost of idle EIPs: \$IDLE_COST"

# List all EIPs with details
aws ec2 describe-addresses \
  --query 'Addresses[*].[AllocationId, PublicIp, AssociationId, Tags[?Key==`Name`].Value | [0]]' \
  --output table
```

## Change Log

### Version 1.0 (2025-01-14)
- Initial release
- Support for VPC and standard domain
- BYOIP support
- Instance and network interface associations
- Integration with NAT Gateway module
- Comprehensive tagging and lifecycle management

## Contributing

When contributing to this module:

1. ✅ Add examples to this README
2. ✅ Document any new parameters
3. ✅ Include cost considerations
4. ✅ Test with multiple workspaces
5. ✅ Update troubleshooting section
6. ✅ Validate EIP limits aren't exceeded

## Module Metadata

- **Author** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Networking/Compute
- **Complexity:** Low (Simple resource allocation)
- **Dependencies:** None (foundational resource)

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]
- [FAQ](#FAQ)


---


## Summary

The EIP module provides a simple, workspace-aware way to allocate and manage Elastic IP addresses across multiple environments. Key features:

- ✅ Multi-environment support via Terraform workspaces
- ✅ Integration with NAT Gateway module
- ✅ Comprehensive tagging and lifecycle management
- ✅ Cost-aware design (prevents idle EIP waste)
- ✅ BYOIP support for enterprise IP ranges
- ✅ Detailed outputs for cross-module references

**Most Common Use Case:** NAT Gateway EIP allocation for private subnet internet access

**Remember:** 
- Attached EIPs are FREE
- Unattached EIPs cost ~$3.60/month each
- Always release unused EIPs immediately

## Additional Resources

- **AWS EIP Documentation:** https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html
- **Terraform aws_eip:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
- **BYOIP Guide:** https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-byoip.html
- **NAT Gateway Pricing:** https://aws.amazon.com/vpc/pricing/
- **Service Quotas:** https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html


[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139
