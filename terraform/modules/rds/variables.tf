variable "name_prefix" {
  description = "Prefix for RDS resource names (subnet group, security group, instances)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS instances are placed"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (minimum 2 AZs)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must include at least two subnets in different AZs."
  }
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect on the DB port (typically EKS node SG)"
  type        = list(string)

  validation {
    condition     = length(var.allowed_security_group_ids) >= 1
    error_message = "allowed_security_group_ids must include at least one security group."
  }
}

variable "instances" {
  description = "Map of RDS PostgreSQL instances (key = \"<env>-<service>\", e.g. dev-accounts)"
  type = map(object({
    identifier = string
    db_name    = string
    username   = string
  }))

  validation {
    condition = alltrue([
      for k, v in var.instances :
      can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", v.db_name))
    ])
    error_message = "Each db_name must start with a letter and contain only alphanumeric characters or underscores (RDS constraint)."
  }

  validation {
    condition = alltrue([
      for k, v in var.instances :
      can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", v.username))
    ])
    error_message = "Each username must start with a letter and contain only alphanumeric characters or underscores (RDS constraint)."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.14"
}

variable "instance_class" {
  description = "RDS instance class (db.t4g.micro for lab FinOps)"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for PostgreSQL on RDS."
  }
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling (0 disables autoscaling)"
  type        = number
  default     = 0
}

variable "storage_type" {
  description = "Storage type (gp3 recommended)"
  type        = string
  default     = "gp3"
}

variable "port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Enable Multi-AZ (higher cost; default false for lab)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to retain automated backups (0 disables)"
  type        = number
  default     = 1

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "deletion_protection" {
  description = "Prevent accidental deletion (disable for lab teardown)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (lab teardown convenience)"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of during the next maintenance window"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags merged onto RDS resources"
  type        = map(string)
  default     = {}
}
