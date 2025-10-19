#main.tf

# The main provider block, configuring AWS access
provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# Data source to dynamically look up the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# The primary EC2 instance for Keycloak
resource "aws_instance" "keycloak_lab" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.keycloak_lab.key_name
  subnet_id              = aws_subnet.subnet_keycloak_public_a.id
  vpc_security_group_ids = [aws_security_group.sg_keycloak_lab.id]
  iam_instance_profile   = aws_iam_instance_profile.keycloak_profile.name
  user_data              = templatefile("${path.module}/user-data.sh", {
    project_name  = var.project_name,
    region        = var.region,
    domain_name   = "auth.${var.domain_name}",
    email_address = var.certbot_email
    admin_ip_address = "${chomp(data.http.my_ip.response_body)}"
  })

  # Configure the root volume, keeping it separate from the data volume
  root_block_device {
    volume_type = "gp3"
    volume_size = 10
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

# Separate EBS volume for Postgres data persistence
resource "aws_ebs_volume" "postgres_data" {
  availability_zone = aws_subnet.subnet_keycloak_public_a.availability_zone
  size              = 10
  type              = "gp3"

  tags = {
    Name    = "postgres-data"
    Project = var.project_name
  }
}

# Attaches the EBS volume to the EC2 instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdf" # or /dev/sdf
  volume_id   = aws_ebs_volume.postgres_data.id
  instance_id = aws_instance.keycloak_lab.id
}
