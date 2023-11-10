include "root" {
  path = find_in_parent_folders()
}

include "common_policy" {
  path = "${get_path_to_repo_root()}/_common/iam/iam-policy/iac-sts-policy.hcl"
}
