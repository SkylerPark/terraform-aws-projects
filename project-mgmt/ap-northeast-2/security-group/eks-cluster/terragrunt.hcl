include "root" {
  path = find_in_parent_folders()
}

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

  common_vars = read_terragrunt_config("${dirname(find_in_parent_folders("module_repo.hcl"))}/_common/variables/common.hcl")
  addresses   = local.common_vars.locals.addresses
}

inputs = {
  name   = "${local.project_name}-eks-cluster-sg"
  vpc_id = dependency.vpc.outputs.vpc_id

  ingress_with_cidr_ipv4 = concat([
    for k, v in dependency.vpc.outputs.subnets : {
      description = "Node groups to cluster API"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = v.cidr_block
    } if v.tier == "private"
    ],
    [
      for ip in local.addresses : {
        description = "HQ to cluster API"
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    ],
    [
      for k, v in dependency.vpc.outputs.secondary_subnets : {
        description = "Node groups to cluster API"
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        cidr_ipv4   = v.cidr_block
      } if v.tier == "secondary"
  ])
  egress_with_cidr_ipv4 = [
    {
      description = "Allow all egress"
      from_port   = "-1"
      to_port     = "-1"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  ]
}
