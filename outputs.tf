#outputs.tf

output "ec2_public_ip" {
  description = "Public IP of Keycloak EC2 instance (Elastic IP)"
  value       = aws_eip.keycloak_eip.public_ip
}

output "keycloak_url" {
  description = "Keycloak UI URL (via HTTPS and DNS)"
  value       = "https://auth.${var.domain_name}"
}

output "private_key_path" {
  description = "Path to the generated private key"
  value       = local_file.keycloak_private_key.filename
}
