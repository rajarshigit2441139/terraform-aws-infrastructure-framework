# Security Groups & Rules

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Configuration Guide](#configuration-guide)
- [Common Patterns](#common-patterns)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)
- [Quick Reference](#quick-reference)
- [Summary](#summary)

---

## Overview

Security Groups act as virtual firewalls that control inbound and outbound traffic for your AWS resources. This framework provides a powerful, flexible way to manage security groups and their rules across multiple environments.

### What You'll Learn

- How to create security groups and rules
- Best practices for securing multi-tier applications
- How to use security group references for dynamic security
- Common security patterns for web apps, databases, and EKS clusters

### Key Features

- ✅ **Dynamic SG References:** Reference security groups by name, not ID  
- ✅ **CIDR Auto-Resolution:** Automatically use VPC CIDR blocks  
- ✅ **Multi-Environment:** Same configuration across dev/staging/prod  
- ✅ **Stateful Firewall:** Return traffic automatically allowed  
- ✅ **Zero Circular Dependencies:** Framework handles SG creation order  

---

## Architecture

### Traffic Flow Model

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │ 0.0.0.0/0
                         ▼
                  ┌──────────────┐
                  │   ALB SG     │  Port 443 (HTTPS)
                  │  (Public)    │  Port 80  (HTTP)
                  └──────┬───────┘
                         │ SG Reference
                         ▼
                  ┌──────────────┐
                  │   Web SG     │  Port 3000
                  │  (Private)   │
                  └──────┬───────┘
                         │ SG Reference
                         ▼
                  ┌──────────────┐
                  │   App SG     │  Port 8080
                  │  (Private)   │
                  └──────┬───────┘
                         │ SG Reference
                         ▼
                  ┌──────────────┐
                  │   DB SG      │  Port 5432
                  │  (Private)   │
                  └──────────────┘
```

### Security Group Components

```
Security Group
├── Name & VPC Association
├── Tags
├── Ingress Rules (Inbound)
│   ├── Source: CIDR Block OR Security Group
│   ├── Protocol: TCP/UDP/ICMP/-1
│   └── Port Range: from_port → to_port
└── Egress Rules (Outbound)
    ├── Destination: CIDR Block OR Security Group
    ├── Protocol: TCP/UDP/ICMP/-1
    └── Port Range: from_port → to_port
```

---

## Quick Start

### Basic Web Application

#### Step 1: Define Security Groups

```hcl
# terraform.tfvars
security_group_parameters = {
  default = {
    web_sg = {
      name     = "my-web-sg"
      vpc_name = "my_vpc"
      tags     = { Tier = "web" }
    }

    db_sg = {
      name     = "my-db-sg"
      vpc_name = "my_vpc"
      tags     = { Tier = "database" }
    }
  }
}
```

#### Step 2: Define Ingress Rules

```hcl
ipv4_ingress_rule = {
  default = {
    # Web: Accept HTTPS from internet
    web_https = {
      vpc_name  = "my_vpc"
      sg_name   = "web_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }

    # DB: Accept from web tier only
    db_from_web = {
      vpc_name                   = "my_vpc"
      sg_name                    = "db_sg"
      from_port                  = 5432
      to_port                    = 5432
      protocol                   = "TCP"
      source_security_group_name = "web_sg"  # SG reference
    }
  }
}
```

#### Step 3: Define Egress Rules

```hcl
ipv4_egress_rule = {
  default = {
    web_egress = {
      vpc_name  = "my_vpc"
      sg_name   = "web_sg"
      protocol  = "-1"           # All protocols
      cidr_ipv4 = "0.0.0.0/0"    # All destinations
    }

    db_egress = {
      vpc_name  = "my_vpc"
      sg_name   = "db_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

#### Step 4: Deploy

```bash
terraform plan
terraform apply
```

**Result:**

- ✅ Web servers accept HTTPS from anywhere
- ✅ Database accepts connections only from web tier
- ✅ All outbound traffic allowed
- ✅ Return traffic automatically allowed (stateful)

---

## Core Concepts

### 1. Stateful Firewall

Security groups are **stateful** — you only define inbound rules, and return traffic is automatically allowed.

```hcl
# You define this:
web_https = {
  sg_name   = "web_sg"
  from_port = 443
  protocol  = "TCP"
  cidr_ipv4 = "0.0.0.0/0"
}

# AWS automatically allows response traffic back to the client.
```

### 2. CIDR-Based Rules

Control traffic based on IP address ranges.

**Common CIDR Blocks:**
```
0.0.0.0/0        → Entire internet (all IPv4 addresses)
10.0.0.0/16      → Specific VPC (example)
10.0.1.0/24      → Specific subnet
203.0.113.50/32  → Single IP address
```

Example — allow from office:

```hcl
office_access = {
  sg_name   = "app_sg"
  from_port = 22
  protocol  = "TCP"
  cidr_ipv4 = "203.0.113.0/24"  # Office IP range
}
```

### 3. Security Group References

Reference other security groups instead of IP addresses.

**Why this matters:**
- ✅ Dynamic (works when instance IPs change)
- ✅ Secure (no need to track IPs)
- ✅ Scalable (applies to all instances in source SG)
- ✅ Readable (use `web_sg` vs `sg-abc123`)

```hcl
# App tier accepts from web tier
app_from_web = {
  vpc_name                   = "my_vpc"
  sg_name                    = "app_sg"              # Target
  from_port                  = 8080
  protocol                   = "TCP"
  source_security_group_name = "web_sg"              # Source
}
```

**What happens:**
- Any instance with `web_sg` attached can connect to port 8080 on any instance with `app_sg`
- No IP addresses needed
- Works as instances scale up/down

### 4. Protocol Specifications

| Protocol | Value | Common Ports | Use Case |
|---------|-------|--------------|----------|
| TCP | `"TCP"` | 80, 443, 22, 3306, 5432 | HTTP, HTTPS, SSH, DBs |
| UDP | `"UDP"` | 53, 123 | DNS, NTP |
| ICMP | `"ICMP"` | N/A | Ping, traceroute |
| All | `"-1"` | N/A | All traffic (typically egress only) |

> **Important:** When `protocol = "-1"`, don’t specify `from_port` or `to_port` (set to `null` automatically).

### 5. Ingress vs Egress

**Ingress (Inbound):** Traffic coming into your resource (be restrictive).  
**Egress (Outbound):** Traffic leaving your resource (often allow all).

---

## Configuration Guide

### Security Group Configuration

```hcl
security_group_parameters = {
  <workspace> = {
    <sg_key> = {
      name     = string                      # REQUIRED: SG name in AWS
      vpc_name = string                      # REQUIRED: VPC key reference
      tags     = optional(map(string), {})   # OPTIONAL: Additional tags
    }
  }
}
```

Parameter details:

| Parameter | Required | Type | Description | Example |
|---|---:|---|---|---|
| `name` | ✅ Yes | string | Security group name (unique per VPC) | `"web-sg"` |
| `vpc_name` | ✅ Yes | string | VPC key from VPC module | `"my_vpc"` |
| `tags` | ❌ No | map(string) | Additional tags | `{ Tier = "web" }` |

Example:

```hcl
security_group_parameters = {
  default = {
    web_sg = {
      name     = "production-web-sg"
      vpc_name = "prod_vpc"
      tags = {
        Tier        = "web"
        Environment = "production"
        CostCenter  = "engineering"
      }
    }
  }
}
```

### Ingress Rule Configuration

```hcl
ipv4_ingress_rule = {
  <workspace> = {
    <rule_key> = {
      vpc_name                   = string              # REQUIRED
      sg_name                    = string              # REQUIRED
      from_port                  = number              # REQUIRED (unless protocol = "-1")
      to_port                    = number              # REQUIRED (unless protocol = "-1")
      protocol                   = string              # REQUIRED
      cidr_ipv4                  = optional(string)    # OPTIONAL
      source_security_group_name = optional(string)    # OPTIONAL
    }
  }
}
```

Notes:
- Ports not required when `protocol = "-1"`
- Provide **either** `cidr_ipv4` **or** `source_security_group_name` (not both)
- If neither is provided, defaults to VPC CIDR (framework behavior)

### Egress Rule Configuration

```hcl
ipv4_egress_rule = {
  <workspace> = {
    <rule_key> = {
      vpc_name                   = string              # REQUIRED
      sg_name                    = string              # REQUIRED
      protocol                   = string              # REQUIRED
      cidr_ipv4                  = optional(string)    # OPTIONAL
      source_security_group_name = optional(string)    # OPTIONAL
    }
  }
}
```

Common pattern (allow all outbound):

```hcl
web_egress = {
  vpc_name  = "my_vpc"
  sg_name   = "web_sg"
  protocol  = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}
```

---

## Common Patterns

### Pattern 1: Public Web Server

Scenario: Web server accessible from internet, connects to internal database.

```hcl
security_group_parameters = {
  default = {
    web_sg = { name = "public-web-sg",  vpc_name = "app_vpc" }
    db_sg  = { name = "private-db-sg",  vpc_name = "app_vpc" }
  }
}

ipv4_ingress_rule = {
  default = {
    web_https = { vpc_name = "app_vpc", sg_name = "web_sg", from_port = 443, to_port = 443, protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
    web_http  = { vpc_name = "app_vpc", sg_name = "web_sg", from_port = 80,  to_port = 80,  protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
    db_from_web = { vpc_name = "app_vpc", sg_name = "db_sg", from_port = 5432, to_port = 5432, protocol = "TCP", source_security_group_name = "web_sg" }
  }
}

ipv4_egress_rule = {
  default = {
    web_egress = { vpc_name = "app_vpc", sg_name = "web_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    db_egress  = { vpc_name = "app_vpc", sg_name = "db_sg",  protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
  }
}
```

Traffic flow:

```
Internet (0.0.0.0/0)
   │ 443/80
   ▼
 Web SG
   │ 5432 (SG ref)
   ▼
 DB SG
```

### Pattern 2: Three-Tier Architecture

Load Balancer → Web → App → DB

```hcl
security_group_parameters = {
  default = {
    alb_sg = { name = "internet-alb-sg", vpc_name = "prod_vpc", tags = { Tier = "load-balancer" } }
    web_sg = { name = "frontend-sg",     vpc_name = "prod_vpc", tags = { Tier = "presentation" } }
    app_sg = { name = "backend-api-sg",  vpc_name = "prod_vpc", tags = { Tier = "application" } }
    db_sg  = { name = "database-sg",     vpc_name = "prod_vpc", tags = { Tier = "data" } }
  }
}

ipv4_ingress_rule = {
  default = {
    alb_https     = { vpc_name = "prod_vpc", sg_name = "alb_sg", from_port = 443, to_port = 443, protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
    alb_http      = { vpc_name = "prod_vpc", sg_name = "alb_sg", from_port = 80,  to_port = 80,  protocol = "TCP", cidr_ipv4 = "0.0.0.0/0" }
    web_from_alb  = { vpc_name = "prod_vpc", sg_name = "web_sg", from_port = 3000, to_port = 3000, protocol = "TCP", source_security_group_name = "alb_sg" }
    app_from_web  = { vpc_name = "prod_vpc", sg_name = "app_sg", from_port = 8080, to_port = 8080, protocol = "TCP", source_security_group_name = "web_sg" }
    db_from_app   = { vpc_name = "prod_vpc", sg_name = "db_sg",  from_port = 5432, to_port = 5432, protocol = "TCP", source_security_group_name = "app_sg" }
  }
}

ipv4_egress_rule = {
  default = {
    alb_egress = { vpc_name = "prod_vpc", sg_name = "alb_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    web_egress = { vpc_name = "prod_vpc", sg_name = "web_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    app_egress = { vpc_name = "prod_vpc", sg_name = "app_sg", protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
    db_egress  = { vpc_name = "prod_vpc", sg_name = "db_sg",  protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
  }
}
```

---

## Security Best Practices

- Apply least privilege
- Use SG references internally
- Don’t expose databases to the internet
- Restrict SSH to bastion + office/VPN CIDRs
- Audit rules regularly

---

## Troubleshooting

Common checks:

```bash
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=sg-xxxxx"
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=vpc-xxxxx"
terraform workspace show
terraform plan
```

---

## Advanced Topics

- Self-referencing rules
- IPv6 rules (require explicit `security_group_id`)
- Cross-VPC traffic uses CIDR (SG refs are same-VPC only)
- Dynamic rule generation with locals
- Monitoring via Flow Logs / Security Hub

---

## Quick Reference

### Common Ports

| Service | Port | Protocol |
|---|---:|---|
| HTTP | 80 | TCP |
| HTTPS | 443 | TCP |
| SSH | 22 | TCP |
| PostgreSQL | 5432 | TCP |
| Kubernetes API | 6443 | TCP |
| Kubelet | 10250 | TCP |

---

## Summary

- Security groups are stateful
- Prefer SG references for internal access
- Use CIDRs for external sources
- Layer defenses and audit regularly
