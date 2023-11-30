include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_url}//vpc/?ref=${local.module_version}"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars    = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  module_url          = local.module_repo_vars.locals.url
  module_version      = local.module_version_vars.locals.module_version
  project_name        = local.account_vars.locals.project_name
  environment         = local.environment_vars.locals.environment

  cidr_block = "10.70.0.0/16"
  name       = "${local.project_name}-${local.environment}"
}

inputs = {
  name                   = local.name
  cidr_block             = local.cidr_block
  create_igw             = true
  create_nat_gw          = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  route_tables = [
    {
      name       = "${local.name}-public-rt-01"
      enable_igw = true
      route      = []
    },
    {
      name          = "${local.name}-private-rt-01"
      enable_nat_gw = true
      nat_gw_az     = "ap-northeast-2a"
      route         = []
    },
    {
      name  = "${local.name}-database-rt-01"
      route = []
    }
  ]

  subnets = [
    {
      name              = "${local.name}"
      tier              = "database"
      availability_zone = "ap-northeast-2a"
      cidr_block        = cidrsubnet(local.cidr_block, 8, 11)
      route_table_name  = "${local.name}-database-rt-01"
    },
    {
      name              = "${local.name}"
      tier              = "database"
      availability_zone = "ap-northeast-2c"
      cidr_block        = cidrsubnet(local.cidr_block, 8, 12)
      route_table_name  = "${local.name}-database-rt-01"
    },
    {
      name              = "${local.name}"
      tier              = "public"
      availability_zone = "ap-northeast-2a"
      cidr_block        = cidrsubnet(local.cidr_block, 8, 21)
      route_table_name  = "${local.name}-public-rt-01"
    },
    {
      name              = "${local.name}"
      tier              = "public"
      availability_zone = "ap-northeast-2c"
      cidr_block        = cidrsubnet(local.cidr_block, 8, 22)
      route_table_name  = "${local.name}-public-rt-01"
    },
    {
      name              = "${local.name}"
      tier              = "private"
      availability_zone = "ap-northeast-2a"
      cidr_block        = cidrsubnet(local.cidr_block, 8, 51)
      route_table_name  = "${local.name}-private-rt-01"
    },
    {
      name              = "${local.name}"
      tier              = "private"
      availability_zone = "ap-northeast-2c"
      cidr_block        = cidrsubnet(local.cidr_block, 8, 52)
      route_table_name  = "${local.name}-private-rt-01"
    }
  ]

  secondary_cidr_blocks = ["100.1.0.0/16"]
  secondary_subnets = [
    {
      name              = "${local.name}"
      tier              = "secondary"
      availability_zone = "ap-northeast-2a"
      cidr_block        = "100.1.0.0/18"
    },
    {
      name              = "${local.name}"
      tier              = "secondary"
      availability_zone = "ap-northeast-2c"
      cidr_block        = "100.1.64.0/18"
    }
  ]
}
