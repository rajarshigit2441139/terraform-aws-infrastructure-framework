# Contributing to Terraform Infrastructure Framework

First off, thank you for considering contributing to the Terraform Infrastructure Framework! It's people like you that make this project a great tool for managing AWS infrastructure.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to **[theoperation.official@gmail.com]**.

## Table of Contents

- [I Want To Contribute](#i-want-to-contribute)
  - [Legal Notice](#legal-notice)
  - [Reporting Bugs](#reporting-bugs)
  - [Reporting Security Issues](#reporting-security-issues)
  - [Requesting New Features](#requesting-new-features)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Improving Documentation](#improving-documentation)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Module Development Guidelines](#module-development-guidelines)
- [Testing Requirements](#testing-requirements)

---

## I Want To Contribute

## Legal Notice

By submitting a contribution to this project, you certify that:

1. You are the original author of the contribution, or you have the legal right to submit it.
2. You grant the project and its users a perpetual, worldwide, non-exclusive, no-charge,
   royalty-free, irrevocable license to use, modify, distribute, and sublicense your
   contribution under the Apache License, Version 2.0.
3. You understand that your contribution may be redistributed as part of the project
   under the Apache License, Version 2.0.

**If you do not agree to these terms, do not submit a contribution.**


### Reporting Bugs

Bug reports help us make the Terraform Infrastructure Framework better for everyone. Before creating a bug report, please:

1. **Search existing issues**: Check our [already reported bugs](../../issues?q=is%3Aissue+is%3Aopen+label%3Abug) to avoid duplicates
2. **Use the bug template**: When creating a new issue, use our bug report template
3. **Provide detailed information**:
   - Terraform version (`terraform version`)
   - AWS provider version
   - Operating system
   - Relevant configuration snippets
   - Error messages and logs
   - Steps to reproduce

**Example Bug Report:**
```markdown
**Terraform Version**: 1.6.0
**AWS Provider Version**: 5.0.0
**OS**: Ubuntu 22.04

**Description**: NAT Gateway fails to create in multi-AZ configuration

**Steps to Reproduce**:
1. Configure multi-AZ NAT gateways
2. Run `terraform apply`
3. Error occurs...

**Expected Behavior**: NAT gateways should be created in all AZs

**Actual Behavior**: Creation fails with error: [error message]

**Configuration**:
```hcl
nat_gateway_parameters = {
  default = {
    nat_az1 = {...}
  }
}
```

### Reporting Security Issues 

**⚠️ CRITICAL: Do not create public GitHub issues for security vulnerabilities.**

If you've found a security issue (e.g., exposed credentials, IAM policy vulnerabilities, infrastructure exposure), please email us directly at **[theoperation.official@gmail.com]** with:

- A clear and detailed description of the issue
- Steps to reproduce the vulnerability (if possible)
- Affected components, modules, or configurations
- Potential impact and severity (critical, high, medium, low)
- Suggested mitigation or fix (if available)

We will respond within 48 hours and work with you to address the issue.

### Requesting New Features

We welcome feature requests! Before submitting:

1. **Check existing requests**: Search [feature requests](../../issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement) to avoid duplicates
2. **Use the feature template**: Provide clear context about your use case
3. **Include examples**: Show how the feature would be used

**What makes a good feature request:**
- Clear problem statement
- Proposed solution with examples
- Alternative solutions considered
- Impact on existing configurations

---

## Your First Code Contribution

### Requirements

To contribute to this project, you need:

**Required Tools:**
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0 (configured with test credentials)
- Git >= 2.0
- A code editor (VS Code, IntelliJ IDEA, Sublime Text, etc.)

**Optional but Recommended:**
- [tflint](https://github.com/terraform-linters/tflint) - Terraform linter
- [terraform-docs](https://terraform-docs.io/) - Documentation generator
- [checkov](https://www.checkov.io/) - Security scanner
- [pre-commit](https://pre-commit.com/) - Git hook framework

**AWS Account:**
- Access to an AWS account for testing (use a sandbox/dev account)
- Appropriate IAM permissions for resource creation
- **Never use production credentials for testing**

### Development Setup

#### 1. Fork the Repository

**You must work from a fork - direct commits to the main repository are not allowed.**

1. Click the **Fork** button on the [repository page](../../)
2. Clone your fork to your local machine:

```bash
git clone git@github.com:{YOUR_USERNAME}/terraform-infrastructure-framework.git
cd terraform-infrastructure-framework
```

3. Add the upstream repository as a remote:

```bash
git remote add upstream git@github.com:{ORIGINAL_OWNER}/terraform-infrastructure-framework.git
```

4. Verify your remotes:

```bash
git remote -v
# origin    git@github.com:{YOUR_USERNAME}/terraform-infrastructure-framework.git (fetch)
# origin    git@github.com:{YOUR_USERNAME}/terraform-infrastructure-framework.git (push)
# upstream  git@github.com:{ORIGINAL_OWNER}/terraform-infrastructure-framework.git (fetch)
# upstream  git@github.com:{ORIGINAL_OWNER}/terraform-infrastructure-framework.git (push)
```

#### 2. Create a Feature Branch

**Important Rules:**
- ✅ **DO**: Create a separate branch for each issue/feature
- ✅ **DO**: Use descriptive branch names
- ❌ **DON'T**: Work directly on the `main` branch
- ❌ **DON'T**: Create PRs directly to `main` - use feature branches

**Branch Naming Convention:**
```bash
# Bug fixes
git checkout -b fix/issue-123-nat-gateway-error

# New features
git checkout -b feature/add-vpc-peering-module

# Documentation updates
git checkout -b docs/update-eks-guide

# Refactoring
git checkout -b refactor/simplify-locals
```

**Create a branch:**
```bash
# Sync with upstream first
git fetch upstream
git checkout main
git merge upstream/main

# Create your feature branch
git checkout -b feature/your-feature-name
```

#### 3. Make Your Changes

Follow our coding standards:

```bash
# Format your code
terraform fmt -recursive

# Validate configuration
terraform validate

# Run linter (if installed)
tflint --recursive

# Generate documentation (if modified modules)
terraform-docs markdown table --output-file README.md modules/your_module/
```

#### 4. Test Your Changes

**Minimum testing requirements:**

```bash
# 1. Initialize Terraform
terraform init

# 2. Validate syntax
terraform validate

# 3. Plan changes (use test workspace)
terraform workspace new test-feature
terraform plan

# 4. Apply in test environment (if possible)
terraform apply -auto-approve

# 5. Verify resources
terraform show
terraform output

# 6. Clean up
terraform destroy -auto-approve
terraform workspace select default
terraform workspace delete test-feature
```

**For module changes:**
- Test the module in isolation
- Test with different configurations
- Verify outputs are correct
- Check for resource drift

---

## Development Workflow

### Standard Workflow

```bash
# 1. Sync your fork with upstream
git fetch upstream
git checkout main
git merge upstream/main
git push origin main

# 2. Create feature branch
git checkout -b feature/my-awesome-feature

# 3. Make changes and commit
git add .
git commit -m "feat: add VPC peering support"

# 4. Keep branch updated
git fetch upstream
git rebase upstream/main

# 5. Push to your fork
git push origin feature/my-awesome-feature

# 6. Create Pull Request from GitHub UI
```

### Working on Multiple Features

```bash
# Switch between branches
git checkout feature/feature-a
# ... work on feature A ...
git commit -m "feat: implement feature A"

git checkout feature/feature-b
# ... work on feature B ...
git commit -m "feat: implement feature B"

# Keep both updated
git checkout feature/feature-a
git rebase upstream/main

git checkout feature/feature-b
git rebase upstream/main
```

---

## Pull Request Process

### Before Creating a PR

✅ **Checklist:**
- [ ] Code is formatted (`terraform fmt -recursive`)
- [ ] Configuration is valid (`terraform validate`)
- [ ] Documentation is updated (README.md, module docs)
- [ ] Examples are provided (if new feature)
- [ ] Tests pass (manual or automated)
- [ ] Commit messages follow guidelines
- [ ] Branch is up-to-date with `main`
- [ ] No merge conflicts

### Creating a Pull Request

1. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open PR on GitHub:**
   - Go to your fork on GitHub
   - Click "Pull Request" button
   - **Base repository**: `{ORIGINAL_OWNER}/terraform-infrastructure-framework`
   - **Base branch**: `main`
   - **Head repository**: `{YOUR_USERNAME}/terraform-infrastructure-framework`
   - **Compare branch**: `feature/your-feature-name`

3. **Fill out the PR template:**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Refactoring
   
   ## Related Issue
   Fixes #123
   
   ## Testing
   - Tested with Terraform 1.6.0
   - Applied in test environment
   - All validations pass
   
   ## Checklist
   - [x] Code formatted
   - [x] Documentation updated
   - [x] Examples provided
   ```

4. **Respond to review feedback:**
   - Address all reviewer comments
   - Push additional commits to the same branch
   - Request re-review when ready

### PR Requirements

- **Minimum 1 approval** from maintainers
- **All CI checks must pass** (if configured)
- **No merge conflicts** with `main`
- **Clean commit history** (squash if needed)

---

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(vpc): add VPC peering module` |
| `fix` | Bug fix | `fix(nat): resolve multi-AZ creation issue` |
| `docs` | Documentation only | `docs(eks): update node group examples` |
| `refactor` | Code refactoring | `refactor(locals): simplify ID resolution` |
| `test` | Adding tests | `test(subnet): add validation tests` |
| `chore` | Maintenance | `chore: update terraform version` |
| `style` | Formatting | `style: run terraform fmt` |


### Breaking Changes

Breaking changes MUST be indicated using one of the following:

- An exclamation mark after the type or scope:
  `feat(vpc)!: change subnet behavior`

- Or a footer:


### Examples

**Good commits:**
```bash
feat(endpoint): add support for Interface VPC endpoints

- Implemented Interface endpoint module
- Added security group integration
- Updated documentation with examples

Closes #45

---

fix(nat): correct EIP allocation in multi-AZ setup

The NAT gateway module was failing when creating
multiple NAT gateways due to incorrect EIP references.

Fixed by updating EIP allocation logic in locals.

Fixes #67

---

docs(cost): add cost optimization guide

Added comprehensive cost breakdown and optimization
strategies for all infrastructure components.
```

**Bad commits:**
```bash
# ❌ Too vague
git commit -m "update stuff"

# ❌ No type
git commit -m "added new feature"

# ❌ Not descriptive
git commit -m "fix bug"
```

---

## Module Development Guidelines

### Creating a New Module

```bash
# 1. Create module directory
mkdir -p modules/your_module

# 2. Create required files
cd modules/your_module
touch main.tf variables.tf outputs.tf README.md

# 3. Follow standard structure
```

**Module Structure:**
```
modules/your_module/
├── main.tf           # Resource definitions
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── README.md         # Module documentation
└── examples/         # Usage examples (optional)
    └── basic/
        └── main.tf
```

### Module Standards

**main.tf:**
```hcl
# Resource creation with for_each
resource "aws_example_resource" "this" {
  for_each = var.resource_parameters

  name       = each.value.name
  vpc_id     = each.value.vpc_id
  
  tags = merge(
    { Name = each.value.name },
    try(each.value.tags, {})
  )
}
```

**variables.tf:**
```hcl
variable "resource_parameters" {
  description = "Configuration for example resources"
  type = map(object({
    name   = string
    vpc_id = string
    tags   = optional(map(string), {})
  }))
}
```

**outputs.tf:**
```hcl
output "resources" {
  description = "Created example resources"
  value = {
    for key, resource in aws_example_resource.this :
    key => {
      id   = resource.id
      name = resource.name
      arn  = resource.arn
    }
  }
}
```

**README.md Template:**
```markdown
# Module Name

## Overview
Brief description of what this module does.

## Usage
```hcl
module "example" {
  source = "./modules/your_module"
  
  resource_parameters = {
    example1 = {
      name   = "my-resource"
      vpc_id = "vpc-123"
    }
  }
}
```

## Inputs
| Name | Description | Type | Required |
|------|-------------|------|----------|
| resource_parameters | ... | map(object) | Yes |

## Outputs
| Name | Description |
|------|-------------|
| resources | Created resources |

## Examples
See [examples/](./examples) directory.


### Documentation Requirements

- **Every module MUST have a README.md**
- **Every variable MUST have a description**
- **Every output MUST have a description**
- **Provide usage examples**
- **Document any dependencies**

---

## Testing Requirements

### Manual Testing

**Minimum testing for all PRs:**

```bash
# 1. Syntax validation
terraform fmt -check -recursive
terraform validate

# 2. Plan without errors
terraform init
terraform plan

# 3. Apply in test workspace
terraform workspace new pr-test
terraform apply -auto-approve

# 4. Verify outputs
terraform output

# 5. Check state
terraform state list
terraform show

# 6. Test destroy
terraform destroy -auto-approve

# 7. Clean up
terraform workspace select default
terraform workspace delete pr-test
```

### Testing Checklist for Modules

- [ ] Module initializes without errors
- [ ] Resources are created successfully
- [ ] Outputs are correct
- [ ] Resources can be destroyed cleanly
- [ ] No state drift after apply
- [ ] Tags are applied correctly
- [ ] Dependencies resolve properly

### Example Test Configuration

Create a `test/` directory for your module:

```hcl
# test/main.tf
module "test_module" {
  source = "../"
  
  resource_parameters = {
    test1 = {
      name   = "test-resource"
      vpc_id = "vpc-test123"
    }
  }
}

output "test_output" {
  value = module.test_module.resources
}
```

---

## Style Guide

### Terraform Code Style

```hcl
# ✅ GOOD: Consistent formatting
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(
    { Name = var.vpc_name },
    var.tags
  )
}

# ❌ BAD: Inconsistent formatting
resource "aws_vpc" "main" {
cidr_block="10.0.0.0/16"
enable_dns_support=true
tags={Name=var.vpc_name}
}
```

### Variable Naming

```hcl
# ✅ GOOD: Descriptive names
variable "vpc_parameters" {}
variable "subnet_cidr_blocks" {}
variable "enable_nat_gateway" {}

# ❌ BAD: Vague names
variable "params" {}
variable "cidrs" {}
variable "enable" {}
```

### Comments

```hcl
# ✅ GOOD: Helpful comments
# Create VPC endpoints for S3 to avoid NAT Gateway costs
resource "aws_vpc_endpoint" "s3" {
  # ... configuration
}

# ❌ BAD: Obvious comments
# Create VPC endpoint
resource "aws_vpc_endpoint" "s3" {
  # ... configuration
}
```

---

## Improving Documentation

Documentation improvements are highly valued! You can contribute to:

### Main Documentation

Located in `docs/` directory:
- **GETTING_STARTED.md** - Initial setup guide
- **NETWORKING.md** - VPC, Subnets, Gateways
- **NETWORK_SECURITY.md** - Security Groups and rules
- **EKS.md** - EKS clusters and node groups
- **EXAMPLES.md** - Architecture examples
- **TROUBLESHOOTING.md** - Common issues

### Module Documentation

Each module has a `README.md` in `modules/<module>/` with:
- Overview and purpose
- Input variables table
- Output values table
- Usage examples
- Best practices

### Documentation Standards

- Use clear, concise language
- Provide practical examples
- Include cost implications
- Add troubleshooting tips
- Keep formatting consistent

---

## Questions?

If you have questions about contributing:

1. Check existing [issues](../../issues) and [discussions](../../discussions)
2. Read the [documentation](docs/)
3. Open a new [discussion](../../discussions/new)
4. Ask Here [Slack](https://theoperationhq.slack.com/?redir=%2Fgantry%2Fclient)

---

## Recognition

Contributors are recognized in:

- [Contributors page](../../graphs/contributors)
- Project documentation (for significant contributions)

**Thank you for contributing! 🎉**

---

**Built with ❤️ by the community, for the community.**
