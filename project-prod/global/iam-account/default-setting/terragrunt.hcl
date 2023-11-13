include "root" {
  path = find_in_parent_folders()
}

include "common_account" {
  path = "${get_path_to_repo_root()}/_common/iam/iam-account/default.hcl"
}
