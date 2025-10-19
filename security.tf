#security.tf

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

resource "tls_private_key" "keycloak" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "keycloak_lab" {
  key_name   = "keycloak-lab-key"
  public_key = tls_private_key.keycloak.public_key_openssh
}

resource "local_file" "keycloak_private_key" {
  content         = tls_private_key.keycloak.private_key_pem
  filename        = "${path.module}/keycloak-lab-key.pem"
  file_permission = "0400"
}

resource "aws_security_group" "sg_keycloak_lab" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH, HTTP, and HTTPS access"
  vpc_id      = aws_vpc.vpc_keycloak.id

  # Allow SSH from your IP only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  # Allow HTTP and HTTPS from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Project     = var.project_name
    Environment = "dev"
  }
}
