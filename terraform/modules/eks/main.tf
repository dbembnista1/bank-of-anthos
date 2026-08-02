# Thin wrapper around the community EKS module.
# Keeps root main.tf on our contract; IRSA OIDC is cluster-scoped (not GitHub OIDC).

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Required in module v20+ so the identity running Terraform can manage the cluster
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Creates IAM OIDC provider for IRSA (External Secrets, ALB Controller, etc.)
  enable_irsa = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  eks_managed_node_groups = {
    main = {
      name           = "main"
      instance_types = var.node_instance_types
      ami_type       = var.node_ami_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Nodes stay in private subnets; egress via NAT from the VPC module
      subnet_ids = var.subnet_ids
    }
  }

  tags = var.tags
}

# Cluster-owned subnet tags for AWS Load Balancer Controller discovery.
# VPC module already sets kubernetes.io/role/elb and kubernetes.io/role/internal-elb.
# Use index keys (not subnet IDs) so for_each is known at plan time when VPC is created in the same apply.
resource "aws_ec2_tag" "private_subnet_cluster" {
  for_each = { for idx, subnet_id in var.subnet_ids : tostring(idx) => subnet_id }

  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnet_cluster" {
  for_each = { for idx, subnet_id in var.public_subnet_ids : tostring(idx) => subnet_id }

  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}
