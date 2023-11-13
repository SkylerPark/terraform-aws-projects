terraform {
  source = "git::${local.module_url}//iam/modules/iam-policy/?ref=${local.module_version}"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  module_url     = local.module_repo_vars.locals.url
  module_version = local.module_version_vars.locals.module_version
  project_name   = local.account_vars.locals.project_name
  account_name   = local.account_vars.locals.account_name

  common_vars = read_terragrunt_config("${dirname(find_in_parent_folders())}/_common/variables/common.hcl")
  addresses   = local.common_vars.locals.addresses
}

inputs = {
  name        = "${local.project_name}-iac-policy"
  path        = "/"
  description = ""
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "VisualEditor0",
          "Effect" : "Allow",
          "Action" : "*",
          "Resource" : "*",
          "Condition" : {
            "Bool" : {
              "aws:ViaAWSService" : "false"
            },
            "IpAddress" : {
              "aws:SourceIp" : "${local.addresses}"
            }
          }
        }
      ]
    }
  )
}
