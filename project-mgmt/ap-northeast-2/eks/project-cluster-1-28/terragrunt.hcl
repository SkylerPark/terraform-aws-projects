include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_url}//eks/?ref=${local.module_version}"
}

dependency "iam_role" {
  config_path = "../../../global/iam-assumable-role/eks-cluster-role"
}

dependency "kms" {
  config_path = "../../kms/eks-cluster"
}

dependency "vpc" {
  config_path = "../../vpc/project-vpc"
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
  name                      = "${local.project_name}-eks"
  cluster_version           = "1.28"
  cluster_enabled_log_types = []
  iam_role_arn              = dependency.iam_role.outputs.iam_role_arn
  control_plane_subnet_ids  = [for k, v in dependency.vpc.outputs.subnets : v.id if v.tier == "private"]
  cluster_encryption_config = {
    provider_key_arn = dependency.kms.outputs.key_arn
    resources        = ["secrets"]
  }
}
