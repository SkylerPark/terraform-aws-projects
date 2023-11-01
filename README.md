account.hcl

```hcl
locals {
  account_id   = "497712261737"
  account_name = "moham-manage"
  project_name = "moham"
}

```

init_config.hcl

```hcl
locals {
  bucket         = "moham-terraform-state"
  dynamodb_table = "moham-terraform-state"
  role_name      = "MohamIacRole"
  profile_name   = "moham-manage"
}

```
