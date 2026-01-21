# Allocate an Elastic IP
resource "aws_eip" "example" {
  for_each                  = var.eip_parameters
  domain                    = each.value.domain
  network_interface         = each.value.network_interface
  associate_with_private_ip = each.value.associate_with_private_ip
  instance                  = each.value.instance
  public_ipv4_pool          = each.value.public_ipv4_pool
  ipam_pool_id              = each.value.ipam_pool_id

  tags = merge(each.value.tags, {
    Name : each.key
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags] # Ignore changes to tags to avoid unnecessary updates
  }
}