variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane (major.minor)"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster and nodes run"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for worker nodes (and control plane ENIs if control_plane_subnet_ids is empty)"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to tag for the cluster (needed later by AWS Load Balancer Controller)"
  type        = list(string)
  default     = []
}

variable "cluster_endpoint_public_access" {
  description = "Expose the Kubernetes API publicly (needed for local kubectl; keep private access enabled too)"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Expose the Kubernetes API inside the VPC"
  type        = bool
  default     = true
}

variable "github_actions_role_name" {
  description = "IAM role name created by bootstrap OIDC (CI). Empty = <cluster_name>-github-oidc-role."
  type        = string
  default     = ""
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_ami_type" {
  description = "AMI type for managed nodes (AL2023 is default for EKS 1.30+)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "tags" {
  description = "Additional tags merged onto resources created by this module"
  type        = map(string)
  default     = {}
}
