variable "repository_names" {
  description = "ECR repository names to create (one per app image)"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "MUTABLE allows overwriting tags (e.g. latest); IMMUTABLE for digests-only workflows"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable basic image vulnerability scanning on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Repository encryption: AES256 (default, free) or KMS"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS."
  }
}

variable "lifecycle_keep_last" {
  description = "Keep the last N images; expire older ones (FinOps)"
  type        = number
  default     = 10

  validation {
    condition     = var.lifecycle_keep_last >= 1
    error_message = "lifecycle_keep_last must be at least 1."
  }
}

variable "force_delete" {
  description = "Allow destroying non-empty repositories (useful for lab teardown)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags merged onto repositories"
  type        = map(string)
  default     = {}
}
