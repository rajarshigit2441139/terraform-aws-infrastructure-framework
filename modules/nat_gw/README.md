# NAT Gateway Module

## Overview

This module creates AWS NAT Gateways. A NAT (Network Address Translation) Gateway enables instances in private subnets to connect to the internet or other AWS services while preventing the internet from initiating connections with those instances. NAT Gateways are highly available, managed services that automatically scale to handle your traffic.

## Module Purpose

- Creates NAT Gateways in public or private subnets
- Enables outbound internet access for private subnets
- Supports both public and private NAT Gateway types
- Manages Elastic IP allocation for public NAT Gateways
- Provides gateway IDs for route table configuration
- Supports secondary IP addresses for high-throughput scenarios

## Module Location

```text
modules//nat/
├── main.tf          # NAT Gateway resources
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **1 type of resource**:

1. **NAT Gateway** - `aws_nat_gateway`

### NAT Gateway Definition

```hcl
resource "aws_nat_gateway" "example" {
  for_each                           = var.nat_gateway_parameters
  connectivity_type                  = each.value.connectivity_type
  secondary_private_ip_address_count = each.value.secondary_private_ip_address_count
  subnet_id                          = each.value.subnet_id
  allocation_id                      = each.value.allocation_id
  secondary_allocation_ids           = each.value.secondary_allocation_ids
  secondary_private_ip_addresses     = each.value.secondary_private_ip_addresses
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

### `nat_gateway_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** `{}`

Map of NAT Gateway configurations.

#### Object Structure

```hcl
{
  subnet_id                          = string                      # REQUIRED (auto-injected)
  connectivity_type                  = optional(string)            # OPTIONAL: "public" (default) or "private"
  secondary_private_ip_address_count = optional(number)            # OPTIONAL: For private NAT with secondary IPs
  allocation_id                      = optional(string)            # REQUIRED for public NAT (auto-injected)
  secondary_allocation_ids           = optional(list(string))      # OPTIONAL: For public NAT with secondary IPs
  secondary_private_ip_addresses     = optional(list(string))      # OPTIONAL: Specific secondary IPs
  tags                               = optional(map(string), {})  # OPTIONAL
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `subnet_id` | string | ✅ Yes* | - | Subnet ID (auto-injected from `subnet_name`) |
| `connectivity_type` | string | ❌ No | `"public"` | NAT type: `"public"` or `"private"` |
| `secondary_private_ip_address_count` | number | ❌ No | - | Number of secondary IPs (private NAT only) |
| `allocation_id` | string | ✅ Yes** | - | Elastic IP allocation ID (public NAT only, auto-injected) |
| `secondary_allocation_ids` | list(string) | ❌ No | - | Secondary EIP allocation IDs (public NAT only) |
| `secondary_private_ip_addresses` | list(string) | ❌ No | - | Specific secondary private IPs |
| `tags` | map(string) | ❌ No | `{}` | Additional tags for the NAT Gateway |

> **Notes**
> - `subnet_id` is **auto-injected** by the parent module from `subnet_name`.
> - `allocation_id` is **auto-injected** by the parent module from `eip_name_for_allocation_id` (for public NAT).
> - `allocation_id` is **required only** for a **public** NAT Gateway (default type).

#### NAT Gateway Types

**Public NAT Gateway (Default):**

- Requires Elastic IP (`allocation_id`)
- Must be in public subnet
- Allows private instances to access the internet
- **Cost:** $0.045/hour + $0.045/GB processed

**Private NAT Gateway:**

- No Elastic IP needed (`connectivity_type = "private"`)
- Routes to other VPCs or on-premises networks
- Cannot access the internet
- **Cost:** $0.045/hour + $0.045/GB processed

## Outputs

### `nat_ids`

**Type:** `map(object)`  
**Description:** Map of NAT Gateway outputs indexed by NAT Gateway name (key)

#### Output Structure

```hcl
{
  "" = {
    id = string  # NAT Gateway ID (nat-xxxxx)
  }
}
```

#### Output Example

```hcl
{
  "nat_gateway_az1" = {
    id = "nat-0abc123def456789"
  }
  "nat_gateway_az2" = {
    id = "nat-0def456abc789012"
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | AWS NAT Gateway ID | `"nat-0abc123def456789"` |

## Usage in Root Module

### Called From

`08_nat.tf` in the root module (create this file if it doesn't exist)

### Module Call

```hcl
module "chat_app_nat" {
  source                 = "./modules/nat"
  nat_gateway_parameters = lookup(local.generated_nat_gateway_parameters, terraform.workspace, {} )
  depends_on             = [module.chat_app_subnet, module.chat_app_eip]
}
```

### Dynamic Parameter Generation

#### NAT Gateway with Subnet ID and EIP Allocation ID Injection

```hcl
# In root module (08_nat.tf)
locals {
  generated_nat_gateway_parameters = {
    for workspace, nats in var.nat_gateway_parameters :
    workspace => {
      for name, nat in nats :
      name => merge(
        nat,
        {
          subnet_id     = local.subnet_id_by_name[nat.subnet_name]
          allocation_id = nat.eip_name_for_allocation_id != null ? local.eip_id_by_name[nat.eip_name_for_allocation_id] : null
        }
      )
    }
  }
}
```

**What this does:**

1. Iterates through all workspaces in `var.nat_gateway_parameters`
2. For each NAT Gateway in each workspace
3. Merges the original configuration with:
   - Resolved Subnet ID from `subnet_name`
   - Resolved EIP Allocation ID from `eip_name_for_allocation_id` (if provided)

### NAT Gateway ID Extraction for Route Tables

```hcl
# In 01_locals.tf
locals {
  extract_nat_gateway_ids = {
    for name, nat in module.chat_app_nat.nat_ids :
    name => nat.id
  }
}

# Used in route table module
module "chat_app_rt" {
  source          = "./modules/rt"
  nat_gateway_ids = local.extract_nat_gateway_ids
  # ...
}
```

## Best Practices

### NAT Gateway Design

✅ **Do:**

- Use one NAT Gateway per AZ for high availability
- Place NAT Gateways in public subnets
- Associate each private subnet with its own AZ’s NAT
- Use descriptive names: `prod_nat_az1`, `dev_nat_az2`
- Tag with Environment, AZ, Purpose
- Monitor bandwidth and connection limits

❌ **Don't:**

- Use single NAT for production (single point of failure)
- Route cross-AZ traffic through NAT (extra costs)
- Forget to allocate an Elastic IP before creating a public NAT

## Validation

### After Creation

```bash
terraform output nat_ids
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx --query 'NatGateways[0].State'
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx --query 'NatGateways[0].NatGatewayAddresses[0].PublicIp'
```

### Test Connectivity

```bash
ping 8.8.8.8
curl ifconfig.me
aws ec2 describe-route-tables --filters "Name=route.nat-gateway-id,Values=nat-xxxxx"
curl -I https://google.com
```

## Module Metadata

- **Author:** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Networking/Gateway
- **Complexity:** Medium (requires EIP + subnet coordination)


## Support
**Questions? Issues? Feedback?**

- Read Documents
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]


## AWS Resource Reference

- **Resource Type:** `aws_nat_gateway`
- **AWS Documentation:** https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
- **Terraform Documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
- **AWS Service Limits:** https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html#vpc-limits-gateways



[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139