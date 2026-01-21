# VPC Endpoint Module

## Overview

This module creates AWS VPC Endpoints. VPC Endpoints enable private connections between your VPC and supported AWS services without requiring an Internet Gateway, NAT device, VPN connection, or AWS Direct Connect. Traffic between your VPC and AWS services does not leave the Amazon network, improving security and reducing data transfer costs.

## Module Purpose

- Creates VPC Gateway Endpoints (S3, DynamoDB)
- Creates VPC Interface Endpoints (EC2, ECR, ECS, SQS, SNS, etc.)
- Enables private connectivity to AWS services
- Eliminates NAT Gateway data processing costs for AWS service traffic
- Provides DNS entries for Interface endpoints
- Manages security groups and subnet associations

## Module Location

```text
modules/vpc_endpoint/
├── main.tf          # VPC Endpoint resources
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **1 type of resource**:

1. **VPC Endpoint** - `aws_vpc_endpoint`

### VPC Endpoint Definition

```hcl
resource "aws_vpc_endpoint" "example" {
  for_each = var.vpc_endpoints

  vpc_id            = each.value.vpc_id
  service_name      = "com.amazonaws.${each.value.region}.${each.value.service_name}"
  vpc_endpoint_type = each.value.vpc_endpoint_type

  # Gateway endpoints use route_table_ids
  route_table_ids = try(each.value.route_table_ids, null)

  # Interface endpoints use these
  subnet_ids          = try(each.value.subnet_ids, null)
  security_group_ids  = try(each.value.security_group_ids, null)
  private_dns_enabled = try(each.value.private_dns_enabled, null)

  tags = merge(each.value.tags, {
    Name = each.key
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}
```

## VPC Endpoint Types

### Gateway Endpoints

- **Services:** S3, DynamoDB
- **How it works:** Routes added automatically to route tables
- **Cost:** **FREE** (no hourly or data processing charges)
- **Use in:** Route tables
- **DNS:** Not applicable
- **Security:** VPC endpoint policies only

### Interface Endpoints

- **Services:** EC2, ECR, ECS, SQS, SNS, CloudWatch, Systems Manager, Secrets Manager, etc.
- **How it works:** ENI created in subnets
- **Cost:** $0.01/hour + $0.01/GB processed
- **Use in:** Subnets with security groups
- **DNS:** Private DNS names
- **Security:** Security groups + VPC endpoint policies

## Inputs

### `vpc_endpoints`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** N/A

#### Object Structure

```hcl
{
  region            = string                      # REQUIRED: AWS region
  vpc_id            = string                      # REQUIRED (auto-injected)
  service_name      = string                      # REQUIRED: Service name (s3, ec2, etc.)
  vpc_endpoint_type = string                      # REQUIRED: "Gateway" or "Interface"

  # Gateway Endpoint Parameters
  route_table_ids   = optional(list(string))      # REQUIRED for Gateway endpoints

  # Interface Endpoint Parameters
  subnet_ids          = optional(list(string))    # REQUIRED for Interface endpoints
  security_group_ids  = optional(list(string))    # REQUIRED for Interface endpoints
  private_dns_enabled = optional(bool)            # OPTIONAL for Interface endpoints

  tags = optional(map(string))                    # OPTIONAL
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `region` | string | ✅ Yes | - | AWS region (e.g., `"ap-south-1"`) |
| `vpc_id` | string | ✅ Yes* | - | VPC ID (auto-injected from `vpc_name`) |
| `service_name` | string | ✅ Yes | - | AWS service name (`s3`, `ec2`, `ecr.api`, etc.) |
| `vpc_endpoint_type` | string | ✅ Yes | - | `"Gateway"` or `"Interface"` |
| `route_table_ids` | list(string) | ✅ Yes** | - | Route table IDs (Gateway endpoints only) |
| `subnet_ids` | list(string) | ✅ Yes*** | - | Subnet IDs (Interface endpoints only) |
| `security_group_ids` | list(string) | ✅ Yes*** | - | Security group IDs (Interface endpoints only) |
| `private_dns_enabled` | bool | ❌ No | `true` | Enable private DNS (Interface endpoints only) |
| `tags` | map(string) | ❌ No | `{}` | Additional tags for the endpoint |

> **Notes**
> - `vpc_id` is **auto-injected** by the parent module from `vpc_name`.
> - `route_table_ids` is **required** for **Gateway** endpoints and ignored for Interface endpoints.
> - `subnet_ids` and `security_group_ids` are **required** for **Interface** endpoints and ignored for Gateway endpoints.

#### Supported Service Names

**Gateway Endpoints (Free):**
- `s3`
- `dynamodb`

**Interface Endpoints (Paid):**

| Category | Services |
|----------|----------|
| Compute | `ec2`, `ec2messages`, `ecs`, `ecs-agent`, `ecs-telemetry` |
| Container Registry | `ecr.api`, `ecr.dkr` |
| Systems Manager | `ssm`, `ssmmessages` |
| Monitoring | `logs`, `monitoring`, `events` |
| Secrets | `secretsmanager`, `kms` |
| Messaging | `sqs`, `sns` |
| Networking | `elasticloadbalancing`, `autoscaling` |
| Storage | `elasticfilesystem`, `fsx` |
| Database | `rds`, `rds-data` |
| EKS | `eks`, `eks-auth` |
| Lambda | `lambda` |
| API Gateway | `execute-api` |
| STS | `sts` |

## Outputs

### `vpc_endpoint_ids`

**Type:** `map(string)`  
**Description:** Map of VPC endpoint IDs

```hcl
{
  "s3_endpoint"   = "vpce-0abc123def456789"
  "ec2_endpoint"  = "vpce-0def456abc789012"
}
```

### `vpc_endpoint_arns`

**Type:** `map(string)`  
**Description:** Map of VPC endpoint ARNs

```hcl
{
  "s3_endpoint"   = "arn:aws:ec2:ap-south-1:123456789012:vpc-endpoint/vpce-0abc123"
  "ec2_endpoint"  = "arn:aws:ec2:ap-south-1:123456789012:vpc-endpoint/vpce-0def456"
}
```

### `vpc_endpoint_dns_entries`

**Type:** `map(list)`  
**Description:** DNS entries for Interface endpoints (empty for Gateway endpoints)

```hcl
{
  "ec2_endpoint" = [
    {
      dns_name       = "vpce-0abc123-xyz.ec2.ap-south-1.vpce.amazonaws.com"
      hosted_zone_id = "Z123456ABCDEFG"
    }
  ]
  "s3_endpoint" = []
}
```

### `vpc_endpoint_network_interface_ids`

**Type:** `map(list(string))`  
**Description:** Network interface IDs for Interface endpoints (empty for Gateway endpoints)

```hcl
{
  "ec2_endpoint" = ["eni-0abc123", "eni-0def456"]
  "s3_endpoint"  = []
}
```

### `vpc_endpoint_type`

**Type:** `map(string)`  
**Description:** Type of each VPC endpoint

```hcl
{
  "s3_endpoint"   = "Gateway"
  "ec2_endpoint"  = "Interface"
}
```

## Usage in Root Module

### Called From

`06_vpc_endpoint.tf` in the root module

### Module Call

```hcl
module "chat_app_vpc_endpoint" {
  source        = "./modules/vpc_endpoint"
  vpc_endpoints = lookup(local.generated_vpc_endpoint_parameters, terraform.workspace, {})
  depends_on    = [
    module.chat_app_vpc,
    module.chat_app_subnet,
    module.chat_app_security_group,
    module.chat_app_rt
  ]
}
```

### Dynamic Parameter Generation

```hcl
locals {
  generated_vpc_endpoint_parameters = {
    for workspace, endpoints in var.vpc_endpoint_parameters :
    workspace => {
      for name, ep in endpoints :
      name => merge(
        ep,
        {
          vpc_id = local.vpc_id_by_name[ep.vpc_name]

          subnet_ids = (
            ep.vpc_endpoint_type == "Interface" ?
            [for sn in coalesce(ep.subnet_names, []) :
              lookup(local.subnet_id_by_name, sn)
            ] :
            null
          )

          security_group_ids = (
            ep.vpc_endpoint_type == "Interface" ?
            [for sg in coalesce(ep.security_group_names, []) :
              lookup(local.sgs_id_by_name, sg)
            ] :
            null
          )

          route_table_ids = (
            ep.vpc_endpoint_type == "Gateway" ?
            [for rt in coalesce(ep.route_table_names, []) :
              lookup(local.rt_id_by_name, rt)
            ] :
            null
          )
        }
      )
    }
  }
}
```

## Best Practices

✅ **Do:**

- Always use **Gateway endpoints** for S3 and DynamoDB (they’re **free**)
- Enable private DNS for Interface endpoints
- Deploy Interface endpoints in multiple AZs for high availability
- Restrict Interface endpoint security groups to port 443 and known sources
- Tag endpoints with Environment, Purpose, Service
- Validate cost/ROI for Interface endpoints

❌ **Don't:**

- Create Interface endpoints for low-volume traffic without an ROI reason
- Allow `0.0.0.0/0` inbound to endpoint SGs
- Forget to associate Gateway endpoints with the correct route tables

## Cost Analysis

### Gateway Endpoints

| Service | Hourly Cost | Data Processing | Monthly Cost |
|---------|-------------|-----------------|--------------|
| S3 | **$0.00** | **$0.00/GB** | **FREE** |
| DynamoDB | **$0.00** | **$0.00/GB** | **FREE** |

### Interface Endpoints

| Component | Cost | Calculation (per endpoint) |
|-----------|------|----------------------------|
| Hourly charge | $0.01/hour | $0.01 × 24 × 30 = **$7.30/month** |
| Data processing | $0.01/GB | Variable based on traffic |

**Break-even (rough):**

```text
$7.30 + ($0.01 × GB) = $0.045 × GB
GB ≈ 210 GB/month
```

## Validation

```bash
terraform output vpc_endpoint_ids
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxx
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx --query 'RouteTables[0].Routes'
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxx --query 'VpcEndpoints[0].DnsEntries'
```


## Module Metadata

- **Author** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Networking/VPC-Endopints
- **Complexity:** Medium (service types + cost considerations)


## Support
**Questions? Issues? Feedback?**
- Read Documents
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]




## AWS Resource Reference

- **Resource Type:** `aws_vpc_endpoint`
- **AWS Documentation:** https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html
- **Terraform Documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
- **AWS Service Limits:** https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-limits-endpoints.html
- **Pricing:** https://aws.amazon.com/privatelink/pricing/


[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139

