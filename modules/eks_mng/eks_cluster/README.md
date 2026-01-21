# EKS Cluster Module

## Overview

This module creates and manages AWS Elastic Kubernetes Service (EKS) clusters. EKS is a managed Kubernetes service that runs Kubernetes control plane instances across multiple AWS availability zones, eliminating the need to install, operate, and maintain your own Kubernetes control plane.

## Module Purpose

- Creates EKS cluster control planes
- Manages cluster IAM roles and policies
- Configures VPC networking for clusters
- Controls API endpoint access (public/private)
- Supports multiple clusters per workspace
- Provides outputs for node group attachment
- Enables multi-environment cluster management

## Module Location

```
modules/eks_mng/eks_cluster/
├── main.tf          # Cluster and IAM resources
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **5 types of resources** per cluster:

1. **EKS Cluster** - `aws_eks_cluster`
2. **Cluster IAM Role** - `aws_iam_role`
3. **Cluster Policy Attachment** - `aws_iam_role_policy_attachment` (AmazonEKSClusterPolicy)
4. **VPC Resource Controller Attachment** - `aws_iam_role_policy_attachment` (AmazonEKSVPCResourceController)
5. **IAM Policy Document** - `data.aws_iam_policy_document` (AssumeRole)

### EKS Cluster Definition

```hcl
resource "aws_eks_cluster" "cluster" {
  for_each = var.eks_clusters
  name     = each.key
  role_arn = aws_iam_role.eks_cluster[each.key].arn
  version  = each.value.cluster_version

  vpc_config {
    subnet_ids              = each.value.subnet_ids
    endpoint_private_access = each.value.endpoint_private_access
    endpoint_public_access  = each.value.endpoint_public_access
    security_group_ids      = each.value.security_group_ids
  }
  
  tags = merge(each.value.tags, {
    Name : each.key
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }

  depends_on = [
    aws_iam_role.eks_cluster,
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_controller
  ]
}
```

### IAM Role Definition

```hcl
resource "aws_iam_role" "eks_cluster" {
  for_each           = var.eks_clusters
  name               = "${each.key}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

data "aws_iam_policy_document" "eks_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
```

### Policy Attachments

```hcl
# Required policy for EKS cluster operations
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  for_each   = var.eks_clusters
  role       = aws_iam_role.eks_cluster[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Required policy for VPC resource management
resource "aws_iam_role_policy_attachment" "eks_vpc_controller" {
  for_each   = var.eks_clusters
  role       = aws_iam_role.eks_cluster[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}
```

## Inputs

### `eks_clusters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** N/A

Map of EKS cluster configurations.

#### Object Structure

```hcl
{
  cluster_version         = string              # REQUIRED
  vpc_id                  = string              # REQUIRED
  subnet_ids              = list(string)        # REQUIRED
  security_group_ids      = optional(list(string))  # OPTIONAL
  endpoint_public_access  = bool                # REQUIRED
  endpoint_private_access = bool                # REQUIRED
  tags                    = map(string)         # REQUIRED
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `cluster_version` | string | ✅ Yes | - | Kubernetes version (e.g., "1.34", "1.33", "1.32") |
| `vpc_id` | string | ✅ Yes | - | VPC ID where cluster will be created |
| `subnet_ids` | list(string) | ✅ Yes | - | Subnet IDs for cluster ENIs (minimum 2, recommended in different AZs) |
| `security_group_ids` | list(string) | ❌ No | `[]` | Additional security group IDs for cluster control plane |
| `endpoint_public_access` | bool | ✅ Yes | - | Enable public API endpoint access |
| `endpoint_private_access` | bool | ✅ Yes | - | Enable private API endpoint access (within VPC) |
| `tags` | map(string) | ✅ Yes | - | Tags to apply to the cluster |

#### Kubernetes Versions

Supported versions (as of January 2026):
- `"1.34"` - Latest (use for new clusters)
- `"1.33"` - Stable
- `"1.32"` - Supported
- `"1.31"` - Minimum supported

**Note:** AWS typically supports the latest 4 Kubernetes versions. Check AWS documentation for current supported versions.

#### Subnet Requirements

- **Minimum:** 2 subnets
- **Recommended:** 3+ subnets across multiple AZs
- **Type:** Can be public or private (private recommended for production)
- **CIDR:** Must have sufficient IPs for cluster ENIs
- **Tags:** Should be tagged for EKS (handled by subnet module)

Required subnet tags (auto-applied by framework):
```hcl
tags = {
  "kubernetes.io/cluster/${cluster_name}" = "shared"
}
```

#### Endpoint Access Patterns

| Pattern | Public | Private | Use Case |
|---------|--------|---------|----------|
| **Public Only** | ✅ true | ❌ false | Development, testing (NOT recommended for prod) |
| **Private Only** | ❌ false | ✅ true | Maximum security, requires VPN/bastion |
| **Both** | ✅ true | ✅ true | Production (restrict public with CIDR/SG) |
| **Neither** | ❌ false | ❌ false | ❌ INVALID - at least one must be true |

## Outputs

### `eks_clusters`

**Type:** `map(object)`  
**Description:** Map of EKS cluster outputs indexed by cluster name (key)

#### Output Structure

```hcl
{
  "<cluster_key>" = {
    cluster_name                      = string  # Cluster name
    cluster_arn                       = string  # Cluster ARN
    cluster_endpoint                  = string  # API server endpoint
    cluster_cert                      = string  # CA certificate (base64)
    cluster_role_arn                  = string  # Cluster IAM role ARN
    cluster_version                   = string  # Kubernetes version
    cluster_primary_security_group_id = string  # Auto-created SG ID
  }
}
```

#### Output Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `cluster_name` | string | EKS cluster name | "a" (frontend cluster) |
| `cluster_arn` | string | Cluster ARN | "arn:aws:eks:region:account:cluster/a" |
| `cluster_endpoint` | string | Kubernetes API endpoint | "https://ABC123.gr7.region.eks.amazonaws.com" |
| `cluster_cert` | string | Base64-encoded CA certificate | "LS0tLS1CRUdJTi..." |
| `cluster_role_arn` | string | IAM role ARN used by cluster | "arn:aws:iam::account:role/a-eks-cluster-role" |
| `cluster_version` | string | Running Kubernetes version | "1.34" |
| `cluster_primary_security_group_id` | string | EKS-managed security group ID | "sg-0abc123def456" |

## Usage in Root Module

### Called From

`07_eks.tf` in the root module

### Module Call

```hcl
module "eks_cluster" {
  source = "./modules/eks_mng/eks_cluster"

  for_each = local.generated_cluster_config

  eks_clusters = {
    (each.key) = each.value
  }

  depends_on = [
    module.chat_app_subnet,
    module.chat_app_security_group,
    module.chat_app_security_rules,
  ]
}
```

### Dynamic Parameter Generation

**In `07_eks.tf` (root):**

```hcl
locals {
  # Get workspace-specific cluster config
  cluster_config = lookup(var.eks_clusters, terraform.workspace, {})

  # Inject VPC ID, subnet IDs, and SG IDs
  generated_cluster_config = {
    for cluster_name, cluster in local.cluster_config :
    cluster_name => merge(
      cluster,
      {
        vpc_id = local.vpc_id_by_name[cluster.vpc_name]

        subnet_ids = [
          for subnet_name in cluster.subnet_name :
          local.subnet_id_by_name[subnet_name]
        ]

        security_group_ids = [
          for sg_name in cluster.sg_name :
          local.sgs_id_by_name[sg_name]
        ]
      }
    )
  }
}
```

### Variable Structure in Root

**In `variables.tf` (root):**

```hcl
variable "eks_clusters" {
  description = "Map of EKS cluster configurations"
  type = map(map(object({
    cluster_version         = string
    vpc_name                = optional(string)
    vpc_id                  = optional(string)
    subnet_name             = optional(list(string))
    subnet_ids              = optional(list(string))
    sg_name                 = optional(list(string))
    endpoint_public_access  = bool
    endpoint_private_access = bool
    tags                    = map(string)
  })))
}
```

### Example Configuration in terraform.tfvars

```hcl
eks_clusters = {
  default = {
    # Frontend cluster
    a = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_dev_vpc1"
      subnet_name             = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      sg_name                 = ["chat_app_dev_cluster_sg"]
      endpoint_public_access  = true
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Cluster     = "a"
        Purpose     = "frontend"
      }
    }

    # Backend cluster
    b = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_dev_vpc1"
      subnet_name             = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
      sg_name                 = ["chat_app_dev_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Cluster     = "b"
        Purpose     = "backend"
      }
    }
  }

  qe = {
    qe-a = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_qe_vpc1"
      subnet_name             = ["qe_vpc1_pri_sub1", "qe_vpc1_pri_sub2"]
      sg_name                 = ["chat_app_qe_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "qe"
        Cluster     = "QE-a"
      }
    }
  }

  prod = {
    prod-1 = {
      cluster_version         = "1.34"
      vpc_name                = "chat_app_prod_vpc1"
      subnet_name             = ["prod_vpc1_pri_sub1", "prod_vpc1_pri_sub2", "prod_vpc1_pri_sub3"]
      sg_name                 = ["chat_app_prod_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "prod"
        Cluster     = "prod-1"
      }
    }
  }
}
```

## Configuration Examples

### Example 1: Basic Development Cluster

```hcl
eks_clusters = {
  default = {
    dev_cluster = {
      cluster_version         = "1.34"
      vpc_name                = "dev_vpc"
      subnet_name             = ["private_subnet_1", "private_subnet_2"]
      sg_name                 = ["eks_cluster_sg"]
      endpoint_public_access  = true   # Easy access for dev
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Team        = "platform"
      }
    }
  }
}
```

**Characteristics:**
- ✅ Public + Private endpoints (flexible access)
- 💰 Cost-effective (single cluster)
- 🔧 Easy kubectl access from anywhere

### Example 2: Production Cluster (High Security)

```hcl
eks_clusters = {
  prod = {
    prod_main = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = [
        "prod_private_subnet_az1",
        "prod_private_subnet_az2",
        "prod_private_subnet_az3"
      ]
      sg_name                 = ["eks_cluster_sg", "vpn_access_sg"]
      endpoint_public_access  = false  # Maximum security
      endpoint_private_access = true
      tags = {
        Environment    = "prod"
        Compliance     = "PCI-DSS"
        BackupRequired = "true"
      }
    }
  }
}
```

**Characteristics:**
- 🔒 Private-only API endpoint
- ✅ Multi-AZ (3 availability zones)
- 🔐 VPN/bastion required for kubectl access

### Example 3: Multi-Cluster Per Environment

```hcl
eks_clusters = {
  default = {
    # Frontend cluster
    frontend = {
      cluster_version         = "1.34"
      vpc_name                = "shared_vpc"
      subnet_name             = ["web_subnet_1", "web_subnet_2"]
      sg_name                 = ["frontend_cluster_sg"]
      endpoint_public_access  = true
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Tier        = "frontend"
        Team        = "web"
      }
    }

    # Backend cluster
    backend = {
      cluster_version         = "1.34"
      vpc_name                = "shared_vpc"
      subnet_name             = ["app_subnet_1", "app_subnet_2"]
      sg_name                 = ["backend_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Tier        = "backend"
        Team        = "api"
      }
    }

    # Data processing cluster
    data = {
      cluster_version         = "1.34"
      vpc_name                = "shared_vpc"
      subnet_name             = ["data_subnet_1", "data_subnet_2"]
      sg_name                 = ["data_cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "dev"
        Tier        = "data"
        Team        = "analytics"
      }
    }
  }
}
```

**Pattern:** Workload isolation via separate clusters

### Example 4: Staged Kubernetes Version Migration

```hcl
eks_clusters = {
  prod = {
    # Current production cluster
    prod_v33 = {
      cluster_version         = "1.33"
      vpc_name                = "prod_vpc"
      subnet_name             = ["subnet_1", "subnet_2"]
      sg_name                 = ["cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "prod"
        Version     = "legacy"
      }
    }

    # New cluster for migration
    prod_v34 = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = ["subnet_1", "subnet_2"]
      sg_name                 = ["cluster_sg"]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment = "prod"
        Version     = "new"
        Migration   = "in-progress"
      }
    }
  }
}
```

**Use Case:** Blue-green cluster migration for version upgrades

### Example 5: Multi-Environment with Different Access Patterns

```hcl
eks_clusters = {
  # Dev: Public access for ease of use
  default = {
    dev = {
      cluster_version         = "1.34"
      vpc_name                = "dev_vpc"
      subnet_name             = ["private_sub_1", "private_sub_2"]
      sg_name                 = ["dev_cluster_sg"]
      endpoint_public_access  = true
      endpoint_private_access = true
      tags = { Environment = "dev" }
    }
  }

  # QE: Restricted public access
  qe = {
    qe = {
      cluster_version         = "1.34"
      vpc_name                = "qe_vpc"
      subnet_name             = ["private_sub_1", "private_sub_2"]
      sg_name                 = ["qe_cluster_sg", "office_access_sg"]
      endpoint_public_access  = true   # Restricted by SG
      endpoint_private_access = true
      tags = { Environment = "qe" }
    }
  }

  # Prod: Private only
  prod = {
    prod = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = ["private_sub_1", "private_sub_2", "private_sub_3"]
      sg_name                 = ["prod_cluster_sg"]
      endpoint_public_access  = false  # Private only
      endpoint_private_access = true
      tags = { Environment = "prod" }
    }
  }
}
```

## EKS Cluster Architecture Patterns

### Pattern 1: Single Cluster (Small Teams)

```
┌─────────────────────────────────────┐
│          EKS Cluster                │
│                                     │
│  ┌──────────┐  ┌──────────┐       │
│  │ Frontend │  │ Backend  │       │
│  │Namespace │  │Namespace │       │
│  └──────────┘  └──────────┘       │
└─────────────────────────────────────┘
```

**Pros:** Simple, cost-effective  
**Cons:** No workload isolation, blast radius

### Pattern 2: Multi-Cluster by Tier

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Frontend   │  │   Backend    │  │     Data     │
│  EKS Cluster │  │ EKS Cluster  │  │ EKS Cluster  │
└──────────────┘  └──────────────┘  └──────────────┘
```

**Pros:** Workload isolation, security  
**Cons:** Higher cost, more complexity

### Pattern 3: Multi-Cluster by Environment

```
┌──────┐  ┌──────┐  ┌──────┐
│ Dev  │  │  QE  │  │ Prod │
│Cluster│ │Cluster│ │Cluster│
└──────┘  └──────┘  └──────┘
```

**Pros:** Environment isolation  
**Cons:** Configuration drift risk

### Pattern 4: Hybrid (Recommended)

```
Dev: Single cluster
QE:  Single cluster  
Prod: Multi-cluster (frontend/backend)
```

**Balance:** Cost vs security vs complexity

## Security Group Requirements

### Cluster Security Group

The cluster security group controls traffic to the EKS control plane:

```hcl
# In 03_security_group.tf (example)
security_group_parameters = {
  default = {
    eks_cluster_sg = {
      name     = "eks-cluster-sg"
      vpc_name = "main_vpc"
      tags     = { Purpose = "EKS-Control-Plane" }
    }
  }
}

# Ingress: Accept HTTPS from worker nodes
ipv4_ingress_rule = {
  default = {
    cluster_from_nodes = {
      vpc_name                   = "main_vpc"
      sg_name                    = "eks_cluster_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "eks_node_sg"
    }
  }
}

# Egress: Allow all
ipv4_egress_rule = {
  default = {
    cluster_egress = {
      vpc_name  = "main_vpc"
      sg_name   = "eks_cluster_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

### Required Rules

**Cluster SG Ingress:**
- Port 443 from node security group (HTTPS)

**Cluster SG Egress:**
- All traffic (for pulling images, accessing AWS APIs)

**Node SG (covered in nodegroup module):**
- Ingress from cluster SG (ports 443, 10250, 30000-32767)
- Egress to all

## IAM Roles and Policies

### Cluster IAM Role

Automatically created with name: `${cluster_name}-eks-cluster-role`

**Attached Policies:**

1. **AmazonEKSClusterPolicy**
   - Core EKS permissions
   - Manage ENIs, route tables, security groups
   - Call EC2, ELB APIs

2. **AmazonEKSVPCResourceController**
   - Manage VPC resources
   - Create/delete ENIs
   - Assign security groups

### AssumeRole Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "eks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

### Additional Policies (if needed)

Add custom policies for specific requirements:

```hcl
resource "aws_iam_role_policy_attachment" "custom" {
  role       = aws_iam_role.eks_cluster["cluster_name"].name
  policy_arn = "arn:aws:iam::aws:policy/CustomPolicy"
}
```

## Kubernetes API Access

### Access Patterns

#### 1. Public + Private (Development)

```hcl
endpoint_public_access  = true
endpoint_private_access = true
```

**Access From:**
- ✅ Anywhere on internet
- ✅ Within VPC
- ✅ Peered VPCs

**Security:**
- Restrict public access with CIDR allowlists (via AWS Console/CLI)
- Use security groups

#### 2. Private Only (Production)

```hcl
endpoint_public_access  = false
endpoint_private_access = true
```

**Access From:**
- ✅ Within VPC only
- ✅ Via VPN/Direct Connect
- ✅ From bastion/jump host

**Security:**
- Maximum security
- No internet exposure

**kubectl Access:**
```bash
# Option 1: SSH tunnel via bastion
ssh -L 8443:cluster-endpoint:443 bastion-host
export KUBECONFIG=./kubeconfig
kubectl get nodes --server=https://localhost:8443

# Option 2: VPN connection
# Connect to VPN, then use kubectl normally
kubectl get nodes
```

#### 3. Public Only (NOT Recommended)

```hcl
endpoint_public_access  = true
endpoint_private_access = false
```

**⚠️ Not recommended** - Nodes within VPC can't reach API efficiently

### Restricting Public Access

After cluster creation, restrict public endpoint:

```bash
# Allow only specific CIDR blocks
aws eks update-cluster-config \
  --name cluster-name \
  --resources-vpc-config \
    endpointPublicAccess=true,\
    publicAccessCidrs=["203.0.113.0/24","198.51.100.0/24"]
```

## Cluster Outputs Usage

### In Node Group Module

Node groups need cluster name and endpoint:

```hcl
# In 07_eks.tf
module "eks_nodegroups" {
  for_each = local.generated_nodegroup_config

  source = "./modules/eks_mng/eks_nodegroups"

  cluster_name = module.eks_cluster[each.key].eks_clusters[each.key].cluster_name

  nodegroup_parameters = each.value

  depends_on = [module.eks_cluster]
}
```

### Kubeconfig Generation

```hcl
# Output kubeconfig
output "kubeconfig" {
  value = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name     = module.eks_cluster["prod"].eks_clusters["prod"].cluster_name
    cluster_endpoint = module.eks_cluster["prod"].eks_clusters["prod"].cluster_endpoint
    cluster_ca       = module.eks_cluster["prod"].eks_clusters["prod"].cluster_cert
  })
  sensitive = true
}
```

### AWS Auth ConfigMap

```bash
# Get cluster details
CLUSTER_NAME=$(terraform output -json eks_cluster_names | jq -r '.a')
ROLE_ARN=$(terraform output -json eks_cluster_role_arns | jq -r '.a')

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region ap-south-1

# Verify
kubectl get nodes
```

## Lifecycle Management

### Prevent Destroy

Default: `prevent_destroy = false`

For production clusters:

```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes  = [tags]
}
```

**When to enable:**
- Production clusters
- Clusters with stateful workloads
- Clusters with important data

### Version Upgrades

EKS supports in-place version upgrades:

```hcl
# Step 1: Update version in terraform.tfvars
eks_clusters = {
  prod = {
    main = {
      cluster_version = "1.34"  # Was 1.33
      # ... other params
    }
  }
}

# Step 2: Plan and apply
terraform plan
terraform apply
```

**Important:**
- ✅ Always upgrade one minor version at a time (1.32 → 1.33 → 1.34)
- ✅ Update node groups after cluster upgrade
- ✅ Test in dev/QE first
- ⚠️ May cause temporary API unavailability

### Cluster Deletion

```bash
# Delete node groups first
terraform destroy -target=module.eks_nodegroups

# Then delete cluster
terraform destroy -target=module.eks_cluster

# Or delete entire workspace
terraform workspace select prod
terraform destroy
```

## Dependencies

### This Module Depends On

- ✅ **VPC Module** - Must have VPC created
- ✅ **Subnet Module** - Must have subnets (minimum 2)
- ✅ **Security Group Module** - Must have cluster security group
- IAM (managed by this module)

### Modules That Depend On This

- ✅ **EKS Node Group Module** - Requires cluster name and endpoint
- Kubernetes resources (via kubectl/Helm)
- Service mesh installations
- Monitoring/logging agents

## Best Practices

### Cluster Design

✅ **Do:**
- Use private subnets for cluster ENIs
- Enable both public and private endpoints for dev
- Use private-only endpoints for production
- Deploy across multiple AZs (minimum 2, recommended 3)
- Use descriptive cluster names (avoid generic names)
- Tag clusters with environment, team, purpose

❌ **Don't:**
- Use public subnets for production clusters
- Use public-only endpoint access
- Deploy in single AZ
- Use cluster names like "cluster1", "test"
- Skip tagging
- Mix environments in same cluster (dev + prod)

### Version Management

✅ **Do:**
- Pin exact Kubernetes versions
- Test upgrades in dev/QE first
- Upgrade regularly (quarterly)
- Keep within AWS support window
- Document version upgrade procedures

❌ **Don't:**
- Use "latest" or auto-upgrade
- Skip minor versions (1.32 → 1.34)
- Run unsupported versions
- Upgrade prod without testing
- Forget to upgrade node groups after cluster

### Security

✅ **Do:**
```hcl
# Good: Private-only for production
endpoint_public_access  = false
endpoint_private_access = true
security_group_ids      = ["restrictive_sg"]
```

❌ **Don't:**
```hcl
# Bad: Public access without restrictions
endpoint_public_access  = true
endpoint_private_access = false
security_group_ids      = []  # No additional SGs
```

### Multi-Cluster Strategy

✅ **Do:**
- Separate prod from non-prod
- Use namespaces for small teams/projects
- Use separate clusters for different SLAs
- Implement GitOps for config management

❌ **Don't:**
- Over-segment (too many tiny clusters)
- Share clusters across compliance boundaries
- Mix PCI/HIPAA workloads with regular apps

## Validation

### After Creation

```bash
# Verify cluster creation
terraform output eks_cluster_names

# Update kubeconfig
aws eks update-kubeconfig \
  --name $(terraform output -json eks_cluster_names | jq -r '.a') \
  --region ap-south-1

# Check cluster status
kubectl cluster-info
kubectl get nodes  # Will be empty until node groups are created

# Check cluster details
aws eks describe-cluster --name cluster-name

# Verify API endpoint accessibility
curl -k https://$(terraform output -json eks_cluster_endpoints | jq -r '.a')
```

### Health Checks

```bash
# Cluster health
aws eks describe-cluster --name cluster-name \
  --query 'cluster.health'

# API server availability
kubectl get --raw /healthz

# Control plane logs (enable first)
aws eks describe-cluster --name cluster-name \
  --query 'cluster.logging'
```

## Troubleshooting

### Issue: Cluster Creation Timeout

**Symptoms:**
```
Error: error waiting for EKS Cluster to be created: timeout while waiting for state to become 'ACTIVE'
```

**Solution:**
- Cluster creation typically takes 10-15 minutes
- Check subnet routing (needs route to internet for pulling images)
- Verify IAM role has correct permissions
- Check VPC has DNS support enabled
- Ensure security groups allow required traffic

```bash
# Check cluster status
aws eks describe-cluster --name cluster-name --query 'cluster.status'

# Check for errors
aws eks describe-cluster --name cluster-name --query 'cluster.health'

# Verify VPC DNS settings
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx \
  --query 'Vpcs[0].[EnableDnsSupport,EnableDnsHostnames]'
```

### Issue: Cannot Access API Endpoint

**Symptoms:**
```
Unable to connect to the server: dial tcp: lookup xxx.eks.amazonaws.com: no such host
```

**Solution:**

**For Private-Only Clusters:**
```bash
# Ensure you're accessing from within VPC
# Option 1: Use bastion host
ssh bastion-host
aws eks update-kubeconfig --name cluster-name

# Option 2: VPN connection
# Connect to VPN first, then use kubectl

# Option 3: SSH tunnel
ssh -L 8443:cluster-endpoint:443 bastion-host
# Update kubeconfig to use localhost:8443
```

**For Public Clusters:**
```bash
# Check public access is enabled
aws eks describe-cluster --name cluster-name \
  --query 'cluster.resourcesVpcConfig.endpointPublicAccess'

# Check CIDR restrictions
aws eks describe-cluster --name cluster-name \
  --query 'cluster.resourcesVpcConfig.publicAccessCidrs'

# Update CIDR allowlist if needed
aws eks update-cluster-config \
  --name cluster-name \
  --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs=["0.0.0.0/0"]
```

### Issue: IAM Role Creation Failed

**Symptoms:**
```
Error: error creating IAM Role: EntityAlreadyExists
```

**Solution:**
- IAM role name `${cluster_name}-eks-cluster-role` already exists
- Choose different cluster name
- Or manually delete existing role (if safe)

```bash
# Check if role exists
aws iam get-role --role-name cluster-name-eks-cluster-role

# Delete if safe (ensure nothing is using it)
aws iam delete-role --role-name cluster-name-eks-cluster-role
```

### Issue: Subnet Not Tagged Properly

**Symptoms:**
```
Error: error creating EKS Cluster: InvalidParameterException: Subnet subnet-xxxxx does not have required tags
```

**Solution:**
- Subnets must be tagged for EKS
- Public subnets need `kubernetes.io/role/elb = 1`
- Private subnets need `kubernetes.io/role/internal-elb = 1`

```bash
# Tag private subnets (for internal load balancers)
aws ec2 create-tags --resources subnet-xxxxx \
  --tags Key=kubernetes.io/role/internal-elb,Value=1

# Tag public subnets (for external load balancers)
aws ec2 create-tags --resources subnet-xxxxx \
  --tags Key=kubernetes.io/role/elb,Value=1

# Tag all subnets with cluster name
aws ec2 create-tags --resources subnet-xxxxx \
  --tags Key=kubernetes.io/cluster/cluster-name,Value=shared
```

**Note:** This framework should auto-apply these tags via subnet module.

### Issue: Security Group Rules Missing

**Symptoms:**
```
Nodes cannot join cluster
API server unreachable from nodes
```

**Solution:**
- Ensure cluster SG allows ingress from node SG on port 443
- Ensure node SG allows ingress from cluster SG on ports 443, 10250, 30000-32767

```bash
# Verify cluster security group rules
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-xxxxx"

# Add missing rule if needed (should be in terraform config)
# See security group module documentation
```

### Issue: Cluster Version Not Supported

**Symptoms:**
```
Error: InvalidParameterException: Unsupported Kubernetes version
```

**Solution:**
- AWS only supports latest 4 Kubernetes versions
- Check supported versions:

```bash
# List supported versions
aws eks describe-addon-versions \
  --query 'addons[0].addonVersions[*].compatibilities[*].clusterVersion' \
  --output text | tr '\t' '\n' | sort -u

# Update to supported version
# In terraform.tfvars:
cluster_version = "1.34"  # Use supported version
```

### Issue: VPC Configuration Error

**Symptoms:**
```
Error: InvalidParameterException: The vpc-config has an invalid configuration
```

**Solution:**
- Must specify at least 2 subnets
- Subnets must be in different AZs
- At least one endpoint (public or private) must be enabled

```hcl
# Good configuration
subnet_ids              = ["subnet-az1", "subnet-az2"]  # Different AZs
endpoint_public_access  = true
endpoint_private_access = true

# Bad configuration
subnet_ids              = ["subnet-az1"]  # Only 1 subnet
endpoint_public_access  = false
endpoint_private_access = false  # Both disabled - INVALID
```

### Issue: Cannot Delete Cluster

**Symptoms:**
```
Error: error deleting EKS Cluster: ResourceInUseException: Cluster has nodegroups attached
```

**Solution:**
- Delete all node groups first
- Delete Fargate profiles if any
- Then delete cluster

```bash
# List node groups
aws eks list-nodegroups --cluster-name cluster-name

# Delete node groups (or use terraform)
terraform destroy -target=module.eks_nodegroups

# Then delete cluster
terraform destroy -target=module.eks_cluster
```

### Issue: Cluster Stuck in UPDATING State

**Symptoms:**
```
Cluster status: UPDATING for extended period
```

**Solution:**
- Usually resolves automatically within 15-20 minutes
- Check for failed add-on updates
- Cancel update if stuck >30 minutes

```bash
# Check update status
aws eks describe-update \
  --name cluster-name \
  --update-id update-id

# List recent updates
aws eks list-updates --name cluster-name

# If truly stuck, contact AWS support
```

## Cost Considerations

### EKS Cluster Pricing

**Control Plane:**
- $0.10 per hour per cluster
- $73 per month per cluster
- Same cost regardless of size

**Example Costs:**

| Scenario | Clusters | Monthly Cost |
|----------|----------|--------------|
| Single dev cluster | 1 | $73 |
| Dev + QE + Prod | 3 | $219 |
| Multi-cluster prod (3 clusters) | 5 | $365 |

**Additional Costs (not from EKS cluster module):**
- Worker nodes (EC2 instances) - see nodegroup module
- EBS volumes for persistent storage
- Data transfer
- NAT Gateway charges
- Load balancer charges

### Cost Optimization Tips

✅ **Do:**
1. **Share clusters when appropriate**
   - Use namespaces for different teams/apps in dev
   - Single cluster per environment for small teams

2. **Use Fargate selectively**
   - For bursty workloads
   - Avoid for always-on workloads

3. **Right-size node groups**
   - Don't over-provision
   - Use cluster autoscaler

4. **Monitor idle clusters**
   - Delete unused dev/test clusters
   - Use scheduled start/stop for non-prod

❌ **Don't:**
1. Create separate cluster for every microservice
2. Leave idle clusters running
3. Over-segment without justification
4. Ignore control plane costs in budgeting

### Cost Example

**Scenario: E-commerce Platform**

```hcl
# Development: Single cluster
default = {
  dev = { ... }  # $73/month
}

# QE: Single cluster
qe = {
  qe = { ... }  # $73/month
}

# Production: 3 clusters (frontend, backend, data)
prod = {
  frontend = { ... }  # $73/month
  backend  = { ... }  # $73/month
  data     = { ... }  # $73/month
}

# Total control plane cost: $365/month
# Plus worker nodes, storage, networking
```

## Monitoring and Observability

### Control Plane Logging

Enable CloudWatch logs for cluster:

```bash
# Enable all log types
aws eks update-cluster-config \
  --name cluster-name \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'

# View logs in CloudWatch
aws logs tail /aws/eks/cluster-name/cluster --follow
```

**Log Types:**
- `api` - Kubernetes API server logs
- `audit` - Kubernetes audit logs
- `authenticator` - IAM authenticator logs
- `controllerManager` - Controller manager logs
- `scheduler` - Scheduler logs

### Metrics

Key metrics to monitor:

```bash
# Cluster health
aws eks describe-cluster --name cluster-name \
  --query 'cluster.health'

# Control plane metrics (via CloudWatch)
# - API server latency
# - API server request rate
# - Etcd performance
```

### Alerts

```bash
# Create CloudWatch alarm for cluster issues
aws cloudwatch put-metric-alarm \
  --alarm-name eks-cluster-health \
  --alarm-description "EKS cluster health check" \
  --metric-name cluster-status \
  --namespace AWS/EKS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator LessThanThreshold
```

## Kubernetes Add-ons

After cluster creation, install essential add-ons:

### VPC CNI (Networking)

```bash
# Usually pre-installed, but verify
kubectl get daemonset -n kube-system aws-node

# Update if needed
aws eks create-addon --cluster-name cluster-name \
  --addon-name vpc-cni \
  --addon-version v1.15.0
```

### CoreDNS

```bash
# Install CoreDNS
aws eks create-addon --cluster-name cluster-name \
  --addon-name coredns \
  --addon-version v1.11.1
```

### kube-proxy

```bash
# Install kube-proxy
aws eks create-addon --cluster-name cluster-name \
  --addon-name kube-proxy \
  --addon-version v1.34.0
```

### EBS CSI Driver (for persistent volumes)

```bash
# Create IAM role for CSI driver (IRSA)
# Then install add-on
aws eks create-addon --cluster-name cluster-name \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::ACCOUNT:role/AmazonEKS_EBS_CSI_DriverRole
```

## Authentication and Authorization

### kubectl Access

```bash
# Configure kubectl
aws eks update-kubeconfig --name cluster-name --region ap-south-1

# Test access
kubectl get svc

# Switch between clusters
kubectl config use-context arn:aws:eks:region:account:cluster/cluster-name
```

### IAM to Kubernetes RBAC Mapping

```bash
# Get current aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml

# Add IAM users/roles
kubectl edit configmap aws-auth -n kube-system
```

**Example aws-auth ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::ACCOUNT:role/NodeInstanceRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::ACCOUNT:role/DevOpsRole
      username: devops-user
      groups:
        - system:masters
  mapUsers: |
    - userarn: arn:aws:iam::ACCOUNT:user/admin
      username: admin
      groups:
        - system:masters
```

### IRSA (IAM Roles for Service Accounts)

```bash
# Create OIDC provider (one-time per cluster)
eksctl utils associate-iam-oidc-provider \
  --cluster cluster-name \
  --approve

# Create service account with IAM role
eksctl create iamserviceaccount \
  --cluster cluster-name \
  --namespace default \
  --name my-service-account \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve
```

## Network Architecture

### Cluster Network Design

```
┌─────────────────────────────────────────────────────────┐
│                        VPC                               │
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │  Public Subnet   │         │  Public Subnet   │     │
│  │      AZ-1        │         │      AZ-2        │     │
│  │                  │         │                  │     │
│  │  [NAT Gateway]   │         │  [NAT Gateway]   │     │
│  └────────┬─────────┘         └────────┬─────────┘     │
│           │                            │               │
│  ┌────────▼─────────┐         ┌────────▼─────────┐     │
│  │ Private Subnet   │         │ Private Subnet   │     │
│  │      AZ-1        │         │      AZ-2        │     │
│  │                  │         │                  │     │
│  │  [EKS Control    │         │  [EKS Control    │     │
│  │   Plane ENI]     │         │   Plane ENI]     │     │
│  │                  │         │                  │     │
│  │  [Worker Nodes]  │         │  [Worker Nodes]  │     │
│  └──────────────────┘         └──────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Traffic Flow

**Pod to Internet:**
```
Pod → Node → NAT Gateway → Internet Gateway → Internet
```

**kubectl to Cluster:**
```
# Public endpoint
Developer → Internet → EKS API Endpoint → Control Plane

# Private endpoint
Developer → VPN/Bastion → VPC → EKS API Endpoint → Control Plane
```

**Node to Control Plane:**
```
Worker Node → Private Link ENI → Control Plane
```

## Disaster Recovery

### Backup Strategy

```bash
# Backup cluster configuration
terraform show -json > cluster-backup-$(date +%Y%m%d).json

# Export kubeconfig
kubectl config view --raw > kubeconfig-backup.yaml

# Backup Kubernetes resources (use Velero)
velero backup create cluster-backup-$(date +%Y%m%d)

# Store in version control
git add terraform.tfvars
git commit -m "Cluster config backup $(date +%Y-%m-%d)"
```

### Recovery Procedure

If cluster is lost:

1. **Recreate from Terraform:**
```bash
terraform workspace select prod
terraform apply -target=module.eks_cluster
```

2. **Restore Kubernetes resources:**
```bash
# Using Velero
velero restore create --from-backup cluster-backup-20250114

# Or reapply from GitOps repo
kubectl apply -f k8s-manifests/
```

3. **Verify:**
```bash
kubectl get all --all-namespaces
kubectl get pv,pvc --all-namespaces
```

### High Availability Considerations

✅ **Control Plane:**
- AWS manages HA automatically
- Multi-AZ by default
- No action needed

✅ **Worker Nodes:**
- Deploy node groups across multiple AZs
- Use cluster autoscaler
- See nodegroup module documentation

## Real-World Example: Complete Multi-Environment Setup

```hcl
# =============================================================================
# Complete EKS Cluster Configuration
# =============================================================================

eks_clusters = {
  # =================
  # DEVELOPMENT
  # =================
  default = {
    # Single cluster for all dev workloads
    dev_main = {
      cluster_version         = "1.34"
      vpc_name                = "dev_vpc"
      subnet_name             = [
        "dev_private_subnet_az1",
        "dev_private_subnet_az2"
      ]
      sg_name                 = [
        "dev_eks_cluster_sg"
      ]
      endpoint_public_access  = true   # Easy access for developers
      endpoint_private_access = true
      tags = {
        Environment  = "dev"
        ManagedBy    = "terraform"
        Team         = "platform"
        CostCenter   = "engineering"
        AutoShutdown = "enabled"  # Shutdown nights/weekends
      }
    }
  }

  # =================
  # QE/STAGING
  # =================
  qe = {
    # Production-like setup for testing
    qe_main = {
      cluster_version         = "1.34"
      vpc_name                = "qe_vpc"
      subnet_name             = [
        "qe_private_subnet_az1",
        "qe_private_subnet_az2",
        "qe_private_subnet_az3"
      ]
      sg_name                 = [
        "qe_eks_cluster_sg",
        "office_access_sg"  # Restrict public access
      ]
      endpoint_public_access  = true   # Restricted by SG
      endpoint_private_access = true
      tags = {
        Environment = "qe"
        ManagedBy   = "terraform"
        Team        = "qa"
        CostCenter  = "quality-assurance"
        Purpose     = "pre-production-testing"
      }
    }
  }

  # =================
  # PRODUCTION
  # =================
  prod = {
    # Frontend cluster (public-facing services)
    prod_frontend = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = [
        "prod_private_subnet_az1",
        "prod_private_subnet_az2",
        "prod_private_subnet_az3"
      ]
      sg_name                 = [
        "prod_eks_cluster_sg",
        "prod_vpn_access_sg"
      ]
      endpoint_public_access  = false  # Maximum security
      endpoint_private_access = true
      tags = {
        Environment     = "prod"
        Tier            = "frontend"
        ManagedBy       = "terraform"
        Team            = "web-platform"
        CostCenter      = "production"
        Compliance      = "PCI-DSS"
        BackupRequired  = "true"
        MonitoringLevel = "critical"
      }
    }

    # Backend cluster (API services)
    prod_backend = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = [
        "prod_private_subnet_az1",
        "prod_private_subnet_az2",
        "prod_private_subnet_az3"
      ]
      sg_name                 = [
        "prod_eks_cluster_sg",
        "prod_vpn_access_sg"
      ]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment     = "prod"
        Tier            = "backend"
        ManagedBy       = "terraform"
        Team            = "api-platform"
        CostCenter      = "production"
        Compliance      = "PCI-DSS,SOC2"
        BackupRequired  = "true"
        MonitoringLevel = "critical"
      }
    }

    # Data processing cluster (batch jobs, ML)
    prod_data = {
      cluster_version         = "1.34"
      vpc_name                = "prod_vpc"
      subnet_name             = [
        "prod_private_subnet_az1",
        "prod_private_subnet_az2",
        "prod_private_subnet_az3"
      ]
      sg_name                 = [
        "prod_eks_cluster_sg",
        "prod_vpn_access_sg"
      ]
      endpoint_public_access  = false
      endpoint_private_access = true
      tags = {
        Environment     = "prod"
        Tier            = "data"
        ManagedBy       = "terraform"
        Team            = "data-engineering"
        CostCenter      = "production"
        Purpose         = "batch-ml-workloads"
        BackupRequired  = "true"
        MonitoringLevel = "high"
      }
    }
  }
}
```

**Architecture:**
```
Development:
  └── 1 cluster (all workloads via namespaces)
      Cost: $73/month + nodes

QE/Staging:
  └── 1 cluster (production-like testing)
      Cost: $73/month + nodes

Production:
  ├── Frontend cluster (web, mobile APIs)
  ├── Backend cluster (microservices)
  └── Data cluster (batch jobs, ML)
      Cost: $219/month + nodes
```

## Migration Guide

### From Self-Managed Kubernetes

```bash
# Step 1: Create EKS cluster
terraform apply -target=module.eks_cluster

# Step 2: Create node groups
terraform apply -target=module.eks_nodegroups

# Step 3: Migrate workloads
# Option A: Blue-green deployment
kubectl apply -f workloads/ --context=eks-cluster

# Option B: Use Velero for migration
velero backup create old-cluster-backup --include-namespaces=production
velero restore create --from-backup old-cluster-backup --context=eks-cluster

# Step 4: Update DNS/ingress
# Point traffic to new cluster

# Step 5: Decommission old cluster
```

### Upgrading Kubernetes Versions

```bash
# Step 1: Update dev/QE first
# terraform.tfvars (default workspace)
cluster_version = "1.34"  # Was 1.33

terraform workspace select default
terraform plan
terraform apply

# Step 2: Update node groups
# See nodegroup module documentation

# Step 3: Test thoroughly in QE

# Step 4: Update production
terraform workspace select prod
terraform apply

# Monitor for issues
kubectl get nodes
kubectl get pods --all-namespaces
```

## FAQ

### Q: How many clusters should I have?

**A:** It depends on your needs:
- **Small team:** 1 cluster per environment (dev, qe, prod) = 3 clusters
- **Medium team:** 2-3 clusters in prod (tier separation) = 5-7 clusters
- **Large team:** Many clusters (team/app isolation) = 10+ clusters

**Rule of thumb:** Start with fewer clusters, split as needed.

### Q: Public or private API endpoint?

**A:**
- **Dev/QE:** Public + Private (convenience)
- **Production:** Private only (security)
- **Exception:** Public + Private with CIDR restrictions

### Q: Can I change endpoint access after creation?

**A:** Yes, via AWS console or CLI:
```bash
aws eks update-cluster-config \
  --name cluster-name \
  --resources-vpc-config \
    endpointPublicAccess=false,\
    endpointPrivateAccess=true
```

### Q: How do I access a private-only cluster?

**A:** Three options:
1. **VPN:** Connect to VPN, use kubectl normally
2. **Bastion:** SSH to bastion in VPC, use kubectl from there
3. **SSH Tunnel:** Forward API endpoint through bastion

### Q: Can I have multiple clusters in same VPC?

**A:** Yes, common pattern:
```hcl
eks_clusters = {
  default = {
    frontend = { vpc_name = "shared_vpc", ... }
    backend  = { vpc_name = "shared_vpc", ... }
  }
}
```

### Q: What's the difference between cluster SG and node SG?

**A:**
- **Cluster SG:** Controls traffic to EKS control plane
- **Node SG:** Controls traffic to worker nodes
- Both are required and must allow specific traffic between them

### Q: How long does cluster creation take?

**A:** Typically 10-15 minutes for control plane. Add 3-5 minutes for node groups.

### Q: Can I rename a cluster?

**A:** No. Must create new cluster and migrate workloads.

### Q: What happens during version upgrade?

**A:**
- Control plane upgraded first (5-10 minutes)
- May experience brief API unavailability
- Workloads continue running
- Node groups must be upgraded separately

### Q: Do I need one cluster per microservice?

**A:** No! Use Kubernetes namespaces for isolation. Reserve separate clusters for:
- Different environments (dev/prod)
- Different SLAs/compliance requirements
- Team/organizational boundaries

## Testing Checklist

After cluster creation:

```bash
# ✅ Cluster is ACTIVE
aws eks describe-cluster --name cluster-name --query 'cluster.status'

# ✅ kubectl access works
kubectl cluster-info

# ✅ CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# ✅ API endpoint accessible
curl -k https://$(terraform output -json eks_cluster_endpoints | jq -r '.cluster_name')

# ✅ IAM role correct
aws eks describe-cluster --name cluster-name \
  --query 'cluster.roleArn'

# ✅ Subnets correct
aws eks describe-cluster --name cluster-name \
  --query 'cluster.resourcesVpcConfig.subnetIds'

# ✅ Security groups correct
aws eks describe-cluster --name cluster-name \
  --query 'cluster.resourcesVpcConfig.securityGroupIds'

# ✅ Logging enabled (if desired)
aws eks describe-cluster --name cluster-name \
  --query 'cluster.logging'
```

## Change Log

### Version 1.0 (2025-01-15)
- Initial release
- Support for Kubernetes 1.34
- Multi-cluster per workspace
- Public/private endpoint configuration
- Automatic IAM role creation
- Integration with VPC, subnet, and security group modules

## Contributing

When contributing to this module:

1. ✅ Test with multiple Kubernetes versions
2. ✅ Validate public and private endpoint access
3. ✅ Test multi-cluster configurations
4. ✅ Document version compatibility
5. ✅ Update troubleshooting section
6. ✅ Test cluster upgrades

## Module Metadata

- **Author:** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Container Orchestration
- **Complexity:** High (IAM, networking, Kubernetes integration)
- **Dependencies:** VPC, Subnet, Security Group modules

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]
- [FAQ](#FAQ)


## Summary

The EKS Cluster module provides comprehensive, workspace-aware EKS cluster management with:

- ✅ Multi-environment support via Terraform workspaces
- ✅ Multiple clusters per workspace (frontend, backend, data)
- ✅ Automatic IAM role and policy management
- ✅ Flexible endpoint access control (public/private)
- ✅ Integration with VPC, subnet, and security group modules
- ✅ Support for latest Kubernetes versions
- ✅ Comprehensive tagging and lifecycle management

**Most Common Use Case:** Create production-grade EKS clusters with private API endpoints across multiple availability zones.

**Remember:**
- Control plane costs $73/month per cluster
- Private-only endpoints require VPN/bastion access
- Always upgrade one Kubernetes version at a time
- Test in dev/QE before upgrading production

## Additional Resources

- **AWS EKS Documentation:** https://docs.aws.amazon.com/eks/
- **Terraform aws_eks_cluster:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
- **Kubernetes Version Policy:** https://kubernetes.io/releases/
- **EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/
- **eksctl (CLI tool):** https://eksctl.io/

[SlackLink]: https://theoperationhq.slack.com/
[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues