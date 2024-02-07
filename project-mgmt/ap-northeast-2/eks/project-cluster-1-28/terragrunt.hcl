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

dependency "iam_eks_karpenter_role" {
  config_path = "../../../../global/env-common/iam/karpenter-role"
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
  ################################################################################
  # EKS Cluster 
  ################################################################################

  name                           = "${local.project_name}-eks"
  cluster_version                = "1.29"
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
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  ################################################################################
  # EKS Auth Configmap
  ################################################################################

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = dependency.iam_iac_role.outputs.iam_role_arn
      username = dependency.iam_iac_role.outputs.iam_role_name
      groups   = ["system:masters"]
    },
    # {
    #   rolearn  = dependency.iam_eks_karpenter_role.outputs.iam_role_arn
    #   username = "system:node:{{EC2PrivateDNSName}}"
    #   groups = [
    #     "system:bootstrappers",
    #     "system:nodes",
    #   ]
    # }
  ]

  aws_auth_users = [
    for user in local.admin_users : {
      userarn  = "arn:aws:iam::${local.account_id}:user/${user}"
      username = "${user}"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_accounts = ["${local.account_id}"]

  ################################################################################
  # EKS Managed Node Group
  ################################################################################

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

  ################################################################################
  # EKS Fargate Profile
  ################################################################################

  fargate_profile_defaults = {
    iam_role_arn = dependency.iam_eks_fargate_role.outputs.iam_role_arn
  }
  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }


  ################################################################################
  # AWS Load Balancer Controller
  ################################################################################

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    policy_document = jsonencode(
      {
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Effect" : "Allow",
            "Action" : [
              "iam:CreateServiceLinkedRole"
            ],
            "Resource" : "*",
            "Condition" : {
              "StringEquals" : {
                "iam:AWSServiceName" : "elasticloadbalancing.amazonaws.com"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ec2:DescribeAccountAttributes",
              "ec2:DescribeAddresses",
              "ec2:DescribeAvailabilityZones",
              "ec2:DescribeInternetGateways",
              "ec2:DescribeVpcs",
              "ec2:DescribeVpcPeeringConnections",
              "ec2:DescribeSubnets",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeInstances",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DescribeTags",
              "ec2:GetCoipPoolUsage",
              "ec2:DescribeCoipPools",
              "elasticloadbalancing:DescribeLoadBalancers",
              "elasticloadbalancing:DescribeLoadBalancerAttributes",
              "elasticloadbalancing:DescribeListeners",
              "elasticloadbalancing:DescribeListenerCertificates",
              "elasticloadbalancing:DescribeSSLPolicies",
              "elasticloadbalancing:DescribeRules",
              "elasticloadbalancing:DescribeTargetGroups",
              "elasticloadbalancing:DescribeTargetGroupAttributes",
              "elasticloadbalancing:DescribeTargetHealth",
              "elasticloadbalancing:DescribeTags"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "cognito-idp:DescribeUserPoolClient",
              "acm:ListCertificates",
              "acm:DescribeCertificate",
              "iam:ListServerCertificates",
              "iam:GetServerCertificate",
              "waf-regional:GetWebACL",
              "waf-regional:GetWebACLForResource",
              "waf-regional:AssociateWebACL",
              "waf-regional:DisassociateWebACL",
              "wafv2:GetWebACL",
              "wafv2:GetWebACLForResource",
              "wafv2:AssociateWebACL",
              "wafv2:DisassociateWebACL",
              "shield:GetSubscriptionState",
              "shield:DescribeProtection",
              "shield:CreateProtection",
              "shield:DeleteProtection"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ec2:CreateSecurityGroup"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ec2:CreateTags"
            ],
            "Resource" : "arn:aws:ec2:*:*:security-group/*",
            "Condition" : {
              "StringEquals" : {
                "ec2:CreateAction" : "CreateSecurityGroup"
              },
              "Null" : {
                "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ec2:CreateTags",
              "ec2:DeleteTags"
            ],
            "Resource" : "arn:aws:ec2:*:*:security-group/*",
            "Condition" : {
              "Null" : {
                "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
                "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:RevokeSecurityGroupIngress",
              "ec2:DeleteSecurityGroup"
            ],
            "Resource" : "*",
            "Condition" : {
              "Null" : {
                "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:CreateLoadBalancer",
              "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource" : "*",
            "Condition" : {
              "Null" : {
                "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:CreateListener",
              "elasticloadbalancing:DeleteListener",
              "elasticloadbalancing:CreateRule",
              "elasticloadbalancing:DeleteRule"
            ],
            "Resource" : "*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:AddTags",
              "elasticloadbalancing:RemoveTags"
            ],
            "Resource" : [
              "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition" : {
              "Null" : {
                "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
                "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:AddTags",
              "elasticloadbalancing:RemoveTags"
            ],
            "Resource" : [
              "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
              "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
              "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
              "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:ModifyLoadBalancerAttributes",
              "elasticloadbalancing:SetIpAddressType",
              "elasticloadbalancing:SetSecurityGroups",
              "elasticloadbalancing:SetSubnets",
              "elasticloadbalancing:DeleteLoadBalancer",
              "elasticloadbalancing:ModifyTargetGroup",
              "elasticloadbalancing:ModifyTargetGroupAttributes",
              "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource" : "*",
            "Condition" : {
              "Null" : {
                "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:AddTags"
            ],
            "Resource" : [
              "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
              "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition" : {
              "StringEquals" : {
                "elasticloadbalancing:CreateAction" : [
                  "CreateTargetGroup",
                  "CreateLoadBalancer"
                ]
              },
              "Null" : {
                "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
              }
            }
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:RegisterTargets",
              "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource" : "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
          },
          {
            "Effect" : "Allow",
            "Action" : [
              "elasticloadbalancing:SetWebAcl",
              "elasticloadbalancing:ModifyListener",
              "elasticloadbalancing:AddListenerCertificates",
              "elasticloadbalancing:RemoveListenerCertificates",
              "elasticloadbalancing:ModifyRule"
            ],
            "Resource" : "*"
          }
        ]
      }
    )
    set = [
      {
        name  = "serviceAccount.create"
        value = "true"
      },
      {
        name  = "region"
        value = local.region
      },
      {
        name  = "vpcId"
        value = dependency.vpc.outputs.vpc_id
      },
      {
        name  = "image.repository"
        value = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller"
      }
    ]
  }

  ################################################################################
  # Karpenter
  ################################################################################

  enable_karpenter = true
  karpenter = {
    default_instance_profile = dependency.iam_eks_karpenter_role.outputs.iam_instance_profile_id
    policy_document = jsonencode(
      {
        "Statement" : [
          {
            "Action" : [
              "ssm:GetParameter",
              "iam:PassRole",
              "ec2:DescribeImages",
              "ec2:RunInstances",
              "ec2:DescribeSubnets",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeLaunchTemplates",
              "ec2:DescribeInstances",
              "ec2:DescribeInstanceTypes",
              "ec2:DescribeInstanceTypeOfferings",
              "ec2:DescribeAvailabilityZones",
              "ec2:DeleteLaunchTemplate",
              "ec2:CreateTags",
              "ec2:CreateLaunchTemplate",
              "ec2:CreateFleet",
              "ec2:DescribeSpotPriceHistory",
              "pricing:GetProducts"
            ],
            "Effect" : "Allow",
            "Resource" : "*",
            "Sid" : "Karpenter"
          },
          {
            "Action" : "ec2:TerminateInstances",
            "Condition" : {
              "StringLike" : {
                "ec2:ResourceTag/Name" : "*${local.project_name}"
              }
            },
            "Effect" : "Allow",
            "Resource" : "*",
            "Sid" : "ConditionalEC2Termination"
          }
        ],
        "Version" : "2012-10-17"
      }
    )
    node_template = {
      ami_family                   = "AL2"
      volume_size                  = "50G"
      volume_type                  = "gp3"
      volume_iops                  = 3000
      volume_throughput            = 125
      volume_delete_on_termination = true
    }
    provisioner_requirements = {
      "karpenter.k8s.aws/instance-family" = {
        operator = "In"
        values   = ["c5", "m5", "r5"]
      }
      "karpenter.k8s.aws/instance-size" = {
        operator = "NotIn"
        values   = ["nano", "micro", "small", "large"]
      }
      "topology.kubernetes.io/zone" = {
        operator = "In"
        values   = ["ap-northeast-2a", "ap-northeast-2c"]
      }
      "karpenter.sh/capacity-type" = {
        operator = "In"
        values   = ["on-demand"]
      }
      "kubernetes.io/os" = {
        operator = "In"
        values   = ["linux"]
      }
      "kubernetes.io/arch" = {
        operator = "In"
        values   = ["amd64"]
      }
    }
  }

  ################################################################################
  # argo rollouts
  ################################################################################

  enable_argo_rollouts = true
  argo_rollouts = {
    values = ["${file("argo-rollouts-values.yaml")}"]
  }

  ################################################################################
  # ArgoCD
  ################################################################################

  enable_argocd = true
  argocd = {
    set = [
      {
        name  = "redis-ha.enabled"
        value = "true"
      },
      {
        name  = "controller.replicas"
        value = 1
      },
      {
        name  = "server.replicas"
        value = 2
      },
      {
        name  = "repoServer.replicas"
        value = 2
      },
      {
        name  = "applicationSet.replicas"
        value = 2
      }
    ]
    values = [templatefile("argocd-values.yaml", {
      certificate_arn = "인증서 정보"
    })]
  }
}
