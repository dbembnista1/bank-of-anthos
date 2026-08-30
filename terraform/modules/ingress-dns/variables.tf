variable "domain" {
  description = "Existing public hosted zone name (e.g. example.com). Looked up, never created or destroyed by this module. ACM cert is issued in this stack."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (matches elbv2.k8s.aws/cluster on the LBC-managed ALB)"
  type        = string
}

variable "group_name" {
  description = "IngressGroup name (matches ingress.k8s.aws/stack and alb.ingress.kubernetes.io/group.name)"
  type        = string
  default     = "bank-of-anthos"
}

variable "record_names" {
  description = "DNS labels for alias records (e.g. boa-dev, boa-prod). Must match frontend.ingress.host without the zone."
  type        = list(string)
  default     = []
}

variable "manage_dns_records" {
  description = "Create alias A records to the grouped ALB. Set true only after the Ingress has provisioned the load balancer."
  type        = bool
  default     = false
}
