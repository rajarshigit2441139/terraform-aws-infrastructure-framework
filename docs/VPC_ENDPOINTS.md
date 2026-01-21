# VPC Endpoints (Gateway & Interface)

## Table of Contents
- [Overview](#overview)
- [Understanding VPC Endpoints](#understanding-vpc-endpoints)
- [Gateway vs Interface Endpoints](#gateway-vs-interface-endpoints)
- [Quick Start](#quick-start)
- [Configuration Guide](#configuration-guide)
- [Common Patterns](#common-patterns)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)
- [Quick Reference](#quick-reference)
- [Summary](#summary)

---

## Overview

VPC Endpoints enable private connectivity between your VPC and AWS services without requiring internet access. Traffic stays within the Amazon network, improving security and potentially reducing costs.

### What You'll Learn
- When to use Gateway vs Interface endpoints
- How to configure endpoints for different AWS services
- Cost optimization strategies
- Security best practices
- Common architectural patterns

### Key Benefits
- ✅ **Enhanced Security:** Traffic never leaves AWS network  
- ✅ **No Internet Gateway Required:** Private connectivity  
- ✅ **Reduced Costs:** Avoid NAT Gateway charges (for some services)  
- ✅ **Better Performance:** Direct connection to AWS services  
- ✅ **Simplified Network Architecture:** No complex routing needed  

### When to Use VPC Endpoints

**Use VPC Endpoints When:**
- ✅ Resources in private subnets need AWS service access
- ✅ You want to avoid NAT Gateway costs
- ✅ Security requires traffic stay within AWS network
- ✅ You need predictable network paths
- ✅ Compliance mandates private connectivity

**You May Not Need Endpoints When:**
- ❌ Resources already have internet access and cost isn't a concern
- ❌ Service doesn't support VPC endpoints
- ❌ Traffic volume is very low (Interface endpoints cost **$7.30/month** base)

---

## Understanding VPC Endpoints

### How It Works

**Without VPC Endpoint:**
```
Private Subnet Instance
    │
    ├─► NAT Gateway ($0.045/hour + $0.045/GB)
    │
    ├─► Internet Gateway
    │
    └─► AWS Service (S3, DynamoDB, etc.)
        Public endpoint over internet
```

**With VPC Endpoint:**
```
Private Subnet Instance
    │
    └─► VPC Endpoint (stays in AWS network)
        │
        └─► AWS Service
            Direct private connection
```

### The Two Types

| Feature | Gateway Endpoint | Interface Endpoint |
|---|---|---|
| Services | S3, DynamoDB only | 100+ services (EC2, ECR, ECS, etc.) |
| Implementation | Route table entry | ENI in subnet |
| Cost | **FREE** | $0.01/hour + $0.01/GB |
| DNS | No private DNS | Private DNS available |
| Security | Policy-based | Security groups + policies |
| Availability | Regional | Per AZ (deploy in multiple) |
| Use Case | Always use for S3/DynamoDB | Use when ROI justifies cost |

---

## Gateway vs Interface Endpoints

## Gateway Endpoints

### How They Work
- Add routes to your route tables automatically
- No ENI created
- No hourly charges, no data processing fees
- Regional (high availability built-in)

### Architecture
```
┌─────────────────────────────────────────┐
│              VPC (10.0.0.0/16)          │
│                                         │
│  ┌──────────┐         ┌──────────┐     │
│  │ Subnet A │         │ Subnet B │     │
│  │ Instance │         │ Instance │     │
│  └────┬─────┘         └────┬─────┘     │
│       │                    │            │
│       └────────┬───────────┘            │
│                │                        │
│         ┌──────▼────────┐               │
│         │  Route Table  │               │
│         │               │               │
│         │ pl-xxxxx/32   │◄──────────┐   │
│         │ (S3 prefix)   │           │   │
│         │    ▼          │           │   │
│         │ vpce-xxxxx    │           │   │
│         └───────────────┘           │   │
│                                     │   │
│         ┌───────────────────────┐   │   │
│         │ S3 Gateway Endpoint   │───┘   │
│         │ (FREE)                │       │
│         └───────────────────────┘       │
└─────────────────────────────────────────┘
                  │
                  ▼
            AWS S3 Service
         (Private connection)
```

### When to Use
- ✅ Always for S3 and DynamoDB
- ✅ No cost, no complexity
- ✅ Default choice for these services

### Configuration
```hcl
vpc_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region            = "ap-south-1"
      vpc_name          = "my_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt", "public_rt"]
    }
  }
}
```

---

## Interface Endpoints

### How They Work
- Create Elastic Network Interface (ENI) in your subnets
- Provide private IP addresses
- Enable private DNS (optional)
- Require security groups
- Charged per hour + data processing

### Architecture
```
┌─────────────────────────────────────────────────────┐
│                 VPC (10.0.0.0/16)                   │
│                                                     │
│  AZ-A                            AZ-B               │
│  ┌──────────────┐               ┌──────────────┐   │
│  │ Subnet       │               │ Subnet       │   │
│  │ 10.0.1.0/24  │               │ 10.0.2.0/24  │   │
│  │              │               │              │   │
│  │ ┌──────────┐ │               │ ┌──────────┐ │   │
│  │ │ Instance │ │               │ │ Instance │ │   │
│  │ └────┬─────┘ │               │ └────┬─────┘ │   │
│  │      │       │               │      │       │   │
│  │      ▼       │               │      ▼       │   │
│  │ ┌────────┐   │               │ ┌────────┐   │   │
│  │ │  ENI   │   │               │ │  ENI   │   │   │
│  │ │10.0.1.5│   │               │ │10.0.2.5│   │   │
│  │ │        │   │               │ │        │   │   │
│  │ │Endpoint│   │               │ │Endpoint│   │   │
│  │ │   SG   │   │               │ │   SG   │   │   │
│  │ └────────┘   │               │ └────────┘   │   │
│  └──────────────┘               └──────────────┘   │
│         │                              │            │
└─────────┼──────────────────────────────┼────────────┘
          │                              │
          └──────────┬───────────────────┘
                     │
                     ▼
              AWS ECR Service
           (Private connection)
```

### When to Use
- ✅ For services other than S3/DynamoDB
- ✅ When cost is justified by volume or compliance
- ✅ When you need private DNS
- ✅ For EKS clusters (ECR, EC2, etc.)

### Configuration
```hcl
vpc_endpoint_parameters = {
  default = {
    ecr_api_endpoint = {
      region               = "ap-south-1"
      vpc_name             = "my_vpc"
      service_name         = "ecr.api"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["private_subnet_a", "private_subnet_b"]
      security_group_names = ["endpoint_sg"]
      private_dns_enabled  = true
    }
  }
}
```

---

## Quick Start

## Example 1: Basic S3 Gateway Endpoint

### Step 1: Define the endpoint
```hcl
# terraform.tfvars
vpc_endpoint_parameters = {
  default = {
    s3_endpoint = {
      region            = "us-east-1"
      vpc_name          = "my_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt"]
      tags = {
        Purpose = "S3-private-access"
      }
    }
  }
}
```

### Step 2: Deploy
```bash
terraform plan
terraform apply
```

### Step 3: Verify
```bash
# From EC2 instance in private subnet
aws s3 ls

# Check route table
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx
```

**Result**
- ✅ S3 access from private subnet
- ✅ No NAT Gateway needed
- ✅ No additional costs
- ✅ Traffic stays in AWS network

---

## Example 2: ECR Interface Endpoints for EKS

### Step 1: Create endpoint security group
```hcl
# terraform.tfvars
security_group_parameters = {
  default = {
    endpoint_sg = {
      name     = "vpc-endpoint-sg"
      vpc_name = "eks_vpc"
      tags     = { Purpose = "vpc-endpoints" }
    }
  }
}

ipv4_ingress_rule = {
  default = {
    endpoint_https = {
      vpc_name  = "eks_vpc"
      sg_name   = "endpoint_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      # Allow from VPC CIDR (auto-resolved)
    }
  }
}

ipv4_egress_rule = {
  default = {
    endpoint_egress = {
      vpc_name  = "eks_vpc"
      sg_name   = "endpoint_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

### Step 2: Create ECR endpoints
```hcl
vpc_endpoint_parameters = {
  default = {
    # ECR API endpoint
    ecr_api = {
      region               = "us-east-1"
      vpc_name             = "eks_vpc"
      service_name         = "ecr.api"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["private_a", "private_b"]
      security_group_names = ["endpoint_sg"]
      private_dns_enabled  = true
    }

    # ECR Docker endpoint
    ecr_dkr = {
      region               = "us-east-1"
      vpc_name             = "eks_vpc"
      service_name         = "ecr.dkr"
      vpc_endpoint_type    = "Interface"
      subnet_names         = ["private_a", "private_b"]
      security_group_names = ["endpoint_sg"]
      private_dns_enabled  = true
    }

    # S3 endpoint (for ECR layers)
    s3 = {
      region            = "us-east-1"
      vpc_name          = "eks_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt"]
    }
  }
}
```

### Step 3: Deploy
```bash
terraform apply
```

**Result**
- ✅ EKS nodes can pull images from ECR privately
- ✅ No NAT Gateway needed for image pulls
- ✅ Enhanced security (traffic doesn't leave AWS)
- ✅ Cost: ~$22/month (3 Interface endpoints × $7.30 base)

---

## Configuration Guide

## Gateway Endpoint Configuration
```hcl
vpc_endpoint_parameters = {
  <workspace> = {
    <endpoint_key> = {
      region            = string              # REQUIRED
      vpc_name          = string              # REQUIRED
      service_name      = string              # REQUIRED: "s3" or "dynamodb"
      vpc_endpoint_type = "Gateway"           # REQUIRED
      route_table_names = list(string)        # REQUIRED
      tags              = map(string)         # OPTIONAL
    }
  }
}
```

### Parameters

| Parameter | Required | Type | Description | Example |
|---|---:|---|---|---|
| `region` | ✅ | string | AWS region | `"us-east-1"` |
| `vpc_name` | ✅ | string | VPC key reference | `"my_vpc"` |
| `service_name` | ✅ | string | `"s3"` or `"dynamodb"` | `"s3"` |
| `vpc_endpoint_type` | ✅ | string | Must be `"Gateway"` | `"Gateway"` |
| `route_table_names` | ✅ | list(string) | Route table keys to associate | `["private_rt"]` |
| `tags` | ❌ | map(string) | Additional tags | `{ Environment = "prod" }` |

### Example
```hcl
vpc_endpoint_parameters = {
  default = {
    s3_gateway = {
      region            = "ap-south-1"
      vpc_name          = "prod_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt_a", "private_rt_b", "public_rt"]
      tags = {
        Environment = "production"
        Purpose     = "s3-private-access"
        CostCenter  = "infrastructure"
      }
    }

    dynamodb_gateway = {
      region            = "ap-south-1"
      vpc_name          = "prod_vpc"
      service_name      = "dynamodb"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["private_rt_a", "private_rt_b"]
      tags = {
        Environment = "production"
        Purpose     = "dynamodb-private-access"
      }
    }
  }
}
```

---

## Interface Endpoint Configuration
```hcl
vpc_endpoint_parameters = {
  <workspace> = {
    <endpoint_key> = {
      region               = string              # REQUIRED
      vpc_name             = string              # REQUIRED
      service_name         = string              # REQUIRED
      vpc_endpoint_type    = "Interface"         # REQUIRED
      subnet_names         = list(string)        # REQUIRED
      security_group_names = list(string)        # REQUIRED
      private_dns_enabled  = bool                # OPTIONAL (default true)
      tags                 = map(string)         # OPTIONAL
    }
  }
}
```

---

## Supported Services

### Gateway Endpoints (FREE)

| Service | Service Name | Monthly Cost |
|---|---|---:|
| Amazon S3 | `s3` | $0.00 |
| Amazon DynamoDB | `dynamodb` | $0.00 |

### Common Interface Endpoints (Paid)

**Cost:** $0.01/hour (**$7.30/month**) + $0.01/GB processed per endpoint

---

## Cost Optimization

### NAT vs Interface Endpoint (Quick Math)
- Interface base: **$7.30/month** + **$0.01/GB**
- NAT base: **$32.40/month** + **$0.045/GB**

> Break-even depends on whether you can remove NAT hourly cost or you keep NAT for other needs.

---

## Troubleshooting

### Gateway Endpoint Checklist
- Endpoint state is `available`
- Prefix-list route exists in the right route tables
- Those route tables are associated with the subnets running workloads

### Interface Endpoint Checklist
- Endpoint state is `available`
- Endpoint security group allows **443** from workload CIDR/SG
- Deployed in correct subnets (multi-AZ for prod)
- Private DNS enabled
- VPC DNS hostnames/support enabled

---

## Advanced Topics

### Private DNS Explained
With `private_dns_enabled = true`, standard AWS hostnames resolve to the endpoint’s private IPs—no code changes required.

### Endpoint Policies
You can restrict access with endpoint policies (commonly used with S3). If your module doesn’t support policies yet, add:
```hcl
policy = try(each.value.policy, null)
```

---

## Quick Reference

### Service Name Quick Reference
```hcl
# Gateway (FREE)
service_name = "s3"
service_name = "dynamodb"

# Interface (common)
service_name = "ec2"
service_name = "ecr.api"
service_name = "ecr.dkr"
service_name = "logs"
service_name = "ssm"
service_name = "secretsmanager"
service_name = "kms"
service_name = "sts"
service_name = "sqs"
service_name = "sns"
```

---

## Summary

### Key Takeaways
- ✅ Always use **Gateway endpoints** for **S3** and **DynamoDB** (FREE)
- ✅ **Interface endpoints** cost **$7.30/month base** + **$0.01/GB**
- ✅ Deploy interface endpoints across multiple AZs for production
- ✅ Enable private DNS for seamless AWS SDK usage
- ✅ Use a dedicated endpoint security group

