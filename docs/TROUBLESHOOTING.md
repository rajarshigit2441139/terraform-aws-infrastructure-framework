# TROUBLESHOOTING.md
Complete Troubleshooting Guide for AWS Infrastructure

This guide provides solutions to common issues across all infrastructure modules. Issues are organized by module/component with symptoms, diagnosis, and solutions.

## Table of Contents
- [General Terraform Issues](#general-terraform-issues)
- [VPC Issues](#vpc-issues)
- [Subnet Issues](#subnet-issues)
- [Internet Gateway Issues](#internet-gateway-issues)
- [NAT Gateway Issues](#nat-gateway-issues)
- [Route Table Issues](#route-table-issues)
- [Security Group Issues](#security-group-issues)
- [EIP Issues](#eip-issues)
- [VPC Endpoint Issues](#vpc-endpoint-issues)
- [EKS Cluster Issues](#eks-cluster-issues)
- [EKS Node Group Issues](#eks-node-group-issues)
- [Connectivity Issues](#connectivity-issues)
- [Performance Issues](#performance-issues)
- [Cost Issues](#cost-issues)
- [Quick Reference: Common Commands](#quick-reference-common-commands)
- [Getting Help](#getting-help)
- [Appendix: Error Code Reference](#appendix-error-code-reference)
- [Appendix: Diagnostic Scripts](#appendix-diagnostic-scripts)
- [Appendix: Common Configuration Mistakes](#appendix-common-configuration-mistakes)
- [Preventive Measures Checklist](#preventive-measures-checklist)
- [Emergency Recovery Procedures](#emergency-recovery-procedures)
- [Monitoring and Alerting Setup](#monitoring-and-alerting-setup)

---

## General Terraform Issues

### Issue: State File Locked
**Symptoms:**
- `Error: Error acquiring the state lock`
- `ConditionalCheckFailedException`
- Lock info shows an existing apply/plan lock

**Diagnosis:**
```bash
# Check who has the lock (example for DynamoDB locking)
aws dynamodb scan --table-name terraform-state-lock \
  --filter-expression "LockID = :lockid" \
  --expression-attribute-values '{":lockid":{"S":"your-state-key"}}'
```

**Solution:**
- **Option 1: Wait** (if another apply is running)
- **Option 2: Force unlock** (only if you are sure no other terraform is running)
```bash
terraform force-unlock <LOCK_ID>

# Or manually delete from DynamoDB (last resort)
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"your-state-key"}}'
```

**Prevention:**
- Don’t run multiple `terraform apply` simultaneously
- Use CI/CD to serialize deployments

---

### Issue: Workspace Confusion
**Symptoms:**
- `lookup(var.vpc_parameters, terraform.workspace, {} ) - key not found`
- Resources appear in the wrong environment

**Diagnosis:**
```bash
terraform workspace show
terraform workspace list
```

**Solution:**
```bash
terraform workspace select default  # or qe, prod
terraform workspace show
terraform plan
```

**Prevention:**
- Verify workspace before applying
- Add workspace name to your terminal prompt

---

### Issue: Module Not Found
**Symptoms:**
- `Error: Module not installed`
- Module is not available

**Solution:**
```bash
terraform init
terraform init -upgrade
ls -la .terraform/modules/
```

---

### Issue: Provider Version Conflict
**Symptoms:**
- Provider package/version errors
- Lock file conflicts

**Solution:**
```bash
rm -rf .terraform/
rm -f .terraform.lock.hcl
terraform init
```

**Or pin the provider version (recommended)**
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

### Issue: Variable Not Defined
**Symptoms:**
- `Reference to undeclared input variable`

**Diagnosis:**
```bash
grep -r 'variable "vpc_parameters"' .
grep -r "vpc_parameters" terraform.tfvars
```

**Solution:**
- Add variable definition in `variables.tf`
- Add values in `terraform.tfvars`

---

## VPC Issues

### Issue: VPC Limit Reached
**Symptoms:**
- `VpcLimitExceeded`

**Diagnosis:**
```bash
aws ec2 describe-vpcs --query 'length(Vpcs)'
aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE
```

**Solution:**
- Delete unused VPCs, or request a quota increase
```bash
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10
```

**Default limit:** typically 5 VPCs per region.

---

### Issue: CIDR Block Invalid
**Symptoms:**
- `InvalidVpc.Range`

**Solution:**
Use private RFC1918 ranges:
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`

Common pattern:
```hcl
cidr_block = "10.0.0.0/16"
```

---

### Issue: VPC Already Exists
**Symptoms:**
- `InvalidVpc.Duplicate`

**Solution options:**
- Import existing VPC into Terraform
- Use a different key/name in configuration

---

## Subnet Issues

### Issue: Subnet CIDR Overlaps
**Symptoms:**
- `InvalidSubnet.Conflict`

**Diagnosis:**
```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query 'Subnets[*].[SubnetId,CidrBlock]' \
  --output table
```

**Solution:**
Ensure subnets are non-overlapping:
```hcl
subnet1 = { cidr_block = "10.0.1.0/24" }
subnet2 = { cidr_block = "10.0.2.0/24" }
```

---

### Issue: Availability Zone Not Available
**Symptoms:**
- AZ name does not exist in region

**Diagnosis:**
```bash
aws ec2 describe-availability-zones --region ap-south-1 \
  --query 'AvailabilityZones[*].ZoneName'
```

**Solution:**
Use `az_index` rather than hardcoding AZ names.

---

### Issue: Subnet Out of IP Addresses
**Symptoms:**
- `InsufficientFreeAddressesInSubnet`

**Diagnosis:**
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].AvailableIpAddressCount'
```

**Solution options:**
- Use a larger subnet (e.g., `/23`)
- Create additional subnets
- Clean up unused ENIs
```bash
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=subnet-xxxxx" "Name=status,Values=available"
```

---

## Internet Gateway Issues

### Issue: IGW Already Attached
**Symptoms:**
- `Resource.AlreadyAssociated`

**Diagnosis:**
```bash
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-xxxxx"
```

**Solution:**
- Import existing IGW, or detach/delete old IGW (after removing dependencies)

---

### Issue: Cannot Delete IGW
**Symptoms:**
- `DependencyViolation`

**Diagnosis:**
```bash
aws ec2 describe-route-tables \
  --filters "Name=route.gateway-id,Values=igw-xxxxx"
```

**Solution:**
Remove routes that reference the IGW, then delete IGW.

---

## NAT Gateway Issues

### Issue: NAT Gateway Creation Timeout
**Symptoms:**
- NAT stuck in `pending` or apply times out

**Diagnosis:**
```bash
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx \
  --query 'NatGateways[0].State'
```

**Solution:**
- If `pending`: retry apply after some time
- If `failed`: destroy and recreate
- Verify prerequisites: EIP exists, subnet is public, IGW attached

---

### Issue: No EIP for NAT Gateway
**Symptoms:**
- `MissingParameter` (NAT needs an EIP)

**Solution:**
Create EIP first, then NAT:
```bash
terraform apply -target=module.eip
terraform apply -target=module.nat
```

---

### Issue: NAT Gateway Not Routing Traffic
**Symptoms:**
- Private instances cannot reach internet

**Diagnosis checklist:**
- NAT is `available`
- Private RT has `0.0.0.0/0 -> NAT`
- RT is associated to private subnet
- NAT’s subnet is public and has IGW route
- SG + NACL allow outbound

---

### Issue: High NAT Gateway Costs
**Diagnosis:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-xxxxx \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

**Solutions:**
- Use VPC endpoints for S3/DynamoDB (Gateway endpoints are free)
- Consolidate NAT in non-prod
- Reduce data transfer via caching/CDN/compression

---

## Route Table Issues

### Issue: Route Already Exists
**Symptoms:**
- `RouteAlreadyExists`

**Solution:**
Remove duplicate routes and keep only one route per destination.

---

### Issue: Gateway ID Not Resolved
**Symptoms:**
- `InvalidGatewayID.NotFound`

**Solution:**
Ensure modules pass the correct IDs and `depends_on` is set so IGW/NAT are created first.

---

### Issue: Route Table Association Failed
**Symptoms:**
- `Resource.AlreadyAssociated`

**Solution:**
Disassociate the existing route table association, then apply again:
```bash
aws ec2 disassociate-route-table --association-id rtbassoc-xxxxx
terraform apply
```

---

## Security Group Issues

### Issue: Security Group Rule Limit
**Symptoms:**
- `RulesPerSecurityGroupLimitExceeded`

**Diagnosis:**
```bash
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-xxxxx" \
  --query 'length(SecurityGroupRules)'
```

**Solutions:**
- Consolidate rules (use port ranges)
- Prefer CIDR ranges over individual IPs
- Request quota increase if needed

---

### Issue: Circular SG Dependency
**Symptoms:**
- `Cycle detected in the dependency graph`

**Solution:**
Split SG creation and SG rules into separate module calls and add `depends_on` so rules apply after SGs exist.

---

### Issue: Referenced Security Group Not Found
**Symptoms:**
- `InvalidGroup.NotFound`

**Solution:**
Ensure exact key names match between SG definitions and rule references.

---

### Issue: Port Range Invalid
**Symptoms:**
- `InvalidParameterValue` for `from_port`/`to_port`

**Solution:**
- TCP/UDP: `0-65535`
- For protocol `-1`, omit ports entirely.

---

## EIP Issues

### Issue: EIP Allocation Limit
**Symptoms:**
- `AddressLimitExceeded`

**Diagnosis:**
```bash
aws ec2 describe-addresses --query 'length(Addresses)'
aws service-quotas get-service-quota --service-code ec2 --quota-code L-0263D0A3
```

**Solution:**
Release unused EIPs or request quota increase.

---

### Issue: EIP Already Associated
**Symptoms:**
- `Resource.AlreadyAssociated`

**Solution:**
Disassociate or import, then re-apply:
```bash
aws ec2 disassociate-address --association-id eipassoc-xxxxx
terraform apply
```

---

## VPC Endpoint Issues

### Issue: Interface Endpoint ENI Creation Failed
**Symptoms:**
- `InsufficientFreeAddressesInSubnet`

**Solution:**
Ensure endpoint subnets have available IPs (increase subnet size or clean up ENIs).

---

### Issue: Private DNS Not Working
**Symptoms:**
- Service resolves to public IP instead of private

**Diagnosis:**
```bash
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxx \
  --query 'VpcEndpoints[0].PrivateDnsEnabled'
aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsSupport
aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsHostnames
```

**Solution:**
Enable:
- `private_dns_enabled = true` for the endpoint
- `enableDnsSupport = true` and `enableDnsHostnames = true` on the VPC

---

### Issue: Gateway Endpoint Not Routing Traffic
**Symptoms:**
- S3/DynamoDB traffic still goes via NAT

**Diagnosis:**
Confirm the endpoint is associated with the correct route tables.

---

## EKS Cluster Issues

### Issue: Cluster Creation Timeout
**Symptoms:**
- Cluster stuck in `CREATING` > ~20 minutes

**Diagnosis:**
```bash
aws eks describe-cluster --name cluster-name --query 'cluster.status'
aws eks describe-cluster --name cluster-name --query 'cluster.health'
```

**Common causes:**
- VPC DNS disabled
- Subnets lack required routing
- IAM role permissions missing

**Solution:**
Verify DNS, subnet routing, IAM role, and security groups. If stuck, destroy and recreate cluster.

---

### Issue: Cannot Access API Endpoint
**Symptoms:**
- DNS lookup failures
- `kubectl` cannot connect

**Private-only clusters:**
- Access from within VPC via VPN/DirectConnect, bastion host, or tunnel.

**Public clusters:**
Check public access CIDRs:
```bash
aws eks describe-cluster --name cluster-name \
  --query 'cluster.resourcesVpcConfig.publicAccessCidrs'
```

---

### Issue: IAM Role Already Exists
**Symptoms:**
- `EntityAlreadyExists`

**Solution:**
Import existing role or change cluster name.

---

## EKS Node Group Issues

### Issue: Nodes Not Joining Cluster
**Symptoms:**
- Node group exists but `kubectl get nodes` shows none

**Diagnosis:**
- Nodegroup status
- Node IAM policies attached
- Cluster<->Node SG rules correct
- Subnet routing exists (NAT or endpoints)

**Solution:**
Confirm required SG rules and required IAM policies.

---

### Issue: Insufficient Capacity / Quotas
**Symptoms:**
- `ResourceLimitExceeded` for EC2

**Solution:**
Check quotas, request increases, or use different instance types.

---

### Issue: Nodes Stuck in NotReady
**Symptoms:**
- Nodes present but `NotReady`

**Diagnosis:**
```bash
kubectl describe node <node>
kubectl logs -n kube-system -l k8s-app=aws-node
```

**Common causes:**
- CNI issues
- IAM permission issues
- SG blocks pod networking
- Subnet IP exhaustion

---

## Connectivity Issues

### Issue: No Internet from Public Subnet
**Checklist:**
- IGW attached
- Public RT has `0.0.0.0/0 -> IGW`
- RT associated with subnet
- Public IP assigned (auto or EIP)
- SG/NACL allow outbound

---

### Issue: No Internet from Private Subnet
**Checklist:**
- NAT is available
- Private RT has `0.0.0.0/0 -> NAT`
- RT associated with subnet
- NAT subnet has IGW route
- SG/NACL allow outbound

---

## Performance Issues

### Issue: High Latency
Often caused by cross-AZ routing (e.g., using the wrong NAT per AZ).

**Solution:**
Use one private RT per AZ that targets the NAT in the same AZ.

---

### Issue: NAT Gateway Bandwidth / Connection Limits
**Notes (approx limits):**
- Bandwidth up to ~45 Gbps
- High concurrent connections can be a bottleneck

**Solutions:**
- One NAT per AZ
- Use VPC endpoints to bypass NAT for AWS service traffic
- Cache heavy downloads

---

## Cost Issues

### Issue: High NAT Gateway Charges
**Solutions:**
- Add VPC Gateway endpoints for S3/DynamoDB (free)
- Use interface endpoints only when ROI/compliance justifies
- Use single NAT for dev/test (accepting SPOF)

---

### Issue: Idle EIP Charges
**Diagnosis:**
```bash
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].[AllocationId,PublicIp]' \
  --output table
```

**Solution:**
Release unused EIPs to stop charges.

---

## Quick Reference: Common Commands

### Terraform
```bash
terraform workspace show
terraform workspace list
terraform workspace select prod

terraform validate
terraform fmt -recursive

terraform plan
terraform apply

terraform apply -target=module.example
terraform destroy -target=module.example

terraform state list
terraform show
terraform refresh

terraform import 'module.path.resource["key"]' aws-id
terraform force-unlock <LOCK_ID>
```

### AWS CLI
```bash
# VPC
aws ec2 describe-vpcs
aws ec2 describe-subnets
aws ec2 describe-route-tables
aws ec2 describe-security-groups
aws ec2 describe-nat-gateways
aws ec2 describe-addresses
aws ec2 describe-vpc-endpoints

# EKS
aws eks list-clusters
aws eks describe-cluster --name cluster-name
aws eks list-nodegroups --cluster-name cluster-name
aws eks describe-nodegroup --cluster-name cluster-name --nodegroup-name ng-name
aws eks update-kubeconfig --name cluster-name --region ap-south-1
```

### Kubernetes
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
kubectl describe node <node>
kubectl logs -n kube-system -l k8s-app=aws-node
```

---

## Getting Help
If troubleshooting doesn't resolve your issue:
1. Check AWS service health: https://status.aws.amazon.com/
2. Review CloudWatch logs (if enabled)
3. Enable VPC Flow Logs for network debugging
4. Contact AWS Support (if you have a support plan)

---

## Appendix: Error Code Reference

| Error Code | Meaning | Common Cause |
|------------|---------|--------------|
| `VpcLimitExceeded` | Too many VPCs | Request quota increase |
| `InvalidSubnet.Conflict` | CIDR overlap | Check subnet CIDRs |
| `AddressLimitExceeded` | Too many EIPs | Release unused EIPs |
| `RouteAlreadyExists` | Duplicate route | Remove duplicate |
| `RulesPerSecurityGroupLimitExceeded` | Too many rules | Consolidate rules |
| `ResourceLimitExceeded` | AWS quota hit | Request increase |
| `DependencyViolation` | Resource in use | Delete dependencies first |
| `InsufficientFreeAddressesInSubnet` | No IPs available | Use larger subnet |

---

## Appendix: Diagnostic Scripts

### Network Connectivity Test Script
```bash
#!/bin/bash
# network-test.sh - Comprehensive network connectivity test

echo "=== Network Connectivity Diagnostic ==="
echo ""

VPC_ID="${1}"
SUBNET_ID="${2}"
INSTANCE_ID="${3}"

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ]; then
  echo "Usage: $0 <vpc-id> <subnet-id> [instance-id]"
  exit 1
fi

echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo ""

echo "1. Checking VPC..."
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].[VpcId,CidrBlock,State]' \
  --output table

echo "2. Checking VPC DNS Settings..."
aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --query 'EnableDnsSupport.Value' --output text
aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --query 'EnableDnsHostnames.Value' --output text

echo "3. Checking Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[0].InternetGatewayId' --output text)
if [ "$IGW_ID" != "None" ]; then
  echo "✓ IGW attached: $IGW_ID"
else
  echo "✗ No IGW attached"
fi

echo "4. Checking NAT Gateways..."
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table

echo "5. Checking Subnet..."
aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" \
  --query 'Subnets[0].[SubnetId,CidrBlock,AvailableIpAddressCount,MapPublicIpOnLaunch]' \
  --output table

echo "6. Checking Route Table..."
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "Route Table: $RT_ID"
aws ec2 describe-route-tables --route-table-ids "$RT_ID" \
  --query 'RouteTables[0].Routes' --output table

if [ -n "$INSTANCE_ID" ]; then
  echo "7. Checking Instance Security Groups..."
  aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' \
    --output table
fi

echo "8. Checking Network ACLs..."
NACL_ID=$(aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
echo "NACL: $NACL_ID"
aws ec2 describe-network-acls --network-acl-ids "$NACL_ID" \
  --query 'NetworkAcls[0].Entries' --output table

echo ""
echo "=== Diagnostic Complete ==="
```

### EKS Health Check Script
```bash
#!/bin/bash
# eks-health-check.sh - EKS cluster health diagnostic

CLUSTER_NAME="${1}"

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <cluster-name>"
  exit 1
fi

echo "=== EKS Cluster Health Check: $CLUSTER_NAME ==="
echo ""

echo "1. Cluster Status..."
aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query 'cluster.[name,status,version,endpoint]' \
  --output table

echo "2. Cluster Health..."
aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query 'cluster.health' \
  --output json

echo "3. VPC Configuration..."
aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query 'cluster.resourcesVpcConfig' \
  --output json

echo "4. Node Groups..."
aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" \
  --query 'nodegroups' --output table

for ng in $(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[]' --output text); do
  echo "  Nodegroup: $ng"
  aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" \
    --query 'nodegroup.[status,scalingConfig,health]' \
    --output table
done

echo "5. Testing kubectl access..."
REGION=$(aws configure get region)
if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "✓ Kubeconfig updated"
  kubectl cluster-info >/dev/null 2>&1 && echo "✓ Cluster accessible" || echo "✗ Cannot connect to cluster"
  kubectl get nodes >/dev/null 2>&1 || echo "✗ Cannot list nodes"
else
  echo "✗ Failed to update kubeconfig"
fi

echo ""
echo "=== Health Check Complete ==="
```

### Cost Analysis Script
```bash
#!/bin/bash
# cost-analysis.sh - Simple infrastructure cost estimate (excludes EC2 usage and data transfer)

echo "=== Infrastructure Cost Analysis ==="
echo ""

echo "1. NAT Gateway (hourly only)..."
NAT_COUNT=$(aws ec2 describe-nat-gateways \
  --query 'length(NatGateways[?State==`available`])' \
  --output text)
# 0.045/hr * 24 * 30 ~= 32.40
NAT_MONTHLY=$(python3 - <<PY
print(round($NAT_COUNT * 0.045 * 24 * 30, 2))
PY
)
echo "  Active NATs: $NAT_COUNT"
echo "  Est monthly (hourly): \$$NAT_MONTHLY"

echo ""
echo "2. Idle EIPs..."
IDLE_EIPS=$(aws ec2 describe-addresses --query 'length(Addresses[?AssociationId==`null`])' --output text)
IDLE_EIP_MONTHLY=$(python3 - <<PY
print(round($IDLE_EIPS * 3.60, 2))
PY
)
echo "  Idle EIPs: $IDLE_EIPS"
echo "  Est monthly: \$$IDLE_EIP_MONTHLY"

echo ""
echo "3. EKS control plane..."
CLUSTERS=$(aws eks list-clusters --query 'length(clusters)' --output text)
EKS_MONTHLY=$(python3 - <<PY
print(round($CLUSTERS * 73, 2))
PY
)
echo "  Clusters: $CLUSTERS"
echo "  Est monthly: \$$EKS_MONTHLY"

echo ""
echo "4. Interface VPC endpoints (hourly only)..."
IF_EP=$(aws ec2 describe-vpc-endpoints --query 'length(VpcEndpoints[?VpcEndpointType==`Interface`])' --output text)
IF_EP_MONTHLY=$(python3 - <<PY
print(round($IF_EP * 7.30, 2))
PY
)
echo "  Interface endpoints: $IF_EP"
echo "  Est monthly: \$$IF_EP_MONTHLY"

echo ""
TOTAL=$(python3 - <<PY
print(round($NAT_MONTHLY + $IDLE_EIP_MONTHLY + $EKS_MONTHLY + $IF_EP_MONTHLY, 2))
PY
)
echo "=== Total (partial) monthly estimate ==="
echo "  \$$TOTAL"
echo ""
echo "Note: Excludes EC2, data transfer, and endpoint data processing."
```

### Security Audit Script
```bash
#!/bin/bash
# security-audit.sh - Quick checks for common misconfigurations

echo "=== Security Configuration Audit ==="
echo ""

echo "1. Security groups with 0.0.0.0/0 ingress..."
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].[GroupId,GroupName]' \
  --output table

echo ""
echo "2. Idle Elastic IPs..."
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].[AllocationId,PublicIp]' \
  --output table

echo ""
echo "3. VPC Flow Logs coverage..."
for vpc in $(aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' --output text); do
  count=$(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$vpc" --query 'length(FlowLogs)' --output text)
  if [ "$count" -eq 0 ]; then
    echo "⚠ No flow logs for $vpc"
  else
    echo "✓ Flow logs enabled for $vpc"
  fi
done

echo ""
echo "4. EKS endpoint exposure..."
for c in $(aws eks list-clusters --query 'clusters[]' --output text); do
  pub=$(aws eks describe-cluster --name "$c" --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text)
  priv=$(aws eks describe-cluster --name "$c" --query 'cluster.resourcesVpcConfig.endpointPrivateAccess' --output text)
  echo "$c: public=$pub private=$priv"
done

echo ""
echo "=== Audit Complete ==="
```

---

## Appendix: Common Configuration Mistakes

### 1) Wrong Workspace
```bash
terraform workspace show
terraform workspace select default
terraform apply
```

### 2) Missing Dependencies
```hcl
module "nat" {
  source     = "./modules/nat"
  depends_on = [module.eip, module.igw]
}
```

### 3) Hardcoded IDs
Avoid hardcoding AWS IDs across workspaces. Use computed lookups/outputs instead.

### 4) Missing Workspace-Specific Config
Ensure each workspace has its config block (`default`, `qe`, `prod`) where required.

### 5) Security Group Rules Before SG Creation
Create SGs first, then SG rules (or separate modules with `depends_on`).

### 6) Allowing All Ingress Traffic
Never allow `0.0.0.0/0` with `protocol = "-1"` for app SGs.

### 7) Public subnet without IGW route
Public subnet must be associated with an RT that routes `0.0.0.0/0 -> IGW`.

### 8) Cross-AZ NAT routing
Private subnets in AZ2 should use NAT in AZ2 to avoid cross-AZ costs and latency.

---

## Preventive Measures Checklist

### Pre-deployment
```bash
terraform workspace show
terraform validate
terraform fmt -check -recursive
terraform plan | tee plan.txt

grep -i "destroy" plan.txt
grep -i "replace" plan.txt

terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate
```

### Post-deployment
```bash
terraform output
./scripts/network-test.sh <vpc-id> <subnet-id> [instance-id]
./scripts/eks-health-check.sh <cluster-name>
./scripts/security-audit.sh
./scripts/cost-analysis.sh
```

---

## Emergency Recovery Procedures

### Complete Infrastructure Failure
1) Assess:
```bash
terraform state list
terraform show
aws ec2 describe-vpcs
```

2) Restore state backup (if available), then:
```bash
terraform refresh
terraform plan
```

3) Rebuild or import resources if state is missing.

---

### Partial State Corruption (AWS resources intact)
- Backup corrupt state
- Re-import critical resources
- Confirm `terraform plan` is clean

---

## Monitoring and Alerting Setup

### CloudWatch alarms (examples)
```bash
# NAT Gateway connection limit (example thresholds)
aws cloudwatch put-metric-alarm \
  --alarm-name nat-gateway-connection-limit \
  --alarm-description "Alert when NAT Gateway nears connection limit" \
  --metric-name ActiveConnectionCount \
  --namespace AWS/NATGateway \
  --statistic Maximum \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 50000 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=NatGatewayId,Value=nat-xxxxx

# Subnet IP exhaustion: many teams alert from tooling that polls AvailableIpAddressCount.
# EKS scaling alarms: validate metric/namespace for your setup before using in production.
```

---

**Last Updated:** 2025-01-16  
**Version:** 1.0  

