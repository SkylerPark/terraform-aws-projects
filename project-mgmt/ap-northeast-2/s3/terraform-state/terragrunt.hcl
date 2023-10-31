include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_repo}//s3/?ref=${local.module_version}"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  module_repo         = local.module_repo_vars.locals.module_repo
  module_version      = local.module_version_vars.locals.module_version
}

inputs = {

}
