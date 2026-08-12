# Remote state - OPTIONAL (s43: an S3 backend with versioning is the
# production pattern; local state is fine for a one-person course project).
#
# To enable: create a versioned S3 bucket, uncomment, then `terraform init`
# (Terraform offers to migrate the existing local state).
#
# terraform {
#   backend "s3" {
#     bucket = "<your-unique-tfstate-bucket>"
#     key    = "namegen-eks/terraform.tfstate"
#     region = "us-west-2"
#   }
# }
