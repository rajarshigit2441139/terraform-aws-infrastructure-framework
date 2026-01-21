# Getting Started with Terraform Infrastructure Framework

This guide walks you through your first deployment using this Terraform Infrastructure Framework — from initial setup to a running infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
  - [Required Tools](#required-tools)
  - [AWS Account Setup](#aws-account-setup)
  - [Service Quotas](#service-quotas)
- [Initial Setup](#initial-setup)
  - [Clone or Download the Framework](#1-clone-or-download-the-framework)
  - [Verify Directory Structure](#2-verify-directory-structure)
  - [Initial Terraform Initialization](#3-initial-terraform-initialization)
- [Understanding Workspaces](#understanding-workspaces)
  - [Default Workspaces](#default-workspaces)
  - [Workspace Commands](#workspace-commands)
  - [How Workspaces Work](#how-workspaces-work)
- [Provider Configuration](#provider-configuration)
  - [Default Configuration](#default-configuration)
  - [Customizing the Region](#customizing-the-region)
  - [Provider Credentials](#provider-credentials)
- [Backend Configuration](#backend-configuration)
  - [Why Remote State?](#why-remote-state)
  - [Prerequisites](#prerequisites-1)
  - [Backend Configuration Files](#backend-configuration-files)
  - [Initialize Backend](#initialize-backend)
  - [Verify Backend Configuration](#verify-backend-configuration)
  - [Switching Between Workspaces with Remote Backend](#switching-between-workspaces-with-remote-backend)
  - [Backend Configuration Summary](#backend-configuration-summary)
- [Your First Deployment](#your-first-deployment)
  - [Configuration Basics](#configuration-basics)
  - [Deployment Steps](#deployment-steps)
  - [Verification](#verification)
- [Next Steps](#next-steps)
- [Common First-Time Issues](#common-first-time-issues)
- [Destroying Your Infrastructure](#destroying-your-infrastructure)
- [Getting Help](#getting-help)
- [Summary](#summary)

---

## Prerequisites

### Required Tools

Install these tools before proceeding:

```bash
# Terraform (>= 1.1.0)
terraform --version

# AWS CLI (>= 2.0)
aws --version

# kubectl (for EKS clusters, matching your EKS version)
kubectl version --client

# jq (for JSON processing)
jq --version
```

Installation guides:
- Terraform: https://developer.hashicorp.com/terraform/downloads  
- AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html  
- kubectl: https://kubernetes.io/docs/tasks/tools/  

---

### AWS Account Setup

#### AWS Account Access
You need:
- Active AWS account
- Appropriate permissions (VPC, EC2, EKS, IAM, S3)

#### Configure AWS Credentials

```bash
# Option 1: AWS CLI configure
aws configure

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-south-1"

# Verify credentials
aws sts get-caller-identity
```

#### Verify Permissions

```bash
# Check if you can list VPCs (basic permission test)
aws ec2 describe-vpcs --region ap-south-1

# Check S3 access (for remote state)
aws s3 ls
```

---

### Service Quotas

Check your AWS account limits:

| Service | Default | Check Command |
|--------|---------|---------------|
| VPCs per region | 5 | `aws ec2 describe-vpcs --query 'length(Vpcs)'` |
| Elastic IPs | 5 | `aws ec2 describe-addresses --query 'length(Addresses)'` |
| NAT Gateways | 5 | `aws ec2 describe-nat-gateways --query 'length(NatGateways)'` |
| EKS Clusters | 100 | `aws eks list-clusters --query 'length(clusters)'` |

Request increases via **AWS Service Quotas** if needed.

---

## Initial Setup
 **Fork The Repo**
### 1. Clone or Download the Framework

```bash
# If using git
git clone <repository-url>
cd terraform-infrastructure-framework
```

---

### 2. Verify Directory Structure

```bash
tree -L 2
```

Expected structure:

```text
.
├── README.md                          # This file
├── SECURITY.md                        # Project security report
├── LICENSE 
├── terraform.tfvars                   # User configuration (git-ignored)
├── variables.tf                       # Root variable definitions
├── outputs.tf                         # Root outputs
├── provider.tf                        # AWS provider configuration
│
├── 01_locals.tf                       # Local value transformations
├── 02_vpc.tf                          # VPC module calls
├── 03_subnet.tf                       # Subnet module calls
├── 04_rt.tf                           # Route Table module calls
├── 05_security_group.tf               # Security Group module calls
├── 06_eip.tf                          # Elastic IP module calls
├── 07_eks.tf                          # EKS Cluster module calls
├── 08_gateway.tf                      # IGW, NAT Gateway module calls
├── 09_vpc_endpoint.tf                 # VPC Endpoint module calls
│
├── backendfiles/                      # Backend configuration files
│   ├── backend.default.conf.demo
│   ├── backend.prod.conf
│   └── backend.qe.conf
│
├── docs/                              # Documentation
│   ├── GETTING_STARTED.md
│   ├── NETWORKING.md
│   ├── NETWORK_SECURITY.md
│   ├── VPC_ENDPOINTS.md
│   ├── EKS.md
│   ├── EXAMPLE.md
│   ├── TROUBLESHOOTING.md
│   └── COST_OPTIMIZATION.md
│ 
├── examples/
│    ├── all_example.tfvars
│    ├── mini_test.tfvars 
│    └── pub_test.tfvars 
│
└── modules/                           # Reusable modules
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── subnet/
    ├── rt/
    ├── igw/
    ├── nat_gw/
    ├── eip/
    ├── security_group/
    ├── vpc_endpoint/
    └── eks_mng/
        ├── eks_cluster/
        └── eks_nodegroups/

        
```

---

### 3. Initial Terraform Initialization

```bash
# Basic initialization (local state only, for first-time setup)
terraform init
```

Expected output:

```text
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

What this does:
- Downloads AWS provider
- Initializes module references
- Creates `.terraform/`
- Creates `.terraform.lock.hcl`
- Creates local state file `terraform.tfstate` (temporary)

---

## Understanding Workspaces

This framework uses Terraform workspaces to manage multiple environments from a single codebase.

### Default Workspaces

| Workspace | Purpose | Typical Use |
|----------|---------|-------------|
| `default` | Development | Developer testing, experiments |
| `qe` | QA/Staging | Pre-production testing |
| `prod` | Production | Live production environment |

### Workspace Commands

```bash
# List workspaces
terraform workspace list

# Show current workspace
terraform workspace show

# Create new workspace
terraform workspace new qe
terraform workspace new prod

# Switch workspace
terraform workspace select default
terraform workspace select qe
terraform workspace select prod
```

### How Workspaces Work

Configuration in `terraform.tfvars`:

```hcl
vpc_parameters = {
  default = {                    # Applied when workspace = "default"
    dev_vpc = { ... }
  }

  qe = {                         # Applied when workspace = "qe"
    qe_vpc = { ... }
  }

  prod = {                       # Applied when workspace = "prod"
    prod_vpc = { ... }
  }
}
```

Terraform selects the right block:

```hcl
# In module calls
vpc_parameters = lookup(var.vpc_parameters, terraform.workspace, {} )
```

Important: always verify your workspace before `apply`:

```bash
terraform workspace show
```

---

## Provider Configuration

The AWS provider is configured in `provider.tf` at the project root.

### Default Configuration

File: `provider.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "aws" {
  region = "ap-south-1"
}
```

### Customizing the Region

Option 1: Edit `provider.tf`:

```hcl
provider "aws" {
  region = "us-east-1"
}
```

Option 2: Use environment variable:

```bash
export AWS_DEFAULT_REGION="us-east-1"
```

Option 3: Use AWS CLI config:

```bash
aws configure set region us-east-1
```

### Provider Credentials

Terraform uses credentials from:
- Environment variables (highest priority)
- AWS CLI config (`~/.aws/credentials`)
- IAM role (if running on EC2/ECS/Lambda)

Verify:

```bash
aws sts get-caller-identity
```

---

## Backend Configuration

This framework uses **S3 remote state** with **DynamoDB locking** (recommended) for safe collaboration.

### Why Remote State?

Benefits:
- ✅ Team collaboration
- ✅ State locking (prevents concurrent modifications)
- ✅ Backup & versioning
- ✅ Encryption at rest

---

### Prerequisites

You need an S3 bucket to store Terraform state.

#### Option 1: Create bucket manually

```bash
BUCKET_NAME="my-terraform-state-$(date +%s)"

aws s3 mb s3://${BUCKET_NAME} --region ap-south-1

# Enable versioning
aws s3api put-bucket-versioning   --bucket ${BUCKET_NAME}   --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption   --bucket ${BUCKET_NAME}   --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "S3 bucket created: ${BUCKET_NAME}"
```

#### Option 2: Use existing bucket

```bash
aws s3 ls
```

---

### Backend Configuration Files

Backend configs live in `backendfiles/`.

```text
backendfiles/
├── backend.default.conf.demo    # Example configuration
├── backend.default.conf         # Development environment
├── backend.qe.conf              # QA/Staging environment
└── backend.prod.conf            # Production environment
```

#### Step 1: Create Backend Config Files

Development (`backend.default.conf`):

```hcl
bucket  = "my-terraform-state-1234567890"
key     = "terraform.tfstate"
region  = "ap-south-1"
encrypt = true
```

QE/Staging (`backend.qe.conf`):

```hcl
bucket  = "my-terraform-state-1234567890"
key     = "terraform.tfstate"
region  = "ap-south-1"
encrypt = true
```

Production (`backend.prod.conf`):

```hcl
bucket  = "my-terraform-state-prod-1234567890"
key     = "terraform.tfstate"
region  = "ap-south-1"
encrypt = true
```

Best practices:
- ✅ Separate production bucket
- ✅ Versioning enabled
- ✅ Encryption enabled (`encrypt = true`)

---

### Initialize Backend

Linux/Mac:

```bash
export ENV=$(terraform workspace show)
terraform init -backend-config=backendfiles/backend.${ENV}.conf
```

Migrate local state:

```bash
terraform init -migrate-state -backend-config=backendfiles/backend.${ENV}.conf
```

Windows PowerShell:

```powershell
$ENV = terraform workspace show
terraform init -backend-config="backendfiles/backend.$ENV.conf"
```

---

### Verify Backend Configuration

```bash
terraform show
aws s3 ls s3://my-terraform-state-1234567890/
```

Optional inspect:

```bash
aws s3 cp s3://my-terraform-state-1234567890/terraform.tfstate - | jq '.version'
```

---

### Switching Between Workspaces with Remote Backend

```bash
terraform workspace select qe
export ENV=$(terraform workspace show)
terraform init -backend-config=backendfiles/backend.${ENV}.conf
terraform workspace show
```

### Backend Configuration Summary

| Workspace | Config File | Typical S3 Bucket |
|----------|-------------|-------------------|
| `default` | `backend.default.conf` | my-terraform-state-dev-123 |
| `qe` | `backend.qe.conf` | my-terraform-state-qe-123 |
| `prod` | `backend.prod.conf` | my-terraform-state-prod-123 |

---

## Your First Deployment

We’ll deploy a minimal infrastructure with:

- 1 VPC  
- 2 Subnets (1 public, 1 private)  
- 1 Internet Gateway  
- 1 NAT Gateway (optional, for private subnet internet access)  
- Security Groups  
- (Optional) EKS Cluster & node groups  

**Estimated cost:**  
- Networking only: ~$35/month (NAT GW dominates)  
- With EKS: higher (cluster + nodes + networking)

---

## Configuration Basics

### Understanding `terraform.tfvars`

Structure:

```hcl
aws_region = "ap-south-1"

resource_type_parameters = {
  default = { ... }
  qe      = { ... }
  prod    = { ... }
}
```

### Step 1: Create `terraform.tfvars`

```bash
touch terraform.tfvars
```

### Step 2: Add Minimal Configuration

Paste this:

```hcl
# ============================================================================
# MINIMAL INFRASTRUCTURE - NETWORKING ONLY
# ============================================================================

vpc_parameters = {
  default = {
    dev_vpc = {
      cidr_block = "10.10.0.0/16"
      tags = {
        Environment = "dev"
        Purpose     = "infrastructure"
      }
    }
  }
}

subnet_parameters = {
  default = {
    public_subnet = {
      cidr_block              = "10.10.1.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = true
      tags = { Type = "public" }
    }

    private_subnet = {
      cidr_block              = "10.10.10.0/24"
      vpc_name                = "dev_vpc"
      az_index                = 0
      map_public_ip_on_launch = false
      tags = { Type = "private" }
    }
  }
}

igw_parameters = {
  default = {
    dev_igw = {
      vpc_name = "dev_vpc"
      tags = { Purpose = "internet-access" }
    }
  }
}

eip_parameters = {
  default = {
    nat_eip = {
      domain = "vpc"
      tags = { Purpose = "nat-gateway" }
    }
  }
}

nat_gateway_parameters = {
  default = {
    dev_nat = {
      subnet_name                = "public_subnet"
      eip_name_for_allocation_id = "nat_eip"
      tags = { Purpose = "private-subnet-internet" }
    }
  }
}

rt_parameters = {
  default = {
    public_rt = {
      vpc_name = "dev_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "igw"
        target_key  = "dev_igw"
      }]
      tags = { Type = "public" }
    }

    private_rt = {
      vpc_name = "dev_vpc"
      routes = [{
        cidr_block  = "0.0.0.0/0"
        target_type = "nat"
        target_key  = "dev_nat"
      }]
      tags = { Type = "private" }
    }
  }
}

rt_association_parameters = {
  public_assoc = {
    subnet_name = "public_subnet"
    rt_name     = "public_rt"
  }

  private_assoc = {
    subnet_name = "private_subnet"
    rt_name     = "private_rt"
  }
}

security_group_parameters = {
  default = {
    general_sg = {
      name     = "dev-general-sg"
      vpc_name = "dev_vpc"
      tags = { Purpose = "general-compute" }
    }
  }
}

ipv4_ingress_rule = {
  default = {
    general_ssh = {
      vpc_name  = "dev_vpc"
      sg_name   = "general_sg"
      from_port = 22
      to_port   = 22
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }

    general_https = {
      vpc_name  = "dev_vpc"
      sg_name   = "general_sg"
      from_port = 443
      to_port   = 443
      protocol  = "TCP"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}

ipv4_egress_rule = {
  default = {
    general_egress = {
      vpc_name  = "dev_vpc"
      sg_name   = "general_sg"
      protocol  = "-1"
      cidr_ipv4 = "0.0.0.0/0"
    }
  }
}
```

What this creates:
- ✅ VPC, subnets, IGW, NAT GW, route tables, SGs
- ✅ EIP attached to NAT is free
- ✅ NAT GW costs ~$32/month + data processing

---

## Deployment Steps

### Step 1: Verify Configuration

```bash
terraform workspace show
terraform fmt
terraform validate
```

### Step 2: Plan

```bash
terraform plan
```

### Step 3: Apply

```bash
terraform apply
```

NAT Gateway takes the longest (~2–3 minutes).

### Step 4: Monitor NAT Gateway (optional)

```bash
watch -n 5 'aws ec2 describe-nat-gateways --filters "Name=tag:Name,Values=dev_nat" --query "NatGateways[0].State"'
```

---

## Verification

### Step 1: Verify Terraform State

```bash
terraform state list
```

### Step 2: Check Outputs

```bash
terraform output
terraform output vpc_id
terraform output public_subnet_id
```

### Step 3: Verify in AWS

```bash
aws ec2 describe-vpcs   --filters "Name=tag:Name,Values=dev_vpc"   --query 'Vpcs[0].VpcId'

aws ec2 describe-subnets   --filters "Name=tag:Name,Values=public_subnet"   --query 'Subnets[0].SubnetId'

aws ec2 describe-nat-gateways   --filters "Name=tag:Name,Values=dev_nat"   --query 'NatGateways[0].State'
```

Expected NAT state: `"available"`

### Step 4: Verify Connectivity

Launch a test EC2 in the private subnet and test:

```bash
curl -I https://www.google.com
```

---

## Next Steps

### Networking Only
1. Deploy EC2 instances
2. Add VPC Endpoints (reduce NAT GW costs)
3. Multi-AZ setup (subnets + NAT per AZ)

### EKS Deployment
1. Add EKS configuration
2. Read `docs/EKS.md`
3. Use EKS patterns for node groups & add-ons

---

## Common First-Time Issues

### 1) AWS Credentials Not Configured

```text
Error: error configuring Terraform AWS Provider: no valid credential sources
```

Fix:

```bash
aws configure
```

---

### 2) Backend Bucket Doesn't Exist

```text
Error: Failed to get existing workspaces: S3 bucket does not exist
```

Fix:

```bash
aws s3 mb s3://my-terraform-state-123456 --region ap-south-1
```

---

### 3) Backend Config Not Found

Fix:

```bash
ls -la backendfiles/
export ENV=$(terraform workspace show)
terraform init -backend-config=backendfiles/backend.${ENV}.conf
```

---

### 4) Insufficient Permissions

```text
Error: UnauthorizedOperation
```

Fix: ensure required IAM permissions for EC2/VPC/S3/IAM/EKS.

Example (broad, not least-privilege):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ec2:*","s3:*","iam:*","eks:*"],
    "Resource": "*"
  }]
}
```

---

### 5) Service Quota Exceeded

Example:

```text
Error: VpcLimitExceeded
```

Check:

```bash
aws ec2 describe-vpcs --query 'length(Vpcs)'
```

---

### 6) NAT Gateway Creation Failed

```text
Error: InvalidAllocationID.NotFound
```

Fix:
- Ensure EIP exists first
- Ensure `eip_name_for_allocation_id` matches EIP key
- Ensure NAT module depends on IGW (if required in your design)

---

### 7) Workspace State Conflict (Terraform version mismatch)

Fix: align Terraform versions across team (ex: `.terraform-version`).

---

### 8) Backend State Locking

```text
Error: Error acquiring the state lock
```

Fix (stale locks only):

```bash
terraform force-unlock <LOCK_ID>
```

Recommend DynamoDB locking.

---

### 9) CIDR Block Overlap

Check existing subnets:

```bash
aws ec2 describe-subnets   --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"   --query 'Subnets[*].[CidrBlock,SubnetId]'
```

---

## Destroying Your Infrastructure

```bash
terraform plan -destroy
terraform destroy
```

Clean up S3 state (optional):

```bash
aws s3 rm s3://my-terraform-state-123/terraform.tfstate
aws s3 rb s3://my-terraform-state-123 --force
```

---

## Getting Help

- Framework docs: `docs/`
- Module READMEs: `modules/*/README.md`
- Terraform community: https://discuss.hashicorp.com/
- AWS re:Post: https://repost.aws/
- Provider issues: https://github.com/hashicorp/terraform-provider-aws/issues

Debugging:

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform_debug.log
terraform apply
terraform validate
terraform state list
terraform state show <resource-address>
```

---

## Summary

You’ve successfully:
- ✅ Installed prerequisites
- ✅ Configured AWS credentials
- ✅ Understood workspaces
- ✅ Configured provider
- ✅ Configured S3 remote backend
- ✅ Deployed first infrastructure
- ✅ Verified deployment

Next: explore docs for networking, security, cost optimization, and examples.
