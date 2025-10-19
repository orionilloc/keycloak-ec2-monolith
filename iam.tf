# iam.tf

data "aws_caller_identity" "current" {}

# IAM Role and Policy to allow the EC2 instance to read secrets from SSM Parameter Store
resource "aws_iam_role" "ec2_ssm_role" {
  name               = "${var.project_name}-ec2-ssm-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Policy to read secrets from SSM Parameter Store and decrypt them
resource "aws_iam_policy" "ssm_read_policy" {
  name = "${var.project_name}-ssm-read-policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
      },
      {
        "Effect": "Allow",
        "Action": "kms:Decrypt",
        "Resource": [
          "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"
        ]
      }
    ]
  })
}

# Attach the SSM read policy to the IAM role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ssm_read_policy.arn
}

# Attach the SSM core managed policy for Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile to attach the role to the EC2 instance
resource "aws_iam_instance_profile" "keycloak_profile" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
