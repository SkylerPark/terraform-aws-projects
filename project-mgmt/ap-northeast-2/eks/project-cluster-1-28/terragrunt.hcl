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
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--profile", "${local.profile_name}", "--role-arn", "arn:aws:iam::${local.account_id}:role/${local.role_name}"]
  }
}
EOF
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
    }
  }

  create_aws_auth_configmap               = true
  aws_auth_node_iam_role_arns_non_windows = ["arn:aws:iam::497712261737:role/moham-iac-role"]
  aws_auth_users                          = ["parksm"]
  aws_auth_accounts                       = ["497712261737"]

  eks_managed_node_group_defaults = {
    vpc_security_group_ids     = [dependency.eks_node_sg.outputs.security_group_id]
    enable_bootstrap_user_data = true
  }
  eks_managed_node_groups = {
    v1 = {
      name           = "${local.project_name}-eks-api"
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
