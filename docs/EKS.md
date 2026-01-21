# EKS (Elastic Kubernetes Service)

## Table of Contents

- [Overview](#overview)
- [Understanding EKS](#understanding-eks)
- [Architecture Components](#architecture-components)
- [Quick Start](#quick-start)
- [Configuration Guide](#configuration-guide)
- [Common Patterns](#common-patterns)
- [Scaling Strategies](#scaling-strategies)
- [Security Best Practices](#security-best-practices)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)
- [Quick Reference](#quick-reference)
- [Summary](#summary)

---

## Overview

Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service that eliminates the need to install, operate, and maintain your own Kubernetes control plane. This framework provides comprehensive EKS cluster and node group management across multiple environments.

### What You'll Learn

- How to create and manage EKS clusters
- Node group configuration and scaling strategies
- Multi-cluster architectures
- Security best practices
- Cost optimization techniques
- Troubleshooting common issues

### Key Features

- ✅ **Managed Control Plane:** AWS handles Kubernetes masters
- ✅ **Multi-Environment Support:** Dev, QE, and Production configurations
- ✅ **Auto-Scaling:** Cluster autoscaler integration
- ✅ **ARM Support:** Cost-effective Graviton instances
- ✅ **High Availability:** Multi-AZ deployment
- ✅ **Security:** IAM integration, private endpoints, security groups

---

## Understanding EKS

### EKS Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS EKS Service                          │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │         EKS Control Plane (Managed by AWS)       │      │
│  │                                                  │      │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │      │
│  │  │ API      │  │ Scheduler│  │Controller│      │      │
│  │  │ Server   │  │          │  │ Manager  │      │      │
│  │  └──────────┘  └──────────┘  └──────────┘      │      │
│  │                                                  │      │
│  │  ┌──────────────────────────────────────┐       │      │
│  │  │        etcd (distributed)            │       │      │
│  │  └──────────────────────────────────────┘       │      │
│  └──────────────────────────────────────────────────┘      │
│                         │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          │ Private Link
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    Your VPC                                 │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐  │
│  │   Private       │  │   Private       │  │  Private   │  │
│  │   Subnet AZ-1   │  │   Subnet AZ-2   │  │ Subnet AZ-3│  │
│  │                 │  │                 │  │            │  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │ ┌────────┐│  │
│  │  │Worker Node│  │  │  │Worker Node│  │  │ │Worker  ││  │
│  │  │  (Pod)    │  │  │  │  (Pod)    │  │  │ │Node    ││  │
│  │  └───────────┘  │  │  └───────────┘  │  │ └────────┘│  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │ ┌────────┐│  │
│  │  │Worker Node│  │  │  │Worker Node│  │  │ │Worker  ││  │
│  │  │  (Pod)    │  │  │  │  (Pod)    │  │  │ │Node    ││  │
│  │  └───────────┘  │  │  └───────────┘  │  │ └────────┘│  │
│  └─────────────────┘  └─────────────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### What AWS Manages vs You Manage

| Component | Managed By | Your Responsibility |
|---|---|---|
| Control Plane | AWS | Configure access (public/private) |
| etcd | AWS | N/A |
| API Server | AWS | Configure RBAC, authentication |
| Scheduler | AWS | N/A |
| Worker Nodes | You | Instance types, scaling, AMI updates |
| Networking | You | VPC, subnets, security groups |
| Applications | You | Deployments, services, ingress |
| Add-ons | Mixed | Install/configure (VPC CNI, CoreDNS, etc.) |

---

## Architecture Components

### 1. EKS Cluster (Control Plane)

The cluster is the Kubernetes control plane managed by AWS.

**Key configurations:**
- Kubernetes version: `1.34`, `1.33`, `1.32`, etc.
- API endpoint access: Public, Private, or Both
- Networking: VPC, subnets, security groups
- **Cost:** `$0.10/hour` (~`$73/month`) per cluster

**When you need multiple clusters:**
- **Single cluster:** use namespaces for isolation (cost: `$73/month`)
- **Multi-cluster:** isolate environments, compliance boundaries, team autonomy, or workload tiers (cost: `$73/month × clusters`)

### 2. Node Groups (Worker Nodes)

Node groups are managed collections of EC2 instances that run your workloads.

**Key configurations:**
- Instance types: `t3.medium`, `t4g.small`, `m5.large`, etc.
- Architecture: `x86_64` or `arm64`
- Scaling: min, max, desired
- Cost: EC2 instance pricing (varies)

**Strategies:**
- **Single node group:** simplest for general workloads
- **Multiple node groups:** by workload type, team/project, or mixed architecture (ARM + x86)

### 3. Networking Components

**VPC configuration:**
- Subnets in multiple AZs (minimum 2; recommended 3)
- Private subnets recommended for production
- Public subnets optional (for load balancers)

**Security groups:**
- Cluster SG controls control-plane traffic
- Node SG controls worker node traffic

**Required connectivity:**
- Cluster ↔ Nodes:
  - `443` (API server)
  - `10250` (Kubelet API)
  - `30000-32767` (NodePort services)
- Node ↔ Node:
  - All traffic (pod-to-pod as needed; depends on CNI/policies)
- Nodes → Internet/AWS APIs:
  - For image pulls, AWS APIs, add-ons (use NAT or VPC endpoints)

---

## Quick Start

### Example 1: Single Development Cluster

#### Step 1: Define Security Groups

```hcl
# terraform.tfvars

security_group_parameters = {
  default = {
    dev_cluster_sg = {
      name     = "dev-eks-cluster-sg"
      vpc_name = "dev_vpc"
      tags     = { Purpose = "EKS-Control-Plane" }
    }

    dev_node_sg = {
      name     = "dev-eks-node-sg"
      vpc_name = "dev_vpc"
      tags     = { Purpose = "EKS-Worker-Nodes" }
    }
  }
}

ipv4_ingress_rule = {
  default = {
    cluster_from_nodes = {
      vpc_name                   = "dev_vpc"
      sg_name                    = "dev_cluster_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "dev_node_sg"
    }

    node_kubelet = {
      vpc_name                   = "dev_vpc"
      sg_name                    = "dev_node_sg"
      from_port                  = 10250
      to_port                    = 10250
      protocol                   = "TCP"
      source_security_group_name = "dev_cluster_sg"
    }

    node_self = {
      vpc_name                   = "dev_vpc"
      sg_name                    = "dev_node_sg"
      protocol                   = "-1"
      source_security_group_name = "dev_node_sg"
    }
  }
}

ipv4_egress_rule = {
  default = {
    cluster_egress = {
      vpc_name  = "dev_vpc"
      sg_name   = "dev_cluster_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }

    node_egress = {
      vpc_name  = "dev_vpc"
      sg_name   = "dev_node_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

#### Step 2: Define EKS Cluster

```hcl
eks_clusters = {
  default = {
    dev_cluster = {
      cluster_version         = "1.34"
      vpc_name                = "dev_vpc"
      subnet_name             = ["dev_private_a", "dev_private_b"]
      sg_name                 = ["dev_cluster_sg"]
      endpoint_public_access  = true
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Team        = "platform"
        ManagedBy   = "terraform"
      }
    }
  }
}
```

#### Step 3: Define Node Groups

```hcl
eks_nodegroups = {
  default = {
    dev_cluster = {
      general_nodes = {
        k8s_version    = "1.34"
        arch           = "arm64"
        min_size       = 1
        max_size       = 3
        desired_size   = 2
        instance_types = "t4g.small"
        subnet_name    = ["dev_private_a", "dev_private_b"]
        node_security_group_names = ["dev_node_sg"]
        tags = {
          Environment = "dev"
          NodeGroup   = "general"
        }
      }
    }
  }
}
```

#### Step 4: Deploy

```bash
terraform init
terraform plan
terraform apply
```

#### Step 5: Configure kubectl

```bash
aws eks update-kubeconfig --name dev_cluster --region us-east-1
kubectl cluster-info
kubectl get nodes
```

---

## Configuration Guide

### Cluster Configuration

```hcl
eks_clusters = {
  <workspace> = {
    <cluster_key> = {
      cluster_version         = string
      vpc_name                = string
      subnet_name             = list(string)
      sg_name                 = list(string)
      endpoint_public_access  = bool
      endpoint_private_access = bool
      tags                    = map(string)
    }
  }
}
```

**Version guidance**
- Upgrade one minor version at a time: `1.32 → 1.33 → 1.34`

### Node Group Configuration

```hcl
eks_nodegroups = {
  <workspace> = {
    <cluster_key> = {
      <nodegroup_key> = {
        k8s_version               = string
        arch                      = string              # "x86_64" or "arm64"
        min_size                  = number
        max_size                  = number
        desired_size              = number
        instance_types            = string
        instance_ami              = optional(string)
        subnet_name               = list(string)
        node_security_group_names = list(string)
        tags                      = map(string)
      }
    }
  }
}
```

---

## Common Patterns

- **Single cluster per environment** (dev + prod)
- **Multi-cluster by tier** (frontend/backend/data)
- **Multiple node groups** (general/memory/compute)
- **Private cluster + VPC endpoints** (no NAT)

---

## Scaling Strategies

### Manual Scaling

Update `desired_size` and apply.

### Cluster Autoscaler

- Scales node groups when pods can’t be scheduled
- Respects `min_size` and `max_size`

### Horizontal Pod Autoscaler (HPA)

- Scales pods based on metrics
- Works best paired with Cluster Autoscaler

---

## Security Best Practices

- Prefer **private-only** endpoints for production clusters
- Keep nodes in **private subnets**
- Use **least-privilege security groups**
- Use **IRSA** for workload AWS access
- Use **Secrets Manager/SSM Parameter Store** for secrets
- Apply **Pod Security Standards** and **NetworkPolicies**

---

## Cost Optimization

- Control plane is fixed at ~`$73/month` per cluster
- Consolidate dev clusters using namespaces when possible
- Prefer **ARM (Graviton)** for cost/performance
- Right-size using `kubectl top`
- Use autoscaling to reduce average nodes
- Use VPC endpoints to reduce NAT costs (especially for ECR pulls)

---

## Troubleshooting

- **Nodes not joining:** IAM policies, SG rules, subnet IP space, NAT/endpoints
- **API access issues:** public/private endpoint configuration, CIDR allowlist, VPN/bastion
- **Pods pending:** insufficient resources, requests too high, autoscaler misconfig
- **ImagePullBackOff:** ECR auth/policy, image exists, NAT/endpoints for ECR+S3

---

## Advanced Topics

- **Blue/Green cluster migrations** for version upgrades
- **Multi-region EKS** for DR/global apps
- **GitOps** with FluxCD/ArgoCD
- **Service mesh** (Istio) for mTLS and traffic management

---

## Quick Reference

### Common kubectl Commands

```bash
kubectl cluster-info
kubectl get nodes
kubectl top nodes
kubectl get pods --all-namespaces
kubectl describe pod <pod>
kubectl logs <pod> -f
kubectl exec -it <pod> -- /bin/bash
```

### Minimum HA

- 3 AZ subnets
- Node group `min_size = 3` (one per AZ)

---

## Summary

### Key Takeaways

- ✅ EKS manages the control plane; you manage nodes and networking
- ✅ Control plane costs are fixed per cluster
- ✅ ARM nodes reduce cost and improve price/performance
- ✅ Private endpoints are recommended for production
- ✅ Autoscaling improves efficiency
- ✅ VPC endpoints can reduce/remove NAT dependency

### Next Steps

- Read module-specific READMEs (cluster + nodegroup)
- Review `NETWORKING.md` for VPC architecture
- Check `NETWORK_SECURITY.md` for SG configuration
- Use `TROUBLESHOOTING.md` for operational issues
