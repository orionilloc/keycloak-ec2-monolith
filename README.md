# Keycloak Lab on AWS with Terraform

This project uses Terraform to deploy a secure, single-instance Keycloak identity and access management (IAM) server on AWS EC2. The setup includes a persistent PostgreSQL database, is fronted by Nginx, and automatically secures all traffic with Let's Encrypt SSL via Certbot.

## ✨ Architecture and Features

* Infrastructure as Code (IaC): The entire stack is provisioned by Terraform, including the VPC, Subnet, EC2 instance, IAM role, an Elastic IP (EIP), and a Route 53 A record for `auth.${var.domain_name}`.

* Security:

  * Automatic Let's Encrypt SSL/TLS for all traffic.

  * Secrets Management: Sensitive data (DB credentials, Keycloak admin password) are securely stored in AWS SSM Parameter Store.

  * Access Restriction: Both SSH access and the Keycloak `/admin` console are securely restricted in the Security Group and Nginx configuration, respectively, to the public IP address from which `terraform apply` was executed.

* Data Persistence: PostgreSQL data is stored on a dedicated AWS EBS volume, ensuring data survives instance termination or replacement.

* Networking: Configures a dedicated public subdomain, `auth.${var.domain_name}`, via Route 53 pointing to the EC2 instance's public IP.

## ⚙️ Prerequisites

1. AWS Account and CLI: Configured with access key/secret and a named profile (e.g., `dev-stamper`).

2. Terraform: Installed locally (v1.0+ recommended).

3. Registered Domain: A domain name whose Public Hosted Zone is managed by AWS Route 53.

## 🚀 Deployment

1. Configure Variables:
   Edit the `terraform.tfvars` file and update the required variables. Based on your files, here is an example:

   * `aws_profile`: Name of your configured AWS CLI profile. Example Value: `your-aws-cli-profile`

   * `domain_name`: Your root domain name (must be in Route 53). Example Value: `yourdomain.com`

   * `certbot_email`: Email for Let's Encrypt registration/notices. Example Value: `your-email@example.com`

2. Initialize and Apply:
   Run the following commands in your project root directory:

   ```bash
   terraform init      # Initialize the project
   terraform plan      # Review the planned infrastructure changes
   terraform apply     # Execute the deployment
