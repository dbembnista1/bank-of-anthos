# Kubernetes and Helm talk to the shared EKS cluster (ArgoCD bootstrap and later addons).
# Exec auth refreshes tokens during long applies; static aws_eks_cluster_auth tokens expire (~15m).
# Always assume the cluster-admin role so laptop (IAM user) and GHA (OIDC role) use the same
# EKS access entry — get-token without --role-arn is the caller's identity, which has no entry.

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region,
      "--role-arn",
      module.eks.cluster_admin_role_arn,
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region,
        "--role-arn",
        module.eks.cluster_admin_role_arn,
      ]
    }
  }
}
