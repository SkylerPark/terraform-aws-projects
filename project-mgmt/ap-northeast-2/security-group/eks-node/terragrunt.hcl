terraform {
  source = "git::${local.module_url}//security-group?ref=${local.module_version}"
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
  name   = "${local.project_name}-eks-node-sg"
  vpc_id = dependency.vpc.outputs.vpc_id

  ingress_with_cidr_ipv4 = [
    {
      description = "test"
      from_port   = 22
      to_port     = 22
      ip_protocol = "TCP"
      cidr_ipv4   = ip
    }
  ]
}
