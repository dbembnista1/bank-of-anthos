output "zone_id" {
  description = "ID of the existing public hosted zone (looked up, not created)"
  value       = data.aws_route53_zone.this.zone_id
}

output "zone_arn" {
  description = "ARN of the existing public hosted zone (IRSA for ExternalDNS)"
  value       = data.aws_route53_zone.this.arn
}

output "name_servers" {
  description = "Nameservers of the existing hosted zone (already set when the domain was registered in Route 53)"
  value       = data.aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN (available only after DNS validation succeeds)"
  value       = aws_acm_certificate_validation.this.certificate_arn
}
