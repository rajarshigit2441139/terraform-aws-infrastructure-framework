# EKS Cluster Child Module
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

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  for_each   = var.eks_clusters
  role       = aws_iam_role.eks_cluster[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_controller" {
  for_each   = var.eks_clusters
  role       = aws_iam_role.eks_cluster[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_eks_cluster" "cluster" {
  for_each = var.eks_clusters
  name     = each.key
  role_arn = aws_iam_role.eks_cluster[each.key].arn
  version  = each.value.cluster_version

  vpc_config {
    subnet_ids              = each.value.subnet_ids
    endpoint_private_access = each.value.endpoint_private_access
    endpoint_public_access  = each.value.endpoint_public_access
    security_group_ids      = each.value.security_group_ids #[aws_security_group.cluster_sg[each.key].id]
  }
  tags = merge(each.value.tags, {
    Name : each.key
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags] # Ignore changes to tags to avoid unnecessary updates
  }

  depends_on = [
    aws_iam_role.eks_cluster, #N
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_controller
  ]
}
