output "security_group_id" {
  description = "Security group ID attached to all RDS instances"
  value       = aws_security_group.this.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.this.name
}

output "instance_endpoints" {
  description = "Map of logical name => RDS endpoint address (hostname)"
  value       = { for k, db in aws_db_instance.this : k => db.address }
}

output "instance_ports" {
  description = "Map of logical name => RDS port"
  value       = { for k, db in aws_db_instance.this : k => db.port }
}

output "instance_ids" {
  description = "Map of logical name => RDS instance identifier"
  value       = { for k, db in aws_db_instance.this : k => db.identifier }
}

output "db_names" {
  description = "Map of logical name => PostgreSQL database name"
  value       = { for k, db in aws_db_instance.this : k => db.db_name }
}

output "master_usernames" {
  description = "Map of logical name => master username"
  value       = { for k, db in aws_db_instance.this : k => db.username }
}

output "master_user_secret_arns" {
  description = "Map of logical name => Secrets Manager ARN for the managed master password (for ESO later)"
  value = {
    for k, db in aws_db_instance.this :
    k => try(db.master_user_secret[0].secret_arn, null)
  }
}
