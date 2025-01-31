data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret" "secrets" {
  arn = var.secret_manager_arn
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

locals {
    account_id = data.aws_caller_identity.current.account_id
}

output "account_id" {
  value = local.account_id
}

