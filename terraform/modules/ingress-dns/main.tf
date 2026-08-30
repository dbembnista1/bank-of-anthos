# Consume the public hosted zone created when the domain was registered in
# Route 53 (or created once outside this stack). terraform destroy must not
# delete the zone — it outlives this project.
data "aws_route53_zone" "this" {
  name         = var.domain
  private_zone = false
}

# Wildcard covers boa-dev.domain, boa-prod.domain, boa-grafana.domain (phase 10).
# Apex is included so a later redirect off the bare domain does not need a second certificate.
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

# Blocks until ISSUED. On a Route 53 registered domain the zone NS are already
# authoritative, so this should not wait on a manual registrar hop.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# LBC tags the shared IngressGroup ALB with stack = group.name. Lab mode (no
# domain) does not set group.name, so this lookup is only used with TLS.
data "aws_lb" "ingress" {
  count = var.manage_dns_records ? 1 : 0

  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/stack" = var.group_name
  }
}

resource "aws_route53_record" "frontend" {
  for_each = var.manage_dns_records ? toset(var.record_names) : toset([])

  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${each.value}.${var.domain}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress[0].dns_name
    zone_id                = data.aws_lb.ingress[0].zone_id
    evaluate_target_health = true
  }
}
