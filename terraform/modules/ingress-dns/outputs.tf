output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Nameservers to delegate at the domain registrar (required for ACM validation)"
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN (available only after DNS validation succeeds)"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "alb_dns_name" {
  description = "DNS name of the grouped ALB (null until manage_dns_records is true)"
  value       = try(data.aws_lb.ingress[0].dns_name, null)
}
