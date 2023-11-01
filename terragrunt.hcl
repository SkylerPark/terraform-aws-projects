locals {
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  init_config_vars = read_terragrunt_config(find_in_parent_folders("init_config.hcl"))
  region           = local.region_vars.locals.region
  environment      = local.environment_vars.locals.environment
  bucket           = local.init_config_vars.locals.bucket
  dynamodb_table   = local.init_config_vars.locals.dynamodb_table
  role_name        = local.init_config_vars.locals.role_name
  profile_name     = local.init_config_vars.locals.profile_name
  account_id       = local.account_vars.locals.account_id
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket                         = "${local.bucket}"
    key                            = "${path_relative_to_include()}/terraform.tfstate"
    region                         = "ap-northeast-2"
    profile                        = "${local.profile_name}"
    encrypt                        = true
    dynamodb_table                 = "${local.dynamodb_table}"
    enable_lock_table_ssencryption = true
    skip_bucket_root_access        = true
    skip_bucket_enforced_tls       = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  profile = "${local.profile_name}"
  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/${local.role_name}"
  }
}
EOF
}
