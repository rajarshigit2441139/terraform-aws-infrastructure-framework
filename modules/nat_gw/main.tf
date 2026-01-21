resource "aws_nat_gateway" "example" {
  for_each                           = var.nat_gateway_parameters
  connectivity_type                  = each.value.connectivity_type                  # Uset it for Private NAT only. value = "private"
  secondary_private_ip_address_count = each.value.secondary_private_ip_address_count # Uset it for Private NAT with Secondary Private IP Addresses only. value = number 
  subnet_id                          = each.value.subnet_id
  allocation_id                      = each.value.allocation_id                  # aws_eip.id for Public NAT (Only for Public NAT)
  secondary_allocation_ids           = each.value.secondary_allocation_ids       # aws_eip.secondary.id for Public NAT with Secondary Private IP Addresses (Optional Only for Public NAT)
  secondary_private_ip_addresses     = each.value.secondary_private_ip_addresses # secondary IPs
  tags = merge(each.value.tags, {
    Name : each.key
  })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags] # Ignore changes to tags to avoid unnecessary updates
  }
}