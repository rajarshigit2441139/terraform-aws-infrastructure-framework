# Cost Optimization Guide

> **Goal:** Minimize AWS infrastructure costs while maintaining performance, security, and reliability.

## Table of Contents

- [Overview](#overview)
- [Cost Breakdown by Service](#cost-breakdown-by-service)
- [Quick Wins (Immediate Savings)](#quick-wins-immediate-savings)
- [Environment-Specific Strategies](#environment-specific-strategies)
- [Detailed Optimization by Component](#detailed-optimization-by-component)
- [Cost Monitoring & Alerts](#cost-monitoring--alerts)
- [Architecture Patterns for Cost Efficiency](#architecture-patterns-for-cost-efficiency)
- [Real-World Examples](#real-world-examples)
- [Cost Estimation Tool](#cost-estimation-tool)

---

## Overview

### Typical Monthly Infrastructure Costs

| Environment | Low Traffic | Medium Traffic | High Traffic |
|-------------|-------------|----------------|--------------|
| **Development** | $50-150 | $150-300 | $300-500 |
| **QE/Staging** | $100-250 | $250-500 | $500-800 |
| **Production** | $500-1,500 | $1,500-5,000 | $5,000-20,000+ |

### Cost Distribution (Typical)

```text
📊 Production Infrastructure Breakdown:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EC2/EKS Nodes         45%  ████████████████████████████
NAT Gateway           20%  ████████████████
EKS Control Plane     15%  ████████████
Data Transfer         10%  ██████████
EBS Volumes            5%  █████
Interface Endpoints    3%  ███
Other                  2%  ██
```

---

## Cost Breakdown by Service

### 1. Elastic IP (EIP) 💰 **FREE** when attached

| Scenario | Cost | Annual |
|----------|------|--------|
| ✅ Attached to NAT/EC2 | **$0.00/hour** | **$0** |
| ❌ Unattached EIP | $0.005/hour | **~$43.80** |
| ❌ Additional EIP on instance | $0.005/hour | **~$43.80** |

**💡 Optimization:**
```hcl
# ✅ Good: Release unused EIPs immediately
terraform destroy -target=module.chat_app_eip.aws_eip.example[\"unused_eip\"]

# ❌ Bad: Keeping 5 unattached EIPs
# Cost: 5 × $43.80/year = $219/year wasted
```

---

### 2. NAT Gateway 💰 **$32-97/month** (most expensive networking component)

| Configuration | NAT Gateways | Hourly | Monthly | Annual |
|---------------|--------------|--------|---------|--------|
| Single NAT (Dev) | 1 | $0.045 | **$32.40** | **$388.80** |
| Multi-AZ (2 AZ) | 2 | $0.090 | **$64.80** | **$777.60** |
| Multi-AZ (3 AZ) | 3 | $0.135 | **$97.20** | **$1,166.40** |

**Plus data processing:** $0.045/GB

**💡 Optimization Strategies:**

#### Strategy 1: Single NAT for Non-Production
```hcl
# ❌ Before: Multi-AZ NAT in dev ($64.80/month)
nat_gateway_parameters = {
  default = {
    dev_nat_az1 = { subnet_name = "dev_pub_az1", ... }
    dev_nat_az2 = { subnet_name = "dev_pub_az2", ... }
  }
}

# ✅ After: Single NAT in dev ($32.40/month)
nat_gateway_parameters = {
  default = {
    dev_nat = { subnet_name = "dev_pub_az1", ... }
  }
}

# 💰 Savings: $32.40/month = $388.80/year
```

#### Strategy 2: VPC Endpoints Instead of NAT
```hcl
# ❌ Before: S3 traffic through NAT Gateway
# Cost: $0.045/GB (NAT) + $0.09/GB (egress) = $0.135/GB

# ✅ After: S3 Gateway Endpoint (FREE)
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      vpc_name            = "dev_vpc"
      service_name        = "s3"
      vpc_endpoint_type   = "Gateway"
      route_table_names   = ["private_rt"]
      tags                = { Purpose = "cost-optimization" }
    }
  }
}

# 💰 Savings: For 100GB/month S3 traffic
# Before: $13.50/month | After: $0/month
# Annual savings: $162
```

#### Strategy 3: NAT Instance for Very Low Traffic
```hcl
# For <100GB/month traffic, consider NAT Instance
# t4g.nano NAT Instance: ~$3.50/month
# vs NAT Gateway: $32.40/month
# Savings: $28.90/month = $346.80/year

# ⚠️ Trade-offs:
# - Need to manage updates/patches
# - Lower bandwidth (vs NAT Gateway's 45 Gbps)
# - Single point of failure
# - Suitable for: Dev/test, very low traffic
```

---

### 3. Internet Gateway (IGW) 💰 **FREE**

| Component | Cost |
|-----------|------|
| Internet Gateway | **$0.00/hour** |
| Data processing | **$0.00/GB** |
| **Data transfer OUT** | **$0.09/GB** |
| Data transfer IN | $0.00/GB |

**💡 Optimization:**
- IGW itself is free, focus on reducing data transfer
- Use CloudFront for static content (cheaper egress)
- Compress responses before sending

---

### 4. Route Tables 💰 **FREE**

- No charges for route tables or associations
- No charges for number of routes

---

### 5. Security Groups 💰 **FREE**

- Security groups: Free
- Security group rules: Free
- VPC Flow Logs (if enabled): **$0.50/GB ingested**

**💡 Optimization:**
```bash
# Only enable Flow Logs for compliance/debugging
# Not needed for all environments

# ✅ Good: Selective Flow Logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-prod \
  --traffic-type REJECT  # Only rejected traffic
```

---

### 6. VPC Endpoints

#### Gateway Endpoints 💰 **FREE**
| Service | Cost | Data Processing |
|---------|------|-----------------|
| S3 | **$0.00/hour** | **$0.00/GB** |
| DynamoDB | **$0.00/hour** | **$0.00/GB** |

#### Interface Endpoints 💰 **$7.30/month each**
| Component | Cost |
|-----------|------|
| Hourly charge | $0.01/hour × 24 × 30 = **$7.30/month** |
| Data processing | $0.01/GB |

**💡 Break-Even Analysis:**

For Interface Endpoints to be cost-effective vs NAT Gateway:

```text
Interface Endpoint Cost = NAT Gateway Cost
$7.30 + ($0.01 × GB) = $0.045 × GB

Solving for GB:
$7.30 = $0.035 × GB
GB ≈ 208 GB/month

✅ Use Interface Endpoint if: Traffic > 208 GB/month
❌ Use NAT Gateway if: Traffic < 208 GB/month
```

**Common Interface Endpoints (by priority):**

| Priority | Service | Use Case | ROI Threshold |
|----------|---------|----------|---------------|
| ⭐⭐⭐ | ECR (API + DKR) | Pulling container images | >50 GB/month |
| ⭐⭐⭐ | EC2 | High API call volume | >100 GB/month |
| ⭐⭐ | SSM | Systems Manager access | >50 GB/month |
| ⭐⭐ | Logs | CloudWatch logging | >100 GB/month |
| ⭐ | SQS/SNS | Message queues | >200 GB/month |

**Example Configuration:**
```hcl
# ✅ High-ROI: ECR endpoints for EKS (saves NAT costs)
vpc_gateway_endpoint_parameters = {
  prod = {
    ecr_api_endpoint = {
      region              = "ap-south-1"
      vpc_name            = "prod_vpc"
      service_name        = "ecr.api"
      vpc_endpoint_type   = "Interface"
      subnet_names        = ["prod_pri_sub1", "prod_pri_sub2"]
      security_group_names = ["vpc_endpoint_sg"]
      private_dns_enabled = true
    }
    
    ecr_dkr_endpoint = {
      region              = "ap-south-1"
      vpc_name            = "prod_vpc"
      service_name        = "ecr.dkr"
      vpc_endpoint_type   = "Interface"
      subnet_names        = ["prod_pri_sub1", "prod_pri_sub2"]
      security_group_names = ["vpc_endpoint_sg"]
      private_dns_enabled = true
    }
  }
}

# 💰 Savings for 500GB/month ECR traffic:
# Before (NAT): 500 × $0.045 = $22.50/month
# After (Interface): 2 × $7.30 + (500 × $0.01) = $19.60/month
# Savings: $2.90/month = $34.80/year
```

---

### 7. EKS Control Plane 💰 **$73/month per cluster**

| Component | Cost | Monthly | Annual |
|-----------|------|---------|--------|
| EKS Cluster | $0.10/hour | **$73.00** | **$876** |

**💡 Optimization:**

#### Strategy 1: Cluster Consolidation
```hcl
# ❌ Before: 5 clusters ($365/month)
# - dev_frontend
# - dev_backend
# - dev_data
# - dev_testing
# - dev_sandbox

# ✅ After: 1 cluster with namespaces ($73/month)
# Use Kubernetes namespaces for isolation
kubectl create namespace frontend
kubectl create namespace backend
kubectl create namespace data

# 💰 Savings: $292/month = $3,504/year
```

#### Strategy 2: Environment-Based Clustering
```text
✅ Recommended Cluster Strategy:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dev:  1 cluster  ($73/month)
QE:   1 cluster  ($73/month)
Prod: 2-3 clusters ($146-219/month)

Total: $292-365/month

❌ Anti-pattern: Cluster per app/team
10 clusters × $73 = $730/month
```

---

### 8. EKS Node Groups (EC2 Instances)

#### Instance Pricing (On-Demand, us-east-1)

| Instance Type | vCPU | RAM | Arch | Hourly | Monthly | Annual |
|---------------|------|-----|------|--------|---------|--------|
| **t3.micro** | 2 | 1GB | x86 | $0.0104 | $7.49 | $89.86 |
| **t3.small** | 2 | 2GB | x86 | $0.0208 | $15.18 | $182.21 |
| **t3.medium** | 2 | 4GB | x86 | $0.0416 | $30.37 | $364.42 |
| **t3.large** | 2 | 8GB | x86 | $0.0832 | $60.74 | $728.83 |
| **t4g.micro** | 2 | 1GB | ARM | $0.0084 | $6.13 | $73.58 |
| **t4g.small** | 2 | 2GB | ARM | $0.0168 | $12.26 | $147.17 |
| **t4g.medium** | 2 | 4GB | ARM | $0.0336 | $24.53 | $294.34 |
| **t4g.large** | 2 | 8GB | ARM | $0.0672 | $49.06 | $588.67 |
| **m5.large** | 2 | 8GB | x86 | $0.096 | $70.08 | $840.96 |
| **c5.large** | 2 | 4GB | x86 | $0.085 | $62.05 | $744.60 |

**💡 Optimization:**

#### Strategy 1: Use ARM (Graviton) Instances
```hcl
# ❌ Before: t3.medium × 5 nodes
# Cost: $30.37 × 5 = $151.85/month

# ✅ After: t4g.medium × 5 nodes (ARM)
eks_nodegroups = {
  default = {
    a = {
      a1 = {
        arch           = "arm64"        # ⭐ ARM for 20% savings
        instance_types = "t4g.medium"
        min_size       = 2
        max_size       = 5
        desired_size   = 5
      }
    }
  }
}

# Cost: $24.53 × 5 = $122.65/month
# 💰 Savings: $29.20/month = $350.40/year (19% reduction)
```

#### Strategy 2: Right-Size Instances
```hcl
# ❌ Before: m5.xlarge (4 vCPU, 16GB) × 3 = $420/month
# Actual usage: 30% CPU, 40% memory

# ✅ After: t4g.large (2 vCPU, 8GB) × 3 = $147/month
# 💰 Savings: $273/month = $3,276/year
```

#### Strategy 3: Use Cluster Autoscaler
```hcl
# Scale nodes based on demand
eks_nodegroups = {
  default = {
    a = {
      a1 = {
        min_size     = 1    # Minimum for HA
        max_size     = 10   # Burst capacity
        desired_size = 2    # Normal baseline
        arch         = "arm64"
        instance_types = "t4g.medium"
      }
    }
  }
}

# With autoscaler:
# Peak hours: 8 nodes = $196/month
# Off hours: 2 nodes = $49/month
# Average: ~4 nodes = $98/month
# 💰 vs fixed 8 nodes: $196/month
# Savings: $98/month = $1,176/year
```

#### Strategy 4: Spot Instances for Non-Critical Workloads
```text
💰 Spot Instance Savings: Up to 90%

Example: t4g.medium spot price
On-Demand: $24.53/month
Spot: ~$7.36/month (70% discount)

⚠️ Trade-offs:
- Can be terminated with 2-min warning
- Not suitable for stateful/critical apps
- Good for: Batch jobs, CI/CD, dev/test
```

---

### 9. Data Transfer Costs

| Type | Cost | Direction |
|------|------|-----------|
| **Internet egress** | $0.09/GB | VPC → Internet |
| Internet ingress | $0.00/GB | Internet → VPC |
| Cross-AZ | $0.01/GB | AZ1 ↔ AZ2 |
| Same-AZ | $0.00/GB | Within AZ |
| VPC Peering (same region) | $0.01/GB | VPC1 ↔ VPC2 |

**💡 Optimization:**

#### Strategy 1: Minimize Cross-AZ Traffic
```hcl
# ✅ Good: Each AZ uses its own NAT
nat_gateway_parameters = {
  prod = {
    nat_az1 = { subnet_name = "prod_pub_az1", ... }
    nat_az2 = { subnet_name = "prod_pub_az2", ... }
  }
}

rt_parameters = {
  prod = {
    private_rt_az1 = {
      routes = [{ target_key = "nat_az1" }]  # AZ1 traffic → AZ1 NAT
    }
    private_rt_az2 = {
      routes = [{ target_key = "nat_az2" }]  # AZ2 traffic → AZ2 NAT
    }
  }
}

# ❌ Bad: All AZs share one NAT
# AZ2 traffic → AZ1 NAT = cross-AZ charges
```

#### Strategy 2: Use CloudFront for Static Content
```text
CloudFront Pricing:
- First 10TB/month: $0.085/GB
- 10-50TB/month: $0.080/GB
- Direct S3 egress: $0.09/GB

💰 Savings: 5-10% + caching benefits
```

#### Strategy 3: Compress Data
```bash
# Enable gzip compression in ALB/NGINX
# Typical compression: 70% reduction

# Example: 1TB/month uncompressed
Before: 1000 GB × $0.09 = $90/month
After: 300 GB × $0.09 = $27/month
Savings: $63/month = $756/year
```

---

## Quick Wins (Immediate Savings)

### 1. Release Unused Elastic IPs
```bash
# Find unattached EIPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].[AllocationId,PublicIp]' \
  --output table

# Release them
aws ec2 release-address --allocation-id eipalloc-xxxxx

# Or via Terraform
terraform destroy -target=module.chat_app_eip.aws_eip.example[\"unused_eip\"]

# 💰 Potential savings: $3.60/month per EIP
```

### 2. Enable S3 Gateway Endpoint (Free)
```hcl
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      vpc_name            = "dev_vpc"
      service_name        = "s3"
      vpc_endpoint_type   = "Gateway"
      route_table_names   = ["private_rt"]
    }
  }
}

# 💰 Savings: Eliminate NAT Gateway charges for S3 traffic
# If 100GB/month S3: Save $4.50/month = $54/year
```

### 3. Use ARM Instances
```hcl
# Change one line in node groups
eks_nodegroups = {
  default = {
    a = {
      a1 = {
        arch = "arm64"  # ⭐ Change from "x86_64"
        instance_types = "t4g.medium"  # Change from "t3.medium"
        # ... rest unchanged
      }
    }
  }
}

# 💰 Savings: 20% on EC2 costs
```

### 4. Right-Size Over-Provisioned Nodes
```bash
# Check actual utilization
kubectl top nodes

# If consistently <40% utilized, downsize

# Before: t3.large ($60.74/month)
# After: t3.medium ($30.37/month)
# 💰 Savings: $30.37/month = $364.44/year per node
```

### 5. Consolidate Dev Environments
```hcl
# ❌ Before: 3 EKS clusters in dev
# Cost: 3 × $73 = $219/month

# ✅ After: 1 EKS cluster with namespaces
# Cost: $73/month
# 💰 Savings: $146/month = $1,752/year
```

---

## Environment-Specific Strategies

### Development Environment

**Goal:** Minimize costs while maintaining functionality

```hcl
# ✅ Cost-optimized dev configuration
vpc_parameters = {
  default = {
    dev_vpc = {
      cidr_block = "10.10.0.0/16"
    }
  }
}

# Single NAT Gateway (acceptable downtime)
nat_gateway_parameters = {
  default = {
    dev_nat = {
      subnet_name               = "dev_pub_subnet_az1"
      eip_name_for_allocation_id = "dev_nat_eip"
    }
  }
}

# Single EKS cluster
eks_clusters = {
  default = {
    dev = {
      cluster_version = "1.34"
      # Use namespaces for different teams/apps
    }
  }
}

# ARM instances for cost savings
eks_nodegroups = {
  default = {
    dev = {
      dev_nodes = {
        arch           = "arm64"
        instance_types = "t4g.small"  # Smallest viable
        min_size       = 1
        max_size       = 3
        desired_size   = 2
      }
    }
  }
}

# Gateway endpoints (free)
vpc_gateway_endpoint_parameters = {
  default = {
    s3_endpoint = {
      vpc_name          = "dev_vpc"
      service_name      = "s3"
      vpc_endpoint_type = "Gateway"
      route_table_names = ["dev_private_rt"]
    }
  }
}
```

**Monthly Cost Estimate:**
```text
EKS Control Plane:    $73.00
NAT Gateway:          $32.40
2 × t4g.small nodes:  $24.52
EBS volumes:          $10.00
Data transfer:        $5.00
─────────────────────────────
Total:               ~$145/month
```

---

### QE/Staging Environment

**Goal:** Production-like setup at lower cost

```hcl
# Dual-AZ for HA testing
nat_gateway_parameters = {
  qe = {
    qe_nat_az1 = { subnet_name = "qe_pub_az1", ... }
    qe_nat_az2 = { subnet_name = "qe_pub_az2", ... }
  }
}

# Single cluster, smaller nodes
eks_nodegroups = {
  qe = {
    qe = {
      qe_nodes = {
        arch           = "arm64"
        instance_types = "t4g.medium"
        min_size       = 2
        max_size       = 5
        desired_size   = 3
      }
    }
  }
}
```

**Monthly Cost Estimate:**
```text
EKS Control Plane:    $73.00
2 × NAT Gateway:      $64.80
3 × t4g.medium nodes: $73.59
EBS volumes:          $15.00
Data transfer:        $10.00
─────────────────────────────
Total:               ~$236/month
```

---

### Production Environment

**Goal:** Balance cost with reliability

```hcl
# Multi-AZ NAT for HA (required)
nat_gateway_parameters = {
  prod = {
    prod_nat_az1 = { subnet_name = "prod_pub_az1", ... }
    prod_nat_az2 = { subnet_name = "prod_pub_az2", ... }
    prod_nat_az3 = { subnet_name = "prod_pub_az3", ... }
  }
}

# 2-3 clusters for isolation
eks_clusters = {
  prod = {
    prod_frontend = { ... }
    prod_backend  = { ... }
  }
}

# Mix of instance types
eks_nodegroups = {
  prod = {
    prod_frontend = {
      general = {
        arch           = "arm64"
        instance_types = "t4g.medium"
        min_size       = 3
        max_size       = 10
        desired_size   = 5
      }
    }
    prod_backend = {
      api = {
        arch           = "arm64"
        instance_types = "t4g.large"
        min_size       = 3
        max_size       = 15
        desired_size   = 6
      }
    }
  }
}

# High-ROI Interface Endpoints
vpc_gateway_endpoint_parameters = {
  prod = {
    ecr_api = { ... }   # For pulling images
    ecr_dkr = { ... }   # For pulling images
    ec2 = { ... }       # High API volume
  }
}
```

**Monthly Cost Estimate:**
```text
2 × EKS Control Plane:  $146.00
3 × NAT Gateway:         $97.20
11 × nodes (mixed):     ~$400.00
3 × Interface Endpoints: $21.90
EBS volumes:             $50.00
Data transfer:           $100.00
──────────────────────────────
Total:                  ~$815/month
```

---

## Detailed Optimization by Component

### Networking Costs

#### Scenario 1: Small Startup (Dev + Prod)
```text
Before Optimization:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dev:
- 2 NAT Gateways (multi-AZ)        $64.80
- 3 unattached EIPs                $10.80
- No VPC endpoints                  $0.00

Prod:
- 3 NAT Gateways (3-AZ)            $97.20
- Interface endpoints (6)          $43.80
─────────────────────────────────────────
Total:                            $216.60/month

After Optimization:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dev:
- 1 NAT Gateway (single AZ)        $32.40
- S3 Gateway Endpoint (free)        $0.00
- Released unused EIPs              $0.00

Prod:
- 3 NAT Gateways (3-AZ, needed)    $97.20
- Interface endpoints (3, high ROI) $21.90
- S3/DynamoDB Gateway (free)        $0.00
─────────────────────────────────────────
Total:                            $151.50/month

💰 Monthly Savings: $65.10
💰 Annual Savings: $781.20
```

---

### Compute Costs

#### Scenario 2: Medium Company (Multi-tier app)
```text
Before Optimization:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EKS Clusters:
- Dev (3 clusters)                $219.00
- QE (2 clusters)                 $146.00
- Prod (3 clusters)               $219.00

Node Groups (x86):
- Dev: 5 × t3.medium              $151.85
- QE: 5 × t3.medium               $151.85
- Prod: 15 × m5.large           $1,051.20
─────────────────────────────────────────
Total:                          $1,938.90/month

After Optimization:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EKS Clusters:
- Dev (1 cluster)                  $73.00
- QE (1 cluster)                   $73.00
- Prod (2 clusters)               $146.00

Node Groups (ARM + right-sized):
- Dev: 3 × t4g.small               $36.78
- QE: 3 × t4g.medium               $73.59
- Prod: 10 × t4g.large + 
        3 × m6g.large             $637.98
─────────────────────────────────────────
Total:                          $1,040.35/month

💰 Monthly Savings: $898.55
💰 Annual Savings: $10,782.60 (46% reduction!)
```

---

## Cost Monitoring & Alerts

### AWS Cost Explorer

```bash
# Enable Cost Explorer (one-time)
aws ce get-cost-and-usage --help

# View monthly costs
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# EKS-specific costs
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://eks-filter.json
```

**eks-filter.json:**
```json
{
  "Dimensions": {
    "Key": "SERVICE",
    "Values": ["Amazon Elastic Kubernetes Service", "Amazon EC2"]
  }
}
```

### Cost Anomaly Detection

```bash
# Create cost anomaly monitor
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "EKS-Cost-Monitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

# Create alert subscription
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "EKS-Cost-Alerts",
    "Threshold": 100.0,
    "Frequency": "DAILY",
    "MonitorArnList": ["arn:aws:ce::123456789012:anomalymonitor/xxx"],
    "Subscribers": [{
      "Type": "EMAIL",
      "Address": "devops@company.com"
    }]
  }'
```

### CloudWatch Cost Alarms

```bash
# Alert when monthly cost exceeds $500
aws cloudwatch put-metric-alarm \
  --alarm-name monthly-cost-limit \
  --alarm-description "Alert when monthly cost > $500" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --threshold 500 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### Tagging for Cost Allocation

```hcl
# Consistent tagging across all resources
vpc_parameters = {
  default = {
    dev_vpc = {
      cidr_block = "10.10.0.0/16"
      tags = {
        Environment = "dev"
        CostCenter  = "engineering"
        Project     = "chat-app"
        Owner       = "platform-team"
      }
    }
  }
}

eks_clusters = {
  default = {
    dev = {
      cluster_version = "1.34"
      tags = {
        Environment = "dev"
        CostCenter  = "engineering"
        Project     = "chat-app"
      }
    }
  }
}

eks_nodegroups = {
  default = {
    dev = {
      dev_nodes = {
        tags = {
          Environment = "dev"
          CostCenter  = "engineering"
          Workload    = "general"
        }
      }
    }
  }
}
```

**Enable Cost Allocation Tags in AWS:**
```bash
# Activate cost allocation tags
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status \
    TagKey=Environment,Status=Active \
    TagKey=CostCenter,Status=Active \
    TagKey=Project,Status=Active
```

### Custom Cost Dashboard

```bash
#!/bin/bash
# monthly-cost-report.sh

echo "📊 Monthly Cost Report - $(date '+%B %Y')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Total cost
TOTAL=$(aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 month ago' +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
  --output text)

echo "Total Cost: \$TOTAL"
echo ""

# By service
echo "Top Services:"
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 month ago' +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --query 'ResultsByTime[0].Groups | sort_by(@, &Metrics.BlendedCost.Amount) | reverse(@) | [0:5]' \
  --output table

echo ""

# By environment tag
echo "By Environment:"
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 month ago' +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment \
  --query 'ResultsByTime[0].Groups' \
  --output table
```

---

## Architecture Patterns for Cost Efficiency

### Pattern 1: Minimal Viable Dev Environment

```hcl
# Single VPC, single NAT, single cluster
# Total: ~$145/month

vpc_parameters = {
  default = {
    dev_vpc = { cidr_block = "10.10.0.0/16" }
  }
}

nat_gateway_parameters = {
  default = {
    dev_nat = { subnet_name = "dev_pub_subnet" }
  }
}

eks_clusters = {
  default = {
    dev = { cluster_version = "1.34" }
  }
}

eks_nodegroups = {
  default = {
    dev = {
      dev_nodes = {
        arch           = "arm64"
        instance_types = "t4g.small"
        min_size       = 1
        max_size       = 3
        desired_size   = 2
      }
    }
  }
}
```

**Cost Breakdown:**
```text
EKS Control Plane:        $73.00
NAT Gateway:              $32.40
2 × t4g.small nodes:      $24.52
EBS volumes (20GB each):  $10.00
Data transfer:             $5.00
───────────────────────────────
Total:                   ~$145/month
```

---

### Pattern 2: Production HA (Budget-Conscious)

```hcl
# Multi-AZ NAT, single cluster, ARM nodes
# Total: ~$500/month

nat_gateway_parameters = {
  prod = {
    prod_nat_az1 = { subnet_name = "prod_pub_az1" }
    prod_nat_az2 = { subnet_name = "prod_pub_az2" }
  }
}

eks_clusters = {
  prod = {
    prod = { cluster_version = "1.34" }
  }
}

eks_nodegroups = {
  prod = {
    prod = {
      general = {
        arch           = "arm64"
        instance_types = "t4g.medium"
        min_size       = 3
        max_size       = 10
        desired_size   = 5
      }
    }
  }
}

vpc_gateway_endpoint_parameters = {
  prod = {
    s3_endpoint = {
      vpc_endpoint_type = "Gateway"
      service_name      = "s3"
    }
    dynamodb_endpoint = {
      vpc_endpoint_type = "Gateway"
      service_name      = "dynamodb"
    }
  }
}
```

**Cost Breakdown:**
```text
EKS Control Plane:        $73.00
2 × NAT Gateway:          $64.80
5 × t4g.medium nodes:    $122.65
EBS volumes:              $50.00
S3/DynamoDB endpoints:     $0.00
Data transfer:            $50.00
Interface endpoints (2):  $14.60
───────────────────────────────
Total:                   ~$375/month
```

---

### Pattern 3: Enterprise Production (Full HA)

```hcl
# Multi-AZ NAT, multi-cluster, mixed instances
# Total: ~$1,200/month

nat_gateway_parameters = {
  prod = {
    prod_nat_az1 = { subnet_name = "prod_pub_az1" }
    prod_nat_az2 = { subnet_name = "prod_pub_az2" }
    prod_nat_az3 = { subnet_name = "prod_pub_az3" }
  }
}

eks_clusters = {
  prod = {
    prod_frontend = { cluster_version = "1.34" }
    prod_backend  = { cluster_version = "1.34" }
  }
}

eks_nodegroups = {
  prod = {
    prod_frontend = {
      web = {
        arch           = "arm64"
        instance_types = "t4g.large"
        min_size       = 3
        max_size       = 10
        desired_size   = 5
      }
    }
    prod_backend = {
      api = {
        arch           = "arm64"
        instance_types = "c6g.xlarge"
        min_size       = 3
        max_size       = 15
        desired_size   = 8
      }
      data = {
        arch           = "arm64"
        instance_types = "r6g.large"
        min_size       = 2
        max_size       = 6
        desired_size   = 3
      }
    }
  }
}
```

**Cost Breakdown:**
```text
2 × EKS Control Plane:   $146.00
3 × NAT Gateway:          $97.20
5 × t4g.large:           $245.30
8 × c6g.xlarge:          $881.60
3 × r6g.large:           $302.40
Interface endpoints (5):  $36.50
EBS volumes:             $100.00
Data transfer:           $200.00
───────────────────────────────
Total:                 ~$2,009/month
```

---

## Real-World Examples

### Example 1: Startup Migration (Before/After)

**Company Profile:**
- Startup with 10 developers
- 1 staging, 1 production environment
- ~50,000 requests/day

**Before (Cloud-native but unoptimized):**
```text
Staging:
- 1 EKS cluster                      $73.00
- 2 NAT Gateways (multi-AZ)          $64.80
- 4 × t3.medium nodes (x86)         $121.48
- 3 unattached EIPs                  $10.80

Production:
- 2 EKS clusters (frontend/backend) $146.00
- 3 NAT Gateways (3-AZ)              $97.20
- 12 × m5.large nodes (x86)         $840.96
- 4 Interface endpoints              $29.20

Data transfer:                       $150.00
───────────────────────────────────────────
Total:                            $1,533.44/month
Annual:                          $18,401.28
```

**After (Optimized):**
```text
Staging:
- 1 EKS cluster                      $73.00
- 1 NAT Gateway (single AZ)          $32.40
- 3 × t4g.small nodes (ARM)          $36.78
- S3 Gateway Endpoint (free)          $0.00

Production:
- 1 EKS cluster (namespaces)         $73.00
- 2 NAT Gateways (2-AZ)              $64.80
- 8 × t4g.large nodes (ARM)         $392.48
- 2 Interface endpoints (ECR)        $14.60
- S3/DynamoDB Gateway (free)          $0.00

Data transfer (compressed):          $90.00
───────────────────────────────────────────
Total:                              $777.06/month
Annual:                            $9,324.72

💰 Monthly Savings: $756.38
💰 Annual Savings: $9,076.56 (49% reduction!)
```

**Key Changes:**
1. ✅ Consolidated prod clusters (namespaces) - saved $73/month
2. ✅ Reduced staging to single NAT - saved $32.40/month
3. ✅ ARM instances everywhere - saved ~$300/month
4. ✅ Right-sized nodes (m5.large → t4g.large) - saved ~$150/month
5. ✅ Gateway endpoints for S3/DynamoDB - saved ~$30/month
6. ✅ Enabled compression - saved $60/month
7. ✅ Released unused EIPs - saved $10.80/month

---

### Example 2: Mid-Size Company (3 Environments)

**Company Profile:**
- 50 developers
- Dev, QE, Production environments
- ~500,000 requests/day

**Before:**
```text
Development:
- 3 EKS clusters                    $219.00
- 2 NAT Gateways                     $64.80
- 10 × t3.medium nodes              $303.70

QE:
- 2 EKS clusters                    $146.00
- 2 NAT Gateways                     $64.80
- 8 × t3.large nodes                $485.92

Production:
- 4 EKS clusters                    $292.00
- 3 NAT Gateways                     $97.20
- 25 × m5.xlarge nodes            $3,504.00
- 8 Interface endpoints              $58.40

Data transfer:                       $400.00
───────────────────────────────────────────
Total:                            $5,635.82/month
Annual:                          $67,629.84
```

**After:**
```text
Development:
- 1 EKS cluster                      $73.00
- 1 NAT Gateway                      $32.40
- 5 × t4g.small nodes (autoscale)    $61.30

QE:
- 1 EKS cluster                      $73.00
- 2 NAT Gateways                     $64.80
- 5 × t4g.medium nodes              $122.65

Production:
- 2 EKS clusters                    $146.00
- 3 NAT Gateways                     $97.20
- 18 × t4g.xlarge nodes           $1,766.16
- 4 Interface endpoints (high ROI)   $29.20
- S3/DynamoDB Gateway (free)          $0.00

Data transfer (optimized):          $250.00
───────────────────────────────────────────
Total:                            $2,715.71/month
Annual:                          $32,588.52

💰 Monthly Savings: $2,920.11
💰 Annual Savings: $35,041.32 (52% reduction!)
```

**Key Changes:**
1. ✅ Cluster consolidation - saved $438/month
2. ✅ ARM instances with autoscaling - saved ~$2,000/month
3. ✅ Right-sizing (m5.xlarge → t4g.xlarge) - saved ~$1,700/month
4. ✅ Reduced Interface endpoints to high-ROI only - saved $29.20/month
5. ✅ Added S3/DynamoDB Gateway endpoints - saved ~$100/month
6. ✅ Optimized data transfer - saved $150/month

---

## Cost Estimation Tool

### Interactive Cost Calculator

```bash
#!/bin/bash
# eks-cost-calculator.sh

echo "🧮 EKS Infrastructure Cost Calculator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get inputs
read -p "Number of EKS clusters: " CLUSTERS
read -p "Number of NAT Gateways: " NATS
read -p "Node instance type (t4g.small/t4g.medium/t4g.large/t4g.xlarge): " INSTANCE_TYPE
read -p "Number of nodes: " NODES
read -p "Number of Interface endpoints: " ENDPOINTS
read -p "Estimated data transfer (GB/month): " DATA_GB

# Pricing
EKS_CLUSTER_COST=73
NAT_GATEWAY_COST=32.40
DATA_TRANSFER_COST=0.09
INTERFACE_ENDPOINT_COST=7.30

# Instance pricing (monthly)
case $INSTANCE_TYPE in
  t4g.small)  NODE_COST=12.26 ;;
  t4g.medium) NODE_COST=24.53 ;;
  t4g.large)  NODE_COST=49.06 ;;
  t4g.xlarge) NODE_COST=98.11 ;;
  *) NODE_COST=24.53 ;;
esac

# Calculate
CLUSTER_TOTAL=$(echo "$CLUSTERS * $EKS_CLUSTER_COST" | bc)
NAT_TOTAL=$(echo "$NATS * $NAT_GATEWAY_COST" | bc)
NODE_TOTAL=$(echo "$NODES * $NODE_COST" | bc)
ENDPOINT_TOTAL=$(echo "$ENDPOINTS * $INTERFACE_ENDPOINT_COST" | bc)
DATA_TOTAL=$(echo "$DATA_GB * $DATA_TRANSFER_COST" | bc)

MONTHLY_TOTAL=$(echo "$CLUSTER_TOTAL + $NAT_TOTAL + $NODE_TOTAL + $ENDPOINT_TOTAL + $DATA_TOTAL" | bc)
ANNUAL_TOTAL=$(echo "$MONTHLY_TOTAL * 12" | bc)

# Display
echo ""
echo "📊 Cost Breakdown:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "EKS Clusters ($CLUSTERS):          \$CLUSTER_TOTAL"
echo "NAT Gateways ($NATS):          \$NAT_TOTAL"
echo "Nodes ($NODES × $INSTANCE_TYPE):    \$NODE_TOTAL"
echo "Interface Endpoints ($ENDPOINTS):  \$ENDPOINT_TOTAL"
echo "Data Transfer ($DATA_GB GB):      \$DATA_TOTAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Monthly Total:                \$MONTHLY_TOTAL"
echo "Annual Total:                 \$ANNUAL_TOTAL"
```

### Example Usage

```bash
$ bash eks-cost-calculator.sh

🧮 EKS Infrastructure Cost Calculator
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Number of EKS clusters: 2
Number of NAT Gateways: 2
Node instance type: t4g.medium
Number of nodes: 8
Number of Interface endpoints: 3
Estimated data transfer (GB/month): 500

📊 Cost Breakdown:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EKS Clusters (2):          $146.00
NAT Gateways (2):          $64.80
Nodes (8 × t4g.medium):    $196.24
Interface Endpoints (3):   $21.90
Data Transfer (500 GB):    $45.00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Monthly Total:             $473.94
Annual Total:              $5,687.28
```

---

## Cost Optimization Checklist

### Weekly Tasks
- [ ] Check for unattached Elastic IPs
- [ ] Review node utilization (`kubectl top nodes`)
- [ ] Check autoscaler logs for scaling events
- [ ] Review CloudWatch cost anomalies

### Monthly Tasks
- [ ] Review AWS Cost Explorer by service
- [ ] Analyze data transfer costs
- [ ] Review Interface endpoint usage
- [ ] Check for unused EBS volumes
- [ ] Review instance right-sizing opportunities

### Quarterly Tasks
- [ ] Review cluster consolidation opportunities
- [ ] Evaluate Savings Plans / Reserved Instances
- [ ] Review architecture for cost optimizations
- [ ] Update cost allocation tags
- [ ] Conduct cost review with team

### Annual Tasks
- [ ] Comprehensive infrastructure audit
- [ ] Review AWS Enterprise Support costs
- [ ] Evaluate multi-year commitments
- [ ] Update disaster recovery cost projections

---

## Common Cost Pitfalls

### ❌ Pitfall 1: Over-Provisioned Nodes
```text
Problem: "We might need the capacity"
Reality: 60% idle nodes costing $500/month

Solution: Use autoscaling
- Start small: min_size = 2
- Scale up: max_size = 10
- Let demand drive scaling
```

### ❌ Pitfall 2: Forgetting Unused Resources
```text
Problem: "We'll clean up later"
Reality: 5 unattached EIPs = $18/month wasted

Solution: Automate cleanup
- Weekly sweep for unattached EIPs
- Terminate unused clusters
- Delete orphaned EBS volumes
```

### ❌ Pitfall 3: Wrong Instance Types
```text
Problem: "m5.2xlarge should handle anything"
Reality: 20% CPU usage, $280/month overspend

Solution: Right-size based on metrics
- Monitor actual usage
- Start small, scale up if needed
- Use ARM instances for 20% savings
```

### ❌ Pitfall 4: Too Many Clusters
```text
Problem: "Each team needs their own cluster"
Reality: 10 clusters × $73 = $730/month

Solution: Use namespaces
- 1-2 clusters per environment
- Kubernetes namespaces for isolation
- Save $500+/month
```

### ❌ Pitfall 5: Ignoring Interface Endpoint ROI
```text
Problem: "Let's add all Interface endpoints"
Reality: 10 endpoints × $7.30 = $73/month
         Low traffic = negative ROI

Solution: Calculate break-even
- Only add if traffic > 208 GB/month
- Start with free Gateway endpoints
- Monitor actual savings
```

---

## Advanced Cost Optimization Techniques

### 1. Savings Plans / Reserved Instances

For predictable workloads:

```text
On-Demand t4g.large: $49.06/month
1-year Reserved: $30.37/month (38% savings)
3-year Reserved: $20.91/month (57% savings)

Example: 10 nodes for 1 year
On-Demand: $5,887.20/year
1-year RI: $3,644.40/year
Savings: $2,242.80/year (38%)
```

**When to use:**
- ✅ Stable production workloads
- ✅ Baseline capacity (not burst)
- ✅ Commitment for 1-3 years
- ❌ Dev/test environments
- ❌ Unpredictable workloads

### 2. Spot Instances for Batch Workloads

```hcl
# Use Spot for non-critical workloads
eks_nodegroups = {
  prod = {
    prod_backend = {
      batch_spot = {
        arch           = "arm64"
        instance_types = "t4g.medium"
        min_size       = 0
        max_size       = 10
        desired_size   = 0
        capacity_type  = "SPOT"  # 70% discount
        tags = {
          Workload = "batch-jobs"
        }
      }
    }
  }
}

# 💰 Savings: t4g.medium spot ~$7.36/month vs $24.53 on-demand
```

### 3. Scheduled Scaling for Non-Prod

```bash
# Scale down dev/QE during off-hours
# Weekdays 6PM - 8AM: min_size = 0
# Weekends: min_size = 0

# Example: 5 nodes × t4g.medium
# Full time: $122.65/month
# Business hours only: ~$60/month
# 💰 Savings: $62.65/month = $751.80/year
```

### 4. Cross-Region Cost Optimization

If using multiple regions:

```text
Data Transfer Pricing:
- Same region, cross-AZ: $0.01/GB
- Cross-region (within US): $0.02/GB
- Cross-region (US ↔ Asia): $0.09/GB

Optimization:
- Use VPC Peering instead of VPN ($0.05/hour)
- Replicate data during off-peak
- Use S3 Transfer Acceleration for uploads
```

---

## Summary: Quick Reference

### Free Services (Use These!)
- ✅ Elastic IPs (when attached)
- ✅ Internet Gateways
- ✅ Route Tables
- ✅ Security Groups
- ✅ VPC Gateway Endpoints (S3, DynamoDB)

### Expensive Services (Optimize These!)
- 💰 NAT Gateways ($32.40/month each)
- 💰 EKS Control Plane ($73/month each)
- 💰 EC2/EKS Nodes ($12-98/month each)
- 💰 Interface Endpoints ($7.30/month each)
- 💰 Data Transfer ($0.09/GB outbound)

### Top 5 Cost Savings
1. **Use ARM instances** → 20% savings
2. **Single NAT in dev** → $32.40/month savings
3. **Cluster consolidation** → $73+/month per cluster
4. **S3 Gateway Endpoint** → Eliminate NAT costs for S3
5. **Right-size nodes** → 30-50% savings possible

### ROI Thresholds
- Interface Endpoint: Break-even at ~208 GB/month
- Multi-AZ NAT: Worth it for production (HA)
- ARM instances: Always worth it (20% savings, no trade-offs)
- Reserved Instances: 38% savings for stable workloads

---

## Additional Resources

- **AWS Pricing Calculator:** https://calculator.aws/
- **AWS Cost Explorer:** https://console.aws.amazon.com/cost-management/
- **AWS Cost Optimization Hub:** https://aws.amazon.com/aws-cost-management/
- **EKS Best Practices - Cost:** https://aws.github.io/aws-eks-best-practices/cost_optimization/
- **AWS Trusted Advisor:** https://console.aws.amazon.com/trustedadvisor/

---

## Contact & Support

For cost optimization questions or infrastructure review:
- Infrastructure Team: devops@company.com
- Slack: #infrastructure-costs
- Wiki: /wiki/cost-optimization

**Last Updated:** January 2026
**Next Review:** April 2025