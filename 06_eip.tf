module "chat_app_eip" {
  source         = "./modules/eip"
  eip_parameters = lookup(var.eip_parameters, terraform.workspace, {})
}