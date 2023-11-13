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
}

dependency "iac_policy" {
  config_path = "../../iam-policy/iac-policy"
}

inputs = {
  create_role       = true
  role_name         = "${local.project_name}-iac-role"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::${local.manage_account_id}:user/${local.project_name}-iac"
  ]

  custom_role_policy_arns = [
    dependency.iac_policy.outputs.arn
  ]
}
