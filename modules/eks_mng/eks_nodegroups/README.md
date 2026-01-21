# EKS Node Group Module

## Overview

This module creates and manages AWS EKS Node Groups (managed worker nodes) that run your Kubernetes workloads. Node groups are collections of EC2 instances that automatically join your EKS cluster and handle pod scheduling, container runtime, and workload execution.

## Module Purpose

- Creates managed node groups for EKS clusters
- Manages IAM roles and policies for worker nodes
- Configures launch templates with custom security groups
- Supports both x86_64 and ARM64 architectures
- Enables custom IAM policies per node group
- Provides auto-scaling capabilities
- Handles AMI selection automatically (or manual override)

## Module Location

```
modules/eks_mng/eks_nodegroups/
├── main.tf          # Node group resources, IAM, launch templates
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output definitions
└── README.md        # This file
```

## Technical Implementation

### Resources Created

This module creates **7+ types of resources** per node group:

1. **IAM Role** - `aws_iam_role.node` (per node group)
2. **IAM Policy Attachments** - Standard policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`
3. **Custom IAM Policies** - `aws_iam_policy.custom` (optional)
4. **Custom Policy Attachments** - `aws_iam_role_policy_attachment.custom` (optional)
5. **Launch Template** - `aws_launch_template.ng_lt` (per node group)
6. **EKS Node Group** - `aws_eks_node_group.nodegroup` (per node group)
7. **SSM Parameter Lookup** - `data.aws_ssm_parameter.eks_ami` (for automatic AMI selection)

### Node Group Definition

```hcl
resource "aws_eks_node_group" "nodegroup" {
  for_each = var.nodegroup_parameters

  cluster_name    = var.cluster_name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node[each.key].arn
  subnet_ids      = each.value.subnet_ids

  ami_type = (
    each.value.arch == "arm64" ? "AL2023_ARM_64_STANDARD" : "AL2023_x86_64_STANDARD"
  )

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  tags = merge(each.value.tags, {
    Name : each.key
  })

  launch_template {
    id      = aws_launch_template.ng_lt[each.key].id
    version = "$Latest"
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }

  depends_on = [
    aws_iam_role.node,
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_read,
    aws_iam_role_policy_attachment.custom,
    aws_launch_template.ng_lt
  ]
}
```

### Launch Template Definition

```hcl
resource "aws_launch_template" "ng_lt" {
  for_each = var.nodegroup_parameters

  name_prefix            = "${each.key}-lt"
  image_id               = each.value.instance_ami
  instance_type          = each.value.instance_types
  vpc_security_group_ids = each.value.node_security_group_ids

  tag_specifications {
    resource_type = "instance"
    tags = merge(each.value.tags, {
      Name = "${each.key}-node"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(each.value.tags, {
      Name = "${each.key}-volume"
    })
  }
}
```

### IAM Role Definition

```hcl
resource "aws_iam_role" "node" {
  for_each           = var.nodegroup_parameters
  name               = "${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
```

### Standard Policy Attachments

```hcl
# Required for EKS worker node operations
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  for_each   = var.nodegroup_parameters
  role       = aws_iam_role.node[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Required for VPC CNI plugin
resource "aws_iam_role_policy_attachment" "eks_cni" {
  for_each   = var.nodegroup_parameters
  role       = aws_iam_role.node[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Required for pulling container images from ECR
resource "aws_iam_role_policy_attachment" "ecr_read" {
  for_each   = var.nodegroup_parameters
  role       = aws_iam_role.node[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```

## Inputs

### `cluster_name`

**Type:** `string`  
**Required:** Yes  
**Default:** N/A

The name of the EKS cluster to which node groups will be attached.

**Example:**
```hcl
cluster_name = "a"  # From module.eks_cluster["a"].eks_clusters["a"].cluster_name
```

### `nodegroup_parameters`

**Type:** `map(object)`  
**Required:** Yes  
**Default:** N/A

Map of node group configurations.

#### Object Structure

```hcl
{
  min_size                = number              # REQUIRED
  max_size                = number              # REQUIRED
  desired_size            = number              # REQUIRED
  arch                    = string              # REQUIRED
  instance_types          = string              # REQUIRED
  instance_ami            = string              # REQUIRED (auto-filled by root)
  subnet_ids              = list(string)        # REQUIRED (auto-filled by root)
  node_security_group_ids = list(string)        # REQUIRED (auto-filled by root)
  tags                    = map(string)         # REQUIRED
}
```

#### Parameter Details

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `min_size` | number | ✅ Yes | - | Minimum number of nodes (ASG minimum) |
| `max_size` | number | ✅ Yes | - | Maximum number of nodes (ASG maximum) |
| `desired_size` | number | ✅ Yes | - | Desired number of nodes (initial count) |
| `arch` | string | ✅ Yes | - | CPU architecture: `"arm64"` or `"x86_64"` |
| `instance_types` | string | ✅ Yes | - | EC2 instance type (e.g., `"t4g.small"`, `"t3.medium"`) |
| `instance_ami` | string | ✅ Yes | `""` | AMI ID (auto-selected if empty) |
| `subnet_ids` | list(string) | ✅ Yes | - | Subnet IDs where nodes will be deployed |
| `node_security_group_ids` | list(string) | ✅ Yes | - | Security group IDs for worker nodes |
| `tags` | map(string) | ✅ Yes | - | Tags to apply to nodes and volumes |

#### Scaling Configuration

**Scaling behavior:**
- `min_size`: ASG will never scale below this number
- `max_size`: ASG will never scale above this number (cluster autoscaler respects this)
- `desired_size`: Initial node count (ASG target)

**Examples:**

```hcl
# Development (cost-optimized)
min_size     = 1
max_size     = 3
desired_size = 1

# Production (high availability)
min_size     = 3  # One per AZ
max_size     = 10
desired_size = 3

# Burst workloads (autoscaling)
min_size     = 2
max_size     = 20
desired_size = 2
```

#### Architecture Options

| Architecture | Value | Instance Families | Use Case | Cost |
|--------------|-------|-------------------|----------|------|
| ARM (Graviton) | `"arm64"` | t4g, m6g, c6g, r6g | Cost-effective, general purpose | 💰 Lower |
| x86_64 (Intel/AMD) | `"x86_64"` | t3, m5, c5, r5 | Legacy apps, specific requirements | 💰 Higher |

**Recommended:** Use `"arm64"` (Graviton) for 20-40% cost savings with comparable/better performance.

#### Instance Type Selection

**Common instance types:**

| Type | vCPU | Memory | Use Case | Hourly Cost (approx) |
|------|------|--------|----------|---------------------|
| `t4g.small` | 2 | 2 GB | Dev/test, small workloads | $0.0168 |
| `t4g.medium` | 2 | 4 GB | General purpose | $0.0336 |
| `t4g.large` | 2 | 8 GB | Medium workloads | $0.0672 |
| `m6g.large` | 2 | 8 GB | Balanced compute/memory | $0.077 |
| `c6g.large` | 2 | 4 GB | Compute-intensive | $0.068 |
| `r6g.large` | 2 | 16 GB | Memory-intensive | $0.1008 |

**x86_64 equivalents (higher cost):**

| Type | vCPU | Memory | Hourly Cost (approx) |
|------|------|--------|---------------------|
| `t3.small` | 2 | 2 GB | $0.0208 |
| `t3.medium` | 2 | 4 GB | $0.0416 |
| `t3.large` | 2 | 8 GB | $0.0832 |
| `m5.large` | 2 | 8 GB | $0.096 |

**Sizing guidelines:**
- **Small apps/dev:** `t4g.small` or `t4g.medium`
- **Production web apps:** `t4g.large` or `m6g.large`
- **Compute-heavy:** `c6g.large`, `c6g.xlarge`
- **Memory-heavy:** `r6g.large`, `r6g.xlarge`

#### AMI Selection

The module **automatically selects** the latest EKS-optimized AMI for your Kubernetes version and architecture:

```hcl
data "aws_ssm_parameter" "eks_ami" {
  for_each = {
    for k, ng in local.flat_nodegroups_map :
    k => ng
    if ng.instance_ami == ""
  }

  name = "/aws/service/eks/optimized-ami/${each.value.k8s_version}/amazon-linux-2023/${each.value.arch}/standard/recommended/image_id"
}
```

**AMI naming pattern:**
- AL2023 ARM: `AL2023_ARM_64_STANDARD`
- AL2023 x86: `AL2023_x86_64_STANDARD`

**Manual override (advanced):**
```hcl
eks_nodegroups = {
  default = {
    a = {
      a1 = {
        instance_ami = "ami-0abcdef1234567890"  # Custom AMI
        # ... other params
      }
    }
  }
}
```

⚠️ **Warning:** Manual AMI selection requires you to manage AMI updates yourself.

### `additional_policies`

**Type:** `map(object)`  
**Required:** No  
**Default:** `{}`

Custom IAM policies to attach to specific node groups.

#### Object Structure

```hcl
{
  <policy_name> = {
    nodegroups = list(string)  # List of node group names
    policy     = list(string)  # List of IAM policy JSON strings
  }
}
```

#### Validation Rules

1. ✅ All node groups in `additional_policies.<policy>.nodegroups` **must exist** in `nodegroup_parameters`
2. ✅ `policy` list must **not be empty** (at least one JSON policy)
3. ✅ `nodegroups` list must **not be empty** (at least one node group)

#### Example Usage

```hcl
additional_policies = {
  s3_access = {
    nodegroups = ["a1", "a2"]
    policy = [
      jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:ListBucket"
            ]
            Resource = [
              "arn:aws:s3:::my-app-bucket",
              "arn:aws:s3:::my-app-bucket/*"
            ]
          }
        ]
      })
    ]
  }

  cloudwatch_logs = {
    nodegroups = ["b1"]
    policy = [
      jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Resource = "arn:aws:logs:*:*:*"
          }
        ]
      })
    ]
  }
}
```

**Common use cases:**
- S3 access for application data
- CloudWatch Logs for custom logging
- Secrets Manager access
- DynamoDB access
- SQS/SNS permissions
- Custom application-specific permissions

## Outputs

### `nodegroups`

**Type:** `map(object)`  
**Description:** Comprehensive information about all created node groups

#### Output Structure

```hcl
{
  "<nodegroup_key>" = {
    node_group_name = string       # Node group name
    arn             = string       # Node group ARN
    node_role_name  = string       # IAM role name
    node_role_arn   = string       # IAM role ARN
    instance_types  = list(string) # Instance types
    status          = string       # Node group status
    labels          = map(string)  # Kubernetes labels
    tags            = map(string)  # AWS tags
    scaling = {
      min     = number             # Min size
      max     = number             # Max size
      desired = number             # Desired size
    }
  }
}
```

#### Example Output

```hcl
nodegroups = {
  "a1" = {
    node_group_name = "a1"
    arn             = "arn:aws:eks:ap-south-1:123456789012:nodegroup/a/a1/abc-123"
    node_role_name  = "a1-role"
    node_role_arn   = "arn:aws:iam::123456789012:role/a1-role"
    instance_types  = ["t4g.small"]
    status          = "ACTIVE"
    labels          = {}
    tags = {
      Team = "a"
      Name = "a1"
    }
    scaling = {
      min     = 1
      max     = 2
      desired = 1
    }
  }
}
```

## Usage in Root Module

### Called From

`07_eks.tf` in the root module

### Module Call

```hcl
module "eks_nodegroups" {
  for_each = local.generated_nodegroup_config

  source = "./modules/eks_mng/eks_nodegroups"

  cluster_name = module.eks_cluster[each.key].eks_clusters[each.key].cluster_name

  nodegroup_parameters = each.value

  depends_on = [
    module.eks_cluster,
    module.chat_app_security_group,
    module.chat_app_security_rules,
    module.chat_app_subnet
  ]
}
```

### Dynamic Parameter Generation

**In `07_eks.tf` (root):**

```hcl
locals {
  # Get workspace-specific nodegroup config
  ws_nodegroup_config = lookup(var.eks_nodegroups, terraform.workspace, {})

  # Flatten all nodegroups across clusters
  flat_nodegroups = flatten([
    for cluster_name, ngroups in local.ws_nodegroup_config : [
      for ng_name, ng in ngroups : {
        key          = "${cluster_name}/${ng_name}"
        cluster_name = cluster_name
        ng_name      = ng_name
        config       = ng
      }
    ]
  ])

  flat_nodegroups_map = {
    for ng in local.flat_nodegroups :
    ng.key => ng.config
  }
}

# Fetch AMI if not present
data "aws_ssm_parameter" "eks_ami" {
  for_each = {
    for k, ng in local.flat_nodegroups_map :
    k => ng
    if ng.instance_ami == ""
  }

  name = "/aws/service/eks/optimized-ami/${each.value.k8s_version}/amazon-linux-2023/${each.value.arch}/standard/recommended/image_id"
}

locals {
  generated_nodegroup_config = {
    for cluster_name, ngroups in local.ws_nodegroup_config :
    cluster_name => {
      for ng_name, ng in ngroups :
      ng_name => merge(
        ng,
        {
          arch = ng.arch
          # subnet name to subnet id
          subnet_ids = [
            for sn in ng.subnet_name :
            local.subnet_id_by_name[sn]
          ]
          # sg name to sg id
          node_security_group_ids = [
            for node_security_group_names in ng.node_security_group_names :
            local.sgs_id_by_name[node_security_group_names]
          ]
          # AMI
          instance_ami = (
            try(ng.instance_ami, "") != ""
            ? ng.instance_ami
            : data.aws_ssm_parameter.eks_ami["${cluster_name}/${ng_name}"].value
          )
        }
      )
    }
  }
}
```

### Variable Structure in Root

**In `variables.tf` (root):**

```hcl
variable "eks_nodegroups" {
  description = "Map of nodegroup configs per environment"
  type = map(map(map(object({
    k8s_version               = optional(string)
    arch                      = optional(string)
    min_size                  = number
    max_size                  = number
    desired_size              = number
    instance_types            = string
    instance_ami              = optional(string)
    subnet_name               = optional(list(string))
    subnet_ids                = optional(list(string))
    node_security_group_names = list(string)
    tags                      = map(string)
  }))))
  default = {}
}
```

### Example Configuration in terraform.tfvars

```hcl
eks_nodegroups = {
  default = {      # Workspace
    a = {          # Cluster name
      a1 = {       # Node group name
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 2
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
        node_security_group_names = ["chat_app_dev_node_sg"]
        tags                      = { Team = "a" }
      }
      a2 = {
        min_size                  = 1
        max_size                  = 2
        desired_size              = 1
        instance_types            = "t3.small"
        subnet_name               = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
        node_security_group_names = ["chat_app_dev_node_sg"]
        tags                      = { Team = "a" }
      }
    }

    b = {          # Another cluster
      b1 = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 2
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["cad_vpc1_pri_sub1", "cad_vpc1_pri_sub2"]
        node_security_group_names = ["chat_app_dev_node_sg"]
        tags                      = { Team = "b" }
      }
    }
  }
}
```

## Configuration Examples

### Example 1: Basic Development Node Group

```hcl
eks_nodegroups = {
  default = {
    dev_cluster = {
      general = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 3
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["private_subnet_1", "private_subnet_2"]
        node_security_group_names = ["eks_node_sg"]
        tags = {
          Environment = "dev"
          Purpose     = "general-workloads"
        }
      }
    }
  }
}
```

**Characteristics:**
- ✅ ARM architecture (cost-effective)
- ✅ Small instance type for dev
- ✅ Scales 1-3 nodes
- 💰 Monthly cost: ~$12 (1 node) to ~$36 (3 nodes)

### Example 2: Production High-Availability Setup

```hcl
eks_nodegroups = {
  prod = {
    prod_main = {
      # General purpose nodes
      general = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 3  # One per AZ
        max_size                  = 10
        desired_size              = 3
        instance_types            = "t4g.large"
        subnet_name               = ["private_az1", "private_az2", "private_az3"]
        node_security_group_names = ["prod_node_sg"]
        tags = {
          Environment = "prod"
          Purpose     = "general"
        }
      }

      # Memory-optimized for caching
      cache = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 2
        max_size                  = 5
        desired_size              = 2
        instance_types            = "r6g.large"
        subnet_name               = ["private_az1", "private_az2", "private_az3"]
        node_security_group_names = ["prod_node_sg"]
        tags = {
          Environment = "prod"
          Purpose     = "cache"
          Workload    = "redis"
        }
      }
    }
  }
}
```

**Characteristics:**
- ✅ Multi-AZ deployment (3 AZs)
- ✅ Separate node groups by workload
- ✅ High availability (min 3 nodes)
- 💰 Monthly cost: ~$390 (5 nodes total)

### Example 3: Mixed Architecture (ARM + x86)

```hcl
eks_nodegroups = {
  default = {
    mixed_cluster = {
      # ARM nodes for general workloads
      arm_general = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 2
        max_size                  = 5
        desired_size              = 2
        instance_types            = "t4g.medium"
        subnet_name               = ["private_sub1", "private_sub2"]
        node_security_group_names = ["node_sg"]
        tags = {
          Architecture = "arm64"
          Purpose      = "general"
        }
      }

      # x86 nodes for legacy apps
      x86_legacy = {
        k8s_version               = "1.34"
        arch                      = "x86_64"
        min_size                  = 1
        max_size                  = 3
        desired_size              = 1
        instance_types            = "t3.medium"
        subnet_name               = ["private_sub1", "private_sub2"]
        node_security_group_names = ["node_sg"]
        tags = {
          Architecture = "x86_64"
          Purpose      = "legacy-apps"
        }
      }
    }
  }
}
```

**Use case:** Gradual migration from x86 to ARM while maintaining legacy compatibility.

### Example 4: Auto-Scaling with Spot Instances (Advanced)

```hcl
eks_nodegroups = {
  default = {
    spot_cluster = {
      # On-demand baseline
      on_demand = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 2
        max_size                  = 2
        desired_size              = 2
        instance_types            = "t4g.medium"
        subnet_name               = ["private_sub1", "private_sub2"]
        node_security_group_names = ["node_sg"]
        tags = {
          CapacityType = "ON_DEMAND"
          Purpose      = "baseline"
        }
      }

      # Spot instances for burst capacity
      spot = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 0
        max_size                  = 10
        desired_size              = 0
        instance_types            = "t4g.medium"
        subnet_name               = ["private_sub1", "private_sub2"]
        node_security_group_names = ["node_sg"]
        tags = {
          CapacityType = "SPOT"
          Purpose      = "burst"
        }
      }
    }
  }
}
```

**Note:** This framework doesn't natively support Spot instances, but you can configure them via AWS Console or CLI after creation.

### Example 5: Multi-Cluster Multi-Environment

```hcl
eks_nodegroups = {
  # Development
  default = {
    dev_frontend = {
      web = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 3
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["dev_private_1", "dev_private_2"]
        node_security_group_names = ["dev_node_sg"]
        tags                      = { Team = "frontend" }
      }
    }

    dev_backend = {
      api = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 1
        max_size                  = 3
        desired_size              = 1
        instance_types            = "t4g.small"
        subnet_name               = ["dev_private_1", "dev_private_2"]
        node_security_group_names = ["dev_node_sg"]
        tags                      = { Team = "backend" }
      }
    }
  }

  # Production
  prod = {
    prod_frontend = {
      web = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 3
        max_size                  = 10
        desired_size              = 3
        instance_types            = "t4g.large"
        subnet_name               = ["prod_private_1", "prod_private_2", "prod_private_3"]
        node_security_group_names = ["prod_node_sg"]
        tags                      = { Team = "frontend" }
      }
    }

    prod_backend = {
      api = {
        k8s_version               = "1.34"
        arch                      = "arm64"
        min_size                  = 3
        max_size                  = 10
        desired_size              = 3
        instance_types            = "t4g.large"
        subnet_name               = ["prod_private_1", "prod_private_2", "prod_private_3"]
        node_security_group_names = ["prod_node_sg"]
        tags                      = { Team = "backend" }
      }
    }
  }
}
```

## Node Group Architecture Patterns

### Pattern 1: Single Node Group (Simple)

```
┌─────────────────────────────────────┐
│         EKS Cluster                 │
│                                     │
│  ┌───────────────────────────────┐  │
│  │   General Node Group          │  │
│  │   - All workloads             │  │
│  │   - Min: 2, Max: 10           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Pros:** Simple, easy to manage  
**Cons:** No workload isolation

### Pattern 2: Multiple Node Groups by Workload

```
┌─────────────────────────────────────┐
│         EKS Cluster                 │
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │   Web    │  │   API    │        │
│  │  Nodes   │  │  Nodes   │        │
│  └──────────┘  └──────────┘        │
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │  Cache   │  │  Batch   │        │
│  │  Nodes   │  │  Nodes   │        │
│  └──────────┘  └──────────┘        │
└─────────────────────────────────────┘
```

**Pros:** Workload isolation, optimized instance types  
**Cons:** More complexity

### Pattern 3: Mixed Architecture

```
┌─────────────────────────────────────┐
│         EKS Cluster                 │
│                                     │
│  ┌──────────────────────────────┐   │
│  │   ARM Nodes (General)        │   │
│  │   t4g.medium (cost-effective)│   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌──────────────────────────────┐   │
│  │   x86 Nodes (Legacy Apps)    │   │
│  │   t3.medium                  │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Use case:** Gradual migration to ARM while supporting legacy workloads

---

## Security Group Requirements

### Node Security Group Rules

The node security group must allow specific traffic between nodes and the cluster control plane.

**Required Ingress Rules:**

```hcl
# From cluster control plane
ipv4_ingress_rule = {
  default = {
    # Kubelet API
    node_kubelet = {
      vpc_name                   = "my_vpc"
      sg_name                    = "node_sg"
      from_port                  = 10250
      to_port                    = 10250
      protocol                   = "TCP"
      source_security_group_name = "cluster_sg"
    }

    # HTTPS (for webhooks, extensions)
    node_https = {
      vpc_name                   = "my_vpc"
      sg_name                    = "node_sg"
      from_port                  = 443
      to_port                    = 443
      protocol                   = "TCP"
      source_security_group_name = "cluster_sg"
    }

    # NodePort services
    node_nodeport = {
      vpc_name                   = "my_vpc"
      sg_name                    = "node_sg"
      from_port                  = 30000
      to_port                    = 32767
      protocol                   = "TCP"
      source_security_group_name = "cluster_sg"
    }

    # Node-to-node communication (pods)
    node_self = {
      vpc_name                   = "my_vpc"
      sg_name                    = "node_sg"
      protocol                   = -1  # All protocols
      source_security_group_name = "node_sg"
    }
  }
}
```

**Required Egress Rules:**

```hcl
ipv4_egress_rule = {
  default = {
    # Allow all outbound (for pulling images, AWS APIs, etc.)
    node_egress = {
      vpc_name  = "my_vpc"
      sg_name   = "node_sg"
      protocol  = -1
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

### Traffic Flow

```
Control Plane ──────────────> Worker Nodes
                443, 10250

Worker Nodes ───────────────> Control Plane
                443

Worker Nodes <──────────────> Worker Nodes
             All traffic (pod-to-pod)

Worker Nodes ───────────────> Internet/AWS APIs
               NAT Gateway or VPC Endpoints
```

---

## IAM Roles and Policies

### Standard Policies (Always Attached)

#### 1. AmazonEKSWorkerNodePolicy

**Purpose:** Core EKS worker node permissions

**Permissions:**
- Register with EKS cluster
- Describe cluster resources
- Call EKS APIs

#### 2. AmazonEKS_CNI_Policy

**Purpose:** VPC networking (CNI plugin)

**Permissions:**
- Create/delete ENIs
- Assign IP addresses
- Manage security groups
- Describe VPC resources

#### 3. AmazonEC2ContainerRegistryReadOnly

**Purpose:** Pull container images from ECR

**Permissions:**
- Get authorization token
- Batch get images
- Get download URL
- List images/repositories

### Custom Policies

Use `additional_policies` for application-specific permissions:

```hcl
additional_policies = {
  # S3 access for data processing
  s3_access = {
    nodegroups = ["data_processing"]
    policy = [
      jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:ListBucket"
            ]
            Resource = [
              "arn:aws:s3:::my-data-bucket",
              "arn:aws:s3:::my-data-bucket/*"
            ]
          }
        ]
      })
    ]
  }

  # DynamoDB access for session storage
  dynamodb_access = {
    nodegroups = ["web", "api"]
    policy = [
      jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "dynamodb:GetItem",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem",
              "dynamodb:Query"
            ]
            Resource = "arn:aws:dynamodb:ap-south-1:*:table/sessions"
          }
        ]
      })
    ]
  }

  # Secrets Manager for application secrets
  secrets_access = {
    nodegroups = ["api", "batch"]
    policy = [
      jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret"
            ]
            Resource = "arn:aws:secretsmanager:ap-south-1:*:secret:app/*"
          }
        ]
      })
    ]
  }
}
```

### IRSA (IAM Roles for Service Accounts) - Recommended Alternative

**Better approach:** Use IRSA instead of node-level IAM policies for pod-specific permissions.

```bash
# Create service account with IAM role
eksctl create iamserviceaccount \
  --cluster=my-cluster \
  --namespace=default \
  --name=my-app-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve
```

**Benefits:**
- ✅ Pod-level permissions (not all pods on node)
- ✅ Least-privilege security
- ✅ Easier to audit
- ✅ No credential management

---

## Lifecycle Management

### Scaling Operations

#### Manual Scaling

```hcl
# Update terraform.tfvars
eks_nodegroups = {
  default = {
    my_cluster = {
      my_nodegroup = {
        min_size     = 2  # Was 1
        max_size     = 5  # Was 3
        desired_size = 3  # Was 1
        # ... other params
      }
    }
  }
}
```

```bash
terraform plan
terraform apply
```

#### Auto-Scaling (Cluster Autoscaler)

**Install Cluster Autoscaler:**

```bash
# Deploy cluster autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Annotate deployment with cluster name
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler \
  cluster-autoscaler.kubernetes.io/safe-to-evict="false"

# Edit and set cluster name
kubectl -n kube-system edit deployment cluster-autoscaler
# Add: --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<CLUSTER_NAME>
```

**How it works:**
1. Pods become unschedulable (insufficient resources)
2. Cluster Autoscaler adds nodes (within `min_size` to `max_size`)
3. When nodes are underutilized, scales down (respects `min_size`)

**Best practices:**
- Set realistic `min_size` (for baseline capacity)
- Set `max_size` based on budget/requirements
- Use pod disruption budgets (PDBs)
- Configure node labels/taints for workload placement

### Node Group Updates

#### Instance Type Change

```hcl
# Before
instance_types = "t4g.small"

# After
instance_types = "t4g.medium"
```

**Process:**
1. Terraform creates new launch template
2. New nodes are created with new instance type
3. Old nodes are drained and terminated
4. Workloads are rescheduled to new nodes

**Downtime:** None if `desired_size > 1` (rolling update)

#### AMI Updates

**Automatic (recommended):**
- Leave `instance_ami = ""` in tfvars
- Module auto-selects latest EKS-optimized AMI
- Update by running `terraform apply` periodically

**Manual:**
```hcl
instance_ami = "ami-0abcdef1234567890"  # Specify new AMI
```

```bash
terraform apply
```

**Process:**
1. New launch template with new AMI
2. Rolling node replacement (old nodes drained)
3. Pods rescheduled to new nodes

**Best practices:**
- ✅ Test AMI updates in dev/QE first
- ✅ Use automatic AMI selection
- ✅ Update during maintenance windows
- ✅ Monitor pod disruptions during update

### Kubernetes Version Upgrades

**Important:** Node group Kubernetes version must match or be one minor version behind cluster version.

**Valid combinations:**
- Cluster `1.34` + Nodes `1.34` ✅
- Cluster `1.34` + Nodes `1.33` ✅
- Cluster `1.34` + Nodes `1.32` ❌ (too old)
- Cluster `1.33` + Nodes `1.34` ❌ (nodes ahead)

**Upgrade process:**

```bash
# Step 1: Upgrade cluster first
# In terraform.tfvars (cluster config)
cluster_version = "1.34"  # Was 1.33

terraform apply -target=module.eks_cluster

# Step 2: Upgrade node groups
# In terraform.tfvars (nodegroup config)
k8s_version = "1.34"  # Was 1.33

terraform apply -target=module.eks_nodegroups
```

**Timeline:**
- Cluster upgrade: 10-15 minutes
- Node group upgrade: 5-10 minutes per node (rolling)

### Node Group Deletion

```bash
# Delete specific node group
terraform destroy -target=module.eks_nodegroups[\"cluster_name\"].aws_eks_node_group.nodegroup[\"nodegroup_name\"]

# Or remove from terraform.tfvars and apply
terraform apply
```

**Process:**
1. Nodes are cordoned (no new pods)
2. Pods are drained (evicted gracefully)
3. Nodes are terminated
4. Node group is deleted

**⚠️ Warning:** Ensure workloads can be rescheduled to other nodes or use pod disruption budgets.

---

## Scaling Strategies

### Strategy 1: Static Sizing (Predictable Workloads)

```hcl
min_size     = 3
max_size     = 3
desired_size = 3
```

**Use case:** Production workloads with consistent traffic

**Pros:**
- ✅ Predictable costs
- ✅ No scaling delays
- ✅ Simple capacity planning

**Cons:**
- ❌ Over-provisioning during low traffic
- ❌ No burst capacity

### Strategy 2: Auto-Scaling (Variable Workloads)

```hcl
min_size     = 2
max_size     = 10
desired_size = 2
```

**Use case:** Applications with variable traffic patterns

**Pros:**
- ✅ Cost-efficient (scale down during low traffic)
- ✅ Handles traffic spikes
- ✅ Automatic capacity management

**Cons:**
- ❌ Scaling delays (2-5 minutes)
- ❌ Requires cluster autoscaler
- ❌ More complex monitoring

### Strategy 3: Burst Capacity (On-Demand + Spot)

```hcl
# On-demand baseline
on_demand = {
  min_size     = 3
  max_size     = 3
  desired_size = 3
}

# Spot for burst
spot = {
  min_size     = 0
  max_size     = 10
  desired_size = 0
}
```

**Use case:** Cost-sensitive with bursty workloads

**Pros:**
- ✅ Lowest cost (Spot ~70% cheaper)
- ✅ Baseline capacity guaranteed
- ✅ Handles extreme spikes

**Cons:**
- ❌ Spot interruptions possible
- ❌ Requires fault-tolerant apps
- ❌ Complex configuration

### Strategy 4: Time-Based Scaling (Scheduled Traffic)

```hcl
# Business hours
min_size     = 5
max_size     = 10
desired_size = 5

# Off-hours (use Kubernetes CronJob to scale)
# Scale down to min_size = 2
```

**Use case:** Applications with predictable daily patterns

**Pros:**
- ✅ Cost savings during off-hours
- ✅ Capacity ready for peak hours
- ✅ Predictable

**Cons:**
- ❌ Requires scheduling automation
- ❌ Manual adjustment for holidays/events

---

## Cost Optimization

### Cost Breakdown

**Monthly costs (24/7 operation):**

| Instance Type | Hourly | Monthly (1 node) | Monthly (3 nodes) |
|---------------|--------|------------------|-------------------|
| t4g.small | $0.0168 | ~$12 | ~$36 |
| t4g.medium | $0.0336 | ~$24 | ~$72 |
| t4g.large | $0.0672 | ~$49 | ~$147 |
| t3.small | $0.0208 | ~$15 | ~$45 |
| t3.medium | $0.0416 | ~$30 | ~$90 |
| t3.large | $0.0832 | ~$60 | ~$180 |
| m6g.large | $0.077 | ~$56 | ~$168 |
| r6g.large | $0.1008 | ~$73 | ~$219 |

### Optimization Tips

#### 1. Use ARM (Graviton) Instances

```hcl
# Before (x86)
instance_types = "t3.medium"  # $30/month
arch           = "x86_64"

# After (ARM)
instance_types = "t4g.medium"  # $24/month
arch           = "arm64"

# Savings: 20% (~$6/month per node)
```

**Compatible apps:** Most modern applications (Java, Python, Node.js, Go, Rust)

**Incompatible:** Legacy apps with x86-specific binaries

#### 2. Right-Size Instances

```bash
# Check actual resource usage
kubectl top nodes

# Identify over-provisioned nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Example:**
```
# If t4g.large shows:
# CPU: 20% average usage
# Memory: 30% average usage
# 
# Consider: t4g.medium (50% cost reduction)
```

#### 3. Enable Auto-Scaling

```hcl
# Before (static)
min_size     = 5
max_size     = 5
desired_size = 5
# Cost: 5 nodes × 24/7 = 120 node-hours/day

# After (auto-scaling)
min_size     = 2
max_size     = 5
desired_size = 2
# Cost: ~3 nodes average × 24/7 = 72 node-hours/day
# Savings: 40%
```

#### 4. Use Spot Instances (Advanced)

**Potential savings:** 60-70% off on-demand pricing

**Limitations:**
- Can be interrupted with 2-minute notice
- Not suitable for stateful/critical workloads
- Requires fault-tolerant application design

#### 5. Consolidate Node Groups

```hcl
# Before (separate node groups)
web = { desired_size = 2, instance_types = "t4g.medium" }    # $48/month
api = { desired_size = 2, instance_types = "t4g.medium" }    # $48/month
cache = { desired_size = 1, instance_types = "t4g.medium" }  # $24/month
# Total: $120/month

# After (consolidated with node selectors)
general = { desired_size = 3, instance_types = "t4g.large" } # $147/month
# Savings: ~$0/month but better resource utilization
```

**Use node selectors/taints to separate workloads on shared nodes.**

#### 6. Schedule Dev/Test Clusters

```bash
# Stop dev cluster at night (saves 67% for off-hours)
# Scale to min_size = 0 (if not in use)
# Or terminate and recreate daily
```

**Potential savings:** 50-70% for non-production environments

### Cost Monitoring

```bash
# Monthly cost estimate
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --filter file://eks-filter.json

# eks-filter.json
{
  "Tags": {
    "Key": "kubernetes.io/cluster/my-cluster",
    "Values": ["owned"]
  }
}
```

**Set up billing alerts:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name eks-cost-alert \
  --alarm-description "EKS cost exceeds $500/month" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 500 \
  --comparison-operator GreaterThanThreshold
```

---

## Best Practices

### Node Group Design

✅ **Do:**
- Deploy nodes across multiple AZs (at least 2)
- Use ARM architecture (Graviton) when possible
- Set `min_size >= 1` for production (avoid zero nodes)
- Use descriptive node group names
- Tag nodes with environment, team, purpose
- Enable auto-scaling for variable workloads
- Right-size instances based on actual usage

❌ **Don't:**
- Put all nodes in one AZ (single point of failure)
- Set `min_size = 0` for critical workloads
- Use generic names like "ng1", "nodes"
- Over-provision instances
- Mix unrelated workloads without node selectors
- Forget to set `max_size` (can cause runaway costs)

### Scaling Configuration

✅ **Do:**
- Set realistic `max_size` based on budget
- Use `min_size >= number of AZs` for HA
- Monitor scaling events
- Configure pod disruption budgets
- Test scaling behavior in non-prod

❌ **Don't:**
- Set `max_size` too low (prevents scaling)
- Set `min_size = max_size` for auto-scaling workloads
- Ignore scaling metrics
- Scale without testing
- Forget to configure cluster autoscaler

### Security

✅ **Do:**
- Use private subnets for nodes
- Configure minimal security group rules
- Use IRSA for pod permissions (not node IAM roles)
- Regularly update AMIs
- Enable CloudWatch logging
- Use Secrets Manager for sensitive data

❌ **Don't:**
- Put nodes in public subnets (production)
- Open unnecessary ports in security groups
- Grant broad IAM permissions to nodes
- Use outdated AMIs
- Store secrets in environment variables
- Disable security features for convenience

### High Availability

✅ **Do:**
- Deploy across 3 AZs for production
- Set `min_size >= 3` (one per AZ)
- Use pod anti-affinity rules
- Configure pod disruption budgets (PDBs)
- Test node failures

❌ **Don't:**
- Use single AZ for production
- Set `min_size = 1` for critical apps
- Ignore pod placement
- Skip PDB configuration
- Assume nodes won't fail

---

## Troubleshooting

### Issue: Nodes Not Joining Cluster

**Symptoms:**
```bash
kubectl get nodes
# No nodes or nodes in NotReady state
```

**Diagnosis:**

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup

# Check IAM role
aws iam get-role --role-name my-nodegroup-role

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check subnet routing
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxxxx"
```

**Common causes:**

1. **IAM Role Missing Policies**
```bash
# Verify policies attached
aws iam list-attached-role-policies --role-name my-nodegroup-role

# Should show:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly
```

**Fix:** Policies are auto-attached by this module. Check if role was created successfully.

2. **Security Group Rules Missing**
```bash
# Check node SG allows traffic from cluster SG
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-nodesg"
```

**Fix:** Add required ingress rules (see Security Group Requirements section)

3. **Subnet Has No Route to Internet**
```bash
# Private subnet must route to NAT Gateway or VPC endpoints
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxx"
```

**Fix:** Ensure route table has `0.0.0.0/0 → NAT Gateway` or VPC endpoints for ECR/S3/EC2

4. **Subnet Out of IPs**
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].AvailableIpAddressCount'
```

**Fix:** Use larger subnets or add additional subnets

### Issue: Pods Pending (Insufficient Resources)

**Symptoms:**
```bash
kubectl get pods
# NAME                    READY   STATUS    RESTARTS   AGE
# my-app-5d4f8c7b-x9z2k   0/1     Pending   0          5m
```

**Diagnosis:**
```bash
kubectl describe pod my-app-5d4f8c7b-x9z2k
# Events:
#   Warning  FailedScheduling  pod has unbound immediate PersistentVolumeClaims
#   OR
#   Warning  FailedScheduling  0/3 nodes are available: insufficient cpu
```

**Common causes:**

1. **Insufficient CPU/Memory**
```bash
# Check node capacity
kubectl top nodes

# Check pod requests
kubectl describe pod my-app-5d4f8c7b-x9z2k | grep -A 5 "Requests:"
```

**Fix:**
- Reduce pod resource requests
- Add more nodes (increase `desired_size` or `max_size`)
- Use larger instance types

2. **Node Affinity/Taints**
```bash
# Check if pod has node selector
kubectl get pod my-app-5d4f8c7b-x9z2k -o yaml | grep -A 5 "nodeSelector"

# Check node taints
kubectl describe nodes | grep Taints
```

**Fix:**
- Remove node selector/affinity if not needed
- Add matching labels to nodes
- Use tolerations for taints

3. **Cluster Autoscaler Not Working**
```bash
# Check autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check autoscaler configuration
kubectl get deployment -n kube-system cluster-autoscaler -o yaml
```

**Fix:**
- Install/configure cluster autoscaler
- Verify IAM permissions
- Check autoscaler discovers node groups

### Issue: High Node CPU/Memory Usage

**Diagnosis:**
```bash
# Check node metrics
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Check resource requests vs limits
kubectl describe nodes | grep -A 10 "Allocated resources"
```

**Fix:**

1. **Right-size pods:**
```yaml
# Before
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"

# After (based on actual usage)
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

2. **Add more nodes:**
```hcl
desired_size = 5  # Was 3
```

3. **Use larger instances:**
```hcl
instance_types = "t4g.large"  # Was t4g.medium
```

### Issue: ImagePullBackOff

**Symptoms:**
```bash
kubectl get pods
# NAME                    READY   STATUS             RESTARTS   AGE
# my-app-5d4f8c7b-x9z2k   0/1     ImagePullBackOff   0          2m
```

**Diagnosis:**
```bash
kubectl describe pod my-app-5d4f8c7b-x9z2k
# Events:
#   Failed to pull image "123456789012.dkr.ecr.ap-south-1.amazonaws.com/my-app:latest": 
#   rpc error: code = Unknown desc = Error response from daemon: 
#   Get https://123456789012.dkr.ecr.ap-south-1.amazonaws.com/v2/: 
#   net/http: request canceled while waiting for connection
```

**Common causes:**

1. **ECR Authentication Failure**
```bash
# Check if ECR policy is attached
aws iam list-attached-role-policies --role-name my-nodegroup-role | grep ECR
```

**Fix:** Policy is auto-attached by module. Verify role exists.

2. **No Internet Access**
```bash
# Check if nodes can reach ECR
# SSH to node or use SSM
curl https://api.ecr.ap-south-1.amazonaws.com

# Check NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

**Fix:**
- Ensure private subnet routes to NAT Gateway
- Or add VPC endpoints for ECR (cheaper than NAT)

3. **VPC Endpoints Not Configured**

**Fix:** Add ECR and S3 VPC endpoints:
```hcl
vpc_endpoint_parameters = {
  default = {
    ecr_api = {
      vpc_endpoint_type = "Interface"
      service_name      = "ecr.api"
      subnet_names      = ["private_sub1", "private_sub2"]
      security_group_names = ["endpoint_sg"]
      private_dns_enabled = true
    }
    
    ecr_dkr = {
      vpc_endpoint_type = "Interface"
      service_name      = "ecr.dkr"
      subnet_names      = ["private_sub1", "private_sub2"]
      security_group_names = ["endpoint_sg"]
      private_dns_enabled = true
    }
    
    s3 = {
      vpc_endpoint_type = "Gateway"
      service_name      = "s3"
      route_table_names = ["private_rt"]
    }
  }
}
```

4. **Image Doesn't Exist**
```bash
# List ECR images
aws ecr list-images --repository-name my-app

# Check if tag exists
aws ecr describe-images \
  --repository-name my-app \
  --image-ids imageTag=latest
```

**Fix:** Push image to ECR or fix image name/tag in deployment

### Issue: Nodes Stuck in "Degraded" State

**Diagnosis:**
```bash
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup \
  --query 'nodegroup.health'
```

**Common causes:**
- Launch template issues
- AMI compatibility issues
- Subnet capacity issues

**Fix:**
```bash
# Delete and recreate node group
terraform destroy -target=module.eks_nodegroups[\"cluster\"].aws_eks_node_group.nodegroup[\"nodegroup_name\"]
terraform apply
```

### Issue: Cannot Delete Node Group

**Symptoms:**
```
Error: ResourceInUseException: Nodegroup cannot be deleted while pods are running
```

**Fix:**
```bash
# Drain nodes first
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Or scale down pods
kubectl scale deployment my-app --replicas=0

# Then delete node group
terraform destroy -target=module.eks_nodegroups[\"cluster\"].aws_eks_node_group.nodegroup[\"ng\"]
```

---

## Validation Checklist

```bash
# ✅ Node group created
terraform output -module=eks_nodegroups

# ✅ Nodes joined cluster
kubectl get nodes
# Should show nodes in Ready state

# ✅ Node group status ACTIVE
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup \
  --query 'nodegroup.status'

# ✅ IAM role created and policies attached
aws iam get-role --role-name my-nodegroup-role
aws iam list-attached-role-policies --role-name my-nodegroup-role

# ✅ Launch template created
aws ec2 describe-launch-templates \
  --filters "Name=launch-template-name,Values=my-nodegroup-lt*"

# ✅ Security groups attached
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=my-nodegroup" \
  --query 'Reservations[*].Instances[*].SecurityGroups'

# ✅ Nodes have correct instance type
kubectl get nodes -o wide

# ✅ Pods can be scheduled
kubectl run test --image=nginx --restart=Never
kubectl get pod test
kubectl delete pod test

# ✅ Pods can pull images from ECR
kubectl run ecr-test --image=123456789012.dkr.ecr.ap-south-1.amazonaws.com/my-app:latest
kubectl get pod ecr-test
kubectl delete pod ecr-test

# ✅ Auto-scaling works (if configured)
kubectl scale deployment test-app --replicas=100
# Watch nodes increase
kubectl get nodes -w

# ✅ Resource metrics available
kubectl top nodes
kubectl top pods
```

---

## Quick Reference

### Common kubectl Commands

```bash
# List nodes
kubectl get nodes
kubectl get nodes -o wide

# Node details
kubectl describe node <node-name>

# Node resource usage
kubectl top nodes

# Drain node (before maintenance)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node (after maintenance)
kubectl uncordon <node-name>

# Delete node (force remove from cluster)
kubectl delete node <node-name>

# Label nodes
kubectl label nodes <node-name> workload=web

# Taint nodes
kubectl taint nodes <node-name> key=value:NoSchedule
```

### Scaling Commands

```bash
# Manual scale (terraform)
# Update terraform.tfvars, then:
terraform apply -target=module.eks_nodegroups

# Check auto-scaling activity
kubectl logs -n kube-system deployment/cluster-autoscaler

# Force scale deployment (triggers autoscaler)
kubectl scale deployment my-app --replicas=20
```

### Cost Estimation

| Setup | Instance Type | Nodes | Monthly Cost |
|-------|---------------|-------|--------------|
| Dev (minimal) | t4g.small | 1 | ~$12 |
| Dev (HA) | t4g.medium | 2 | ~$48 |
| Prod (small) | t4g.large | 3 | ~$147 |
| Prod (medium) | m6g.large | 5 | ~$280 |
| Prod (large) | m6g.xlarge | 10 | ~$1,120 |

### Instance Type Quick Reference

**ARM (Graviton) - Recommended:**
- **Small:** `t4g.small`, `t4g.medium`
- **General:** `t4g.large`, `m6g.large`
- **Compute:** `c6g.large`, `c6g.xlarge`
- **Memory:** `r6g.large`, `r6g.xlarge`

**x86_64 (Legacy):**
- **Small:** `t3.small`, `t3.medium`
- **General:** `t3.large`, `m5.large`
- **Compute:** `c5.large`, `c5.xlarge`
- **Memory:** `r5.large`, `r5.xlarge`

---

## Advanced Topics

### Multi-Tenancy with Node Groups

**Pattern:** Separate node groups per team/application

```hcl
eks_nodegroups = {
  default = {
    shared_cluster = {
      # Team A nodes
      team_a = {
        min_size     = 2
        max_size     = 5
        desired_size = 2
        instance_types = "t4g.medium"
        # ... config
        tags = { Team = "a" }
      }

      # Team B nodes
      team_b = {
        min_size     = 2
        max_size     = 5
        desired_size = 2
        instance_types = "t4g.medium"
        # ... config
        tags = { Team = "b" }
      }
    }
  }
}
```

**Use node selectors to enforce pod placement:**

```yaml
# Team A deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-a-app
spec:
  template:
    spec:
      nodeSelector:
        Team: a
      containers:
      - name: app
        image: team-a/app:latest
```

### Custom AMI Usage

**When to use custom AMIs:**
- Pre-installed monitoring agents
- Custom security hardening
- Specific kernel versions
- Corporate compliance requirements

**Example:**

```hcl
eks_nodegroups = {
  default = {
    my_cluster = {
      custom_ami_nodes = {
        instance_ami = "ami-custom123456"  # Your custom AMI
        # ... other config
      }
    }
  }
}
```

**⚠️ Important:**
- Must be based on EKS-optimized AMI
- Must match Kubernetes version
- You're responsible for AMI updates

### GPU Node Groups

**For ML/AI workloads:**

```hcl
eks_nodegroups = {
  default = {
    ml_cluster = {
      gpu_nodes = {
        k8s_version    = "1.34"
        arch           = "x86_64"  # GPU instances are x86
        min_size       = 0
        max_size       = 3
        desired_size   = 0
        instance_types = "g4dn.xlarge"
        # ... config
        tags = { Workload = "ml-training" }
      }
    }
  }
}
```

**Install NVIDIA device plugin:**

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
```

### Blue-Green Node Group Updates

**Zero-downtime updates:**

```hcl
eks_nodegroups = {
  default = {
    my_cluster = {
      # Green (current)
      nodes_green = {
        min_size     = 3
        max_size     = 5
        desired_size = 3
        instance_types = "t4g.large"
        tags = { Version = "green" }
      }

      # Blue (new version - initially 0)
      nodes_blue = {
        min_size     = 0
        max_size     = 5
        desired_size = 0
        instance_types = "t4g.large"
        tags = { Version = "blue" }
      }
    }
  }
}
```

**Process:**
1. Deploy blue node group (desired_size = 0)
2. Scale up blue (desired_size = 3)
3. Verify pods migrate successfully
4. Scale down green (desired_size = 0)
5. Delete green node group

### Windows Node Groups

**For Windows workloads:**

```hcl
eks_nodegroups = {
  default = {
    my_cluster = {
      windows_nodes = {
        k8s_version    = "1.34"
        arch           = "x86_64"
        min_size       = 2
        max_size       = 5
        desired_size   = 2
        instance_types = "t3.large"
        instance_ami   = "ami-windows-eks-..."  # Windows AMI
        tags = { OS = "windows" }
      }
    }
  }
}
```

**Requirements:**
- Must use Windows EKS-optimized AMI
- Requires larger instances (minimum t3.large)
- Must have Linux nodes for system pods

---

## Migration Guide

### From Self-Managed Nodes to Managed Node Groups

**Step 1: Create managed node group**

```hcl
eks_nodegroups = {
  default = {
    my_cluster = {
      managed = {
        min_size     = 2
        max_size     = 5
        desired_size = 2
        instance_types = "t4g.large"
        # ... config
      }
    }
  }
}
```

```bash
terraform apply
```

**Step 2: Cordon self-managed nodes**

```bash
kubectl cordon <self-managed-node>
```

**Step 3: Drain self-managed nodes**

```bash
kubectl drain <self-managed-node> --ignore-daemonsets --delete-emptydir-data
```

**Step 4: Verify workloads migrated**

```bash
kubectl get pods -o wide
# Verify pods are on managed nodes
```

**Step 5: Terminate self-managed nodes**

```bash
# Remove from terraform or delete ASG/instances
```

### Upgrading Node Group Kubernetes Version

**Scenario:** Cluster upgraded from 1.33 to 1.34, now upgrade nodes

**Step 1: Verify cluster version**

```bash
kubectl version --short
# Client Version: v1.34.0
# Server Version: v1.34.0
```

**Step 2: Update node group version**

```hcl
# terraform.tfvars
eks_nodegroups = {
  default = {
    my_cluster = {
      my_nodes = {
        k8s_version = "1.34"  # Was 1.33
        # ... other config
      }
    }
  }
}
```

**Step 3: Apply changes**

```bash
terraform plan
# Review: new launch template, rolling node replacement
terraform apply
```

**Step 4: Monitor rollout**

```bash
# Watch nodes update
kubectl get nodes -w

# Watch pods reschedule
kubectl get pods -A -o wide -w
```

**Step 5: Verify**

```bash
# Check node versions
kubectl get nodes -o wide

# Check pod status
kubectl get pods -A
```

### Migrating Between Instance Types

**Scenario:** Migrate from x86 to ARM for cost savings

**Step 1: Create new ARM node group**

```hcl
eks_nodegroups = {
  default = {
    my_cluster = {
      # Existing x86 nodes
      x86_nodes = {
        arch           = "x86_64"
        instance_types = "t3.medium"
        min_size       = 3
        max_size       = 5
        desired_size   = 3
      }

      # New ARM nodes
      arm_nodes = {
        arch           = "arm64"
        instance_types = "t4g.medium"
        min_size       = 0
        max_size       = 5
        desired_size   = 0
      }
    }
  }
}
```

**Step 2: Deploy ARM node group**

```bash
terraform apply
```

**Step 3: Scale up ARM, scale down x86**

```hcl
# Update terraform.tfvars
x86_nodes = { desired_size = 0 }
arm_nodes = { desired_size = 3 }
```

```bash
terraform apply
```

**Step 4: Verify workloads**

```bash
kubectl get pods -o wide
# Verify pods running on ARM nodes
```

**Step 5: Remove x86 node group**

```hcl
# Remove x86_nodes from terraform.tfvars
```

```bash
terraform apply
```

---

## FAQ

### Q: How many node groups should I have?

**A:** It depends:
- **Small team/simple app:** 1 node group per cluster
- **Medium team:** 2-3 node groups (general, memory-optimized, compute-optimized)
- **Large team/complex:** Multiple node groups per team/workload type

**Start with 1, split as needed.**

### Q: ARM vs x86_64 - which should I choose?

**A:**
- **ARM (Graviton):** 20-40% cheaper, better performance per dollar, recommended for most workloads
- **x86_64:** For legacy apps, specific software that doesn't support ARM

**Recommendation:** Use ARM unless you have a specific reason not to.

### Q: What's the difference between desired, min, and max size?

**A:**
- **`desired_size`:** Target number of nodes (initial count)
- **`min_size`:** ASG never scales below this (baseline capacity)
- **`max_size`:** ASG never scales above this (cost ceiling)

**Example:** `min=2, desired=3, max=10` means start with 3, never go below 2, never exceed 10.

### Q: Can I change instance type without downtime?

**A:** Yes, if you have multiple nodes:
1. Terraform creates new launch template
2. New nodes are added with new instance type
3. Old nodes are drained and terminated
4. Pods reschedule to new nodes

**⚠️ Single-node clusters will have brief downtime during node replacement.**

### Q: How do I update node AMIs?

**A:**
- **Automatic (recommended):** Leave `instance_ami = ""`, module auto-selects latest
- **Manual:** Specify `instance_ami = "ami-xxxxx"`, update as needed

**Run `terraform apply` to trigger rolling update.**

### Q: What happens during a node update?

**A:**
1. New nodes are launched with new configuration
2. Old nodes are cordoned (no new pods)
3. Pods are drained (evicted gracefully)
4. Old nodes are terminated
5. Node group updated

**Duration:** 5-10 minutes per node (rolling)

### Q: Can I mix ARM and x86 nodes in same node group?

**A:** No. Each node group uses one architecture. Create separate node groups for ARM and x86.

### Q: How do I add custom IAM permissions to nodes?

**A:** Use `additional_policies`:

```hcl
additional_policies = {
  my_policy = {
    nodegroups = ["my_nodegroup"]
    policy     = [jsonencode({ ... })]
  }
}
```

**Better approach:** Use IRSA (IAM Roles for Service Accounts) for pod-level permissions.

### Q: What's the cost of a node group?

**A:** Node groups themselves are free. You pay for:
- EC2 instances (hourly)
- EBS volumes (per GB per month)
- Data transfer (out to internet)

**Control plane cost:** ~$73/month (separate from node groups)

### Q: Can I use Spot instances?

**A:** This framework doesn't natively support Spot instances, but you can:
- Configure manually via AWS Console
- Use separate tools (karpenter)
- Create via Terraform (requires custom configuration)

### Q: How do I troubleshoot nodes not joining cluster?

**A:** Check:
1. IAM role has required policies
2. Security groups allow cluster → node communication
3. Subnets have internet access (NAT or VPC endpoints)
4. Subnets have available IPs

**See Troubleshooting section for detailed steps.**

### Q: Should I use one large node or multiple small nodes?

**A:**
- **Multiple small nodes:** Better for HA, fault tolerance, cost optimization with auto-scaling
- **Fewer large nodes:** Better resource utilization, fewer network hops

**Recommendation:** Multiple small-to-medium nodes for production.

### Q: How do I prevent pods from running on specific nodes?

**A:** Use taints and tolerations:

```bash
# Taint node
kubectl taint nodes <node-name> key=value:NoSchedule

# Pod must have toleration to run on tainted node
```

Or use node selectors in pod spec.

---

## Testing Checklist

```bash
# ✅ Nodes are Ready
kubectl get nodes
# All nodes should show STATUS: Ready

# ✅ System pods running
kubectl get pods -n kube-system
# CoreDNS, kube-proxy, aws-node should be Running

# ✅ Workload pods can schedule
kubectl run test-nginx --image=nginx
kubectl get pod test-nginx
kubectl delete pod test-nginx

# ✅ Resource metrics available
kubectl top nodes
kubectl top pods -A

# ✅ Logs accessible
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=10

# ✅ DNS resolution works
kubectl run test-dns --image=busybox --restart=Never -- nslookup kubernetes.default
kubectl logs test-dns
kubectl delete pod test-dns

# ✅ Internet connectivity (if needed)
kubectl run test-curl --image=curlimages/curl --restart=Never -- curl -I https://www.google.com
kubectl logs test-curl
kubectl delete pod test-curl

# ✅ ECR image pull works
kubectl run test-ecr --image=123456789012.dkr.ecr.ap-south-1.amazonaws.com/my-app:latest
kubectl get pod test-ecr
kubectl delete pod test-ecr

# ✅ Auto-scaling works (if configured)
kubectl scale deployment test-app --replicas=50
kubectl get nodes -w
# Watch for new nodes to be added

# ✅ Node updates work
# Update instance_types in tfvars, then:
terraform apply
kubectl get nodes -w
# Watch for rolling node replacement
```

---

## Change Log

### Version 1.0 (2025-01-21)
- Initial release
- Support for ARM and x86_64 architectures
- Automatic AMI selection
- Custom IAM policy support
- Launch template integration
- Multi-AZ deployment support
- Integration with EKS cluster module

---

## Contributing

When contributing to this module:

1. ✅ Test with both ARM and x86 instances
2. ✅ Validate auto-scaling behavior
3. ✅ Test node updates (instance type, AMI, version)
4. ✅ Verify IAM policy attachments
5. ✅ Test with multiple node groups per cluster
6. ✅ Document any new features or changes
7. ✅ Update troubleshooting section with new issues

---

## Module Metadata

- **Author** [rajarshigit2441139][mygithub]
- **Version:** 1.0
- **Provider:** AWS
- **Terraform Version:** >= 1.0
- **Maintained By:** Infrastructure Team
- **Last Updated:** 2025-01-15
- **Module Type:** Container Orchestration - Worker Nodes
- **Complexity:** Medium-High (IAM, networking, auto-scaling)
- **Dependencies:** EKS Cluster, VPC, Subnet, Security Group modules

---

## Support
**Questions? Issues? Feedback?**

- Read Documents
- Check [Troubleshooting](#troubleshooting) section
- Open a [GitHub Issue][GithubIsshuePage]
- Join [Slack][SlackLink]
- [FAQ](#FAQ)

---

## Summary

The EKS Node Group module provides comprehensive managed node group functionality with:

- ✅ Automatic AMI selection (or manual override)
- ✅ Support for ARM (Graviton) and x86_64 architectures
- ✅ Custom IAM policy support per node group
- ✅ Launch template with custom security groups
- ✅ Auto-scaling capabilities
- ✅ Multi-AZ deployment
- ✅ Rolling updates with zero downtime
- ✅ Integration with cluster autoscaler

**Most Common Use Case:** Create production-grade, auto-scaling ARM node groups for cost-effective Kubernetes workload execution.

**Remember:**
- Use ARM (Graviton) for 20-40% cost savings
- Deploy across multiple AZs for high availability
- Set realistic min/max sizes for auto-scaling
- Use private subnets for production nodes
- Keep AMIs updated with automatic selection
- Monitor node resource usage and right-size

---

## Additional Resources

- **AWS EKS Managed Node Groups:** https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html
- **Terraform aws_eks_node_group:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
- **EKS Optimized AMIs:** https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-amis.html
- **Graviton (ARM) Instances:** https://aws.amazon.com/ec2/graviton/
- **Cluster Autoscaler:** https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler
- **EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/




[SlackLink]: https://theoperationhq.slack.com/

[GithubIsshuePage]: https://github.com/rajarshigit2441139/terraform-aws-infrastructure-framework/issues

[mygithub]: https://github.com/rajarshigit2441139