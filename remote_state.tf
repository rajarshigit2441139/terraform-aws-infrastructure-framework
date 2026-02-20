# ----      remote state      ---- #

# Create the S3 backend configuration file with backend.<ENV>.conf file
terraform {
  backend "s3" {}
}
