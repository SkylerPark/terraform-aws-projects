include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_url}//dynamodb/?ref=${local.module_version}"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  module_url          = local.module_repo_vars.locals.url
  module_version      = local.module_version_vars.locals.module_version
  project_name        = local.account_vars.locals.project_name
}

inputs = {
  name           = "test"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attributes = [
    {
      name = "LockID"
      type = "S"
    }
  ]
}
