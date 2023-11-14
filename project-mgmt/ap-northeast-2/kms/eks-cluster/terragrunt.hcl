include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_url}//kms/?ref=${local.module_version}"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars    = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  module_url     = local.module_repo_vars.locals.url
  module_version = local.module_version_vars.locals.module_version
  project_name   = local.account_vars.locals.project_name
  environment    = local.environment_vars.locals.environment
}

inputs = {
  description         = "${local.project_name}-eks-${local.environment} cluster encryption key"
  key_usage           = "ENCRYPT_DECRYPT"
  enable_key_rotation = true

  computed_aliases = {
    cluster = { name = "eks/${local.project_name}-eks-${local.environment}" }
  }
}
