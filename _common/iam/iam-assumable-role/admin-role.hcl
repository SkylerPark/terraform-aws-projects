terraform {
  source = "git::${local.module_url}//iam/modules/iam-assumable-role/?ref=${local.module_version}"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  module_url     = local.module_repo_vars.locals.url
  module_version = local.module_version_vars.locals.module_version
  project_name   = local.account_vars.locals.project_name
  account_name   = local.account_vars.locals.account_name

  common_vars       = read_terragrunt_config("${dirname(find_in_parent_folders("module_repo.hcl"))}/_common/variables/common.hcl")
  manage_account_id = local.common_vars.locals.manage_account_id
  admin_users       = local.common_vars.locals.admin_users
}

dependency "admin_policy" {
  config_path = "../admin-policy"
}

inputs = {
  create_role       = true
  role_name         = "${local.project_name}-admin-role"
  role_requires_mfa = true

  trusted_role_arns = [for user in local.admin_users : "arn:aws:iam::${local.manage_account_id}:user/${user}"]

  custom_role_policy_arns = [
    dependency.admin_policy.outputs.arn
  ]
}
