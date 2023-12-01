include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_url}//eks/?ref=${local.module_version}"
}

dependency "iam_eks_cluster_role" {
  config_path = "../../../global/iam-assumable-role/eks-cluster-role"
}

dependency "iam_eks_node_role" {
  config_path = "../../../global/iam-assumable-role/eks-node-role"
}

dependency "iam_iac_role" {
  config_path = "../../../global/iam-assumable-role/iac-role"
}

dependency "kms" {
  config_path = "../../kms/eks-cluster"
}

dependency "vpc" {
  config_path = "../../vpc/project-vpc"
}

dependency "key_pair" {
  config_path = "../../ec2-key-pair/project-key-pair"
}

dependency "eks_cluster_sg" {
  config_path = "../../security-group/eks-cluster"
}

dependency "eks_node_sg" {
  config_path = "../../security-group/eks-node"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars    = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  init_config_vars    = read_terragrunt_config(find_in_parent_folders("init_config.hcl"))

  module_url     = local.module_repo_vars.locals.url
  module_version = local.module_version_vars.locals.module_version
  project_name   = local.account_vars.locals.project_name
  environment    = local.environment_vars.locals.environment

  role_name    = local.init_config_vars.locals.role_name
  profile_name = local.init_config_vars.locals.profile_name
  account_id   = local.account_vars.locals.account_id

  common_vars = read_terragrunt_config("${dirname(find_in_parent_folders())}/_common/variables/common.hcl")
  admin_users = local.common_vars.locals.admin_users
}

inputs = {
  name                           = "${local.project_name}-eks"
  cluster_version                = "1.28"
  cluster_enabled_log_types      = []
  iam_role_arn                   = dependency.iam_eks_cluster_role.outputs.iam_role_arn
  cluster_security_group_ids     = [dependency.eks_cluster_sg.outputs.security_group_id]
  cluster_endpoint_public_access = true
  control_plane_subnet_ids       = concat([for k, v in dependency.vpc.outputs.subnets : v.id if v.tier == "public"], [for k, v in dependency.vpc.outputs.subnets : v.id if v.tier == "private"])
  subnet_ids                     = [for k, v in dependency.vpc.outputs.subnets : v.id if v.tier == "private"]
  enable_secondary_subnet        = true
  secondary_subnets              = dependency.vpc.outputs.secondary_subnets
  cluster_encryption_config = {
    provider_key_arn = dependency.kms.outputs.key_arn
    resources        = ["secrets"]
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
          WARM_ENI_TARGET                    = "2"
          MINIMUM_IP_TARGET                  = "12"
          ENABLE_PREFIX_DELEGATION           = "true"
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
        }
      })
    }
  }

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = dependency.iam_iac_role.outputs.iam_role_arn
      username = dependency.iam_iac_role.outputs.iam_role_name
      groups   = ["system:masters"]
    },
  ]

  aws_auth_users = [
    for user in local.admin_users : {
      userarn  = "arn:aws:iam::${local.account_id}:user/${user}"
      username = "${user}"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_accounts = ["${local.account_id}"]

  eks_managed_node_group_defaults = {
    vpc_security_group_ids     = [dependency.eks_node_sg.outputs.security_group_id]
    enable_bootstrap_user_data = true
    bootstrap_extra_args       = "--use-max-pods false --kubelet-extra-args '--max-pods=110'"
  }
  eks_managed_node_groups = {
    v1 = {
      name           = "${local.project_name}-eks-node"
      min_size       = 2
      max_size       = 2
      desired_size   = 2
      iam_role_arn   = dependency.iam_eks_node_role.outputs.iam_role_arn
      key_name       = dependency.key_pair.outputs.key_pair_name
      instance_types = ["t4g.medium"]
      ami_type       = "AL2_ARM_64"
      capacity_type  = "SPOT"
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      tag_specifications = ["instance", "network-interface", "volume", "spot-instances-request"]
    }
  }
}
