# secrets.tf

# Postgres DB user
resource "aws_ssm_parameter" "db_user" {
  name      = "/${var.project_name}/db-user"
  type      = "SecureString"
  value     = "keycloak_db_user"
  overwrite = true
  tags      = { "project" = var.project_name }
  key_id    = "alias/aws/ssm"
}

# Postgres DB password
resource "random_password" "db_password" {
  length  = 20
  upper   = true
  lower   = true
  numeric = true
  special = true
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/${var.project_name}/db-password"
  type      = "SecureString"
  value     = random_password.db_password.result
  overwrite = true
  tags      = { "project" = var.project_name }
  key_id    = "alias/aws/ssm"
}

# Keycloak admin username
resource "aws_ssm_parameter" "kc_admin_user" {
  name      = "/${var.project_name}/admin-user"
  type      = "SecureString"
  value     = "admin"
  overwrite = true
  tags      = { "project" = var.project_name }
  key_id    = "alias/aws/ssm"
}

# Keycloak admin password
resource "random_password" "kc_admin_password" {
  length  = 20
  upper   = true
  lower   = true
  numeric = true
  special = true
}

resource "aws_ssm_parameter" "kc_admin_password" {
  name      = "/${var.project_name}/admin-password"
  type      = "SecureString"
  value     = random_password.kc_admin_password.result
  overwrite = true
  tags      = { "project" = var.project_name }
  key_id    = "alias/aws/ssm"
}
