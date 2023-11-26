terraform {
  source = "git::${local.module_url}//iam/modules/iam-assumable-role/?ref=${local.module_version}"
}

# dependency "policy" {
#   config_path = "../../iam-policy/eks-node-policy"
# }

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  module_url     = local.module_repo_vars.locals.url
  module_version = local.module_version_vars.locals.module_version
  project_name   = local.account_vars.locals.project_name
}

inputs = {
  create_role                     = true
  role_name                       = "${local.project_name}-eks-node-role"
  allow_self_assume_role          = true
  create_custom_role_trust_policy = true

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]

  custom_role_trust_policy = {
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  }
}
