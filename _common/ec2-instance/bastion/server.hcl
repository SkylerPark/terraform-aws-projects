terraform {
  source = "git::${local.module_url}//ec2-instance?ref=${local.module_version}"
}

dependency "key_pair" {
  config_path = "../../ec2-key-pair/project-key-pair"
}

dependency "common_sg" {
  config_path = "../../security-group/common-instance"
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

  num_instances = {
    mgmt = ["01"]
  }

  instance_type = {
    mgmt = "t2.micro"
  }

  service_code  = "bastion"
  identity_code = "server"
}

inputs = {
  num_instances               = local.num_instances[local.environment]
  name                        = "${local.project_name}-${local.service_code}-${local.identity_code}"
  availability_zones          = ["ap-northeast-2a", "ap-northeast-2c"]
  subnet_name                 = "public"
  instance_type               = local.instance_type[local.environment]
  ignore_ami_changes          = true
  ignore_subnet_changes       = true
  associate_public_ip_address = true
  monitoring                  = false
  enable_eip                  = true
  key_name                    = dependency.key_pair.outputs.key_pair_name
  vpc_security_group_ids      = [dependency.common_sg.outputs.security_group_id]

  metadata_options = {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
    instance_metadata_tags      = "enabled"
  }

  root_block_device = [
    {
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "gp3"
    }
  ]

  ebs_block_device = [
    {
      name                  = "game"
      device_name           = "/dev/sdb"
      delete_on_termination = true
      volume_size           = 10
      volume_type           = "gp3"
    }
  ]
}
