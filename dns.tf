#dns.tf

# Look up existing public hosted zone dynamically
data "aws_route53_zone" "existing" {
  name         = var.domain_name
  private_zone = false
}

# Allocate and attach Elastic IP to the EC2 instance
resource "aws_eip" "keycloak_eip" {
  instance = aws_instance.keycloak_lab.id
  tags = {
    Name = "${var.project_name}-keycloak-eip"
  }
}

# Route 53 A record for the auth subdomain
resource "aws_route53_record" "auth_subdomain" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "auth.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.keycloak_eip.public_ip]

  depends_on = [aws_eip.keycloak_eip]
}
