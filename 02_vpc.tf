# -------------- VPC module -------------- #
module "chat_app_vpc" {
  source         = "./modules/vpc"
  vpc_parameters = lookup(var.vpc_parameters, terraform.workspace, {})
}