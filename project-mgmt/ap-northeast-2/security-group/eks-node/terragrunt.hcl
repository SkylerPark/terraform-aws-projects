include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::${local.module_url}//security-group?ref=${local.module_version}"
}

dependency "vpc" {
  config_path = "../../vpc/project-vpc"
}

dependency "cluster_sg" {
  config_path = "../eks-cluster"
}

dependency "common_sg" {
  config_path = "../common-instance"
}

locals {
  module_repo_vars    = read_terragrunt_config(find_in_parent_folders("module_repo.hcl"))
  module_version_vars = read_terragrunt_config(find_in_parent_folders("module_version.hcl"))
  account_vars        = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars    = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  module_url     = local.module_repo_vars.locals.url
  module_version = local.module_version_vars.locals.module_version
  project_name   = local.account_vars.locals.project_name
}

inputs = {
  name   = "${local.project_name}-eks-node-sg"
  vpc_id = dependency.vpc.outputs.vpc_id

  ingress_with_security_group_id = [
    {
      description                  = "Cluster API to node groups"
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.cluster_sg.outputs.security_group_id
    },
    {
      description                  = "Cluster API to node kubelets"
      from_port                    = 10250
      to_port                      = 10250
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.cluster_sg.outputs.security_group_id
    },
    {
      description                  = "Cluster API to node 4443/tcp webhook"
      from_port                    = 4443
      to_port                      = 4443
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.cluster_sg.outputs.security_group_id
    },
    {
      description                  = "Cluster API to node 6443/tcp webhook"
      from_port                    = 6443
      to_port                      = 6443
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.cluster_sg.outputs.security_group_id
    },
    {
      description                  = "Cluster API to node 8443/tcp webhook"
      from_port                    = 8443
      to_port                      = 8443
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.cluster_sg.outputs.security_group_id
    },
    {
      description                  = "Cluster API to node 9443/tcp webhook"
      from_port                    = 9443
      to_port                      = 9443
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.cluster_sg.outputs.security_group_id
    },
    {
      description                  = "Bastion to Node groups"
      from_port                    = 22
      to_port                      = 22
      ip_protocol                  = "tcp"
      referenced_security_group_id = dependency.common_sg.outputs.security_group_id
    }
  ]
  ingress_with_self = [
    {
      description = "Node to node CoreDNS"
      from_port   = 53
      to_port     = 53
      ip_protocol = "tcp"
    },
    {
      description = "Node to node CoreDNS UDP"
      from_port   = 53
      to_port     = 53
      ip_protocol = "udp"
    },
    {
      description = "Node to node ingress on ephemeral ports"
      from_port   = 1025
      to_port     = 65535
      ip_protocol = "tcp"
    }
  ]

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
