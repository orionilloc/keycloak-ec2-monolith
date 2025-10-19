# variables.tf

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

# Provide name of your AWS CLI profile in the "default" value field below
variable "aws_profile" {
  description = "AWS CLI profile"
  default     = "your-aws-cli-profile"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.small"
}

variable "project_name" {
  description = "Project prefix for naming resources"
  default     = "keycloak-lab"
}

variable "public_key_path" {
  description = "Optional public key path; if blank, Terraform will generate one"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name here"
  type        = string
}

variable "certbot_email" {
  description = "Email address for Certbot registration and expiration notices"
  type        = string
}
