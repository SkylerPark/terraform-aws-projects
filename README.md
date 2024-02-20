# 초기설정

해당 Terragrunt 코드는 AWS AssumeRole 기반으로 작성되어 있습니다.

## terragrunt 초기 설정

경로 : init_config.hcl

```hcl
locals {
  bucket         = "bucket_name"
  dynamodb_table = "dynamodb_name"
  role_name      = "role_name"
  profile_name   = "profile_name"
}
```

## 프로젝트 생성 시

경로 : project-directory/account.hcl

```hcl
locals {
  account_id   = "11111111111111"
  account_name = "project-prod"
  project_name = "project"
}

```

## IP 설정, admin 계정 설정 Manage Account 설정

경로 : \_common/variables/common.hcl

```hcl
locals {
  addresses = [
  ]

  manage_account_id = "11111111111"
  admin_users       = ["test"]
}

```
