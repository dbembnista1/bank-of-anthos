output "zone_id" {
  description = "ID of the existing public hosted zone (looked up, not created)"
  value       = data.aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Nameservers of the existing hosted zone (already set when the domain was registered in Route 53)"
  value       = data.aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN (available only after DNS validation succeeds)"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "alb_dns_name" {
  description = "DNS name of the grouped ALB (null until manage_dns_records is true)"
  value       = try(data.aws_lb.ingress[0].dns_name, null)
}
