
resource "aws_vpc_endpoint" "example" {
  for_each = var.vpc_endpoints

  vpc_id            = each.value.vpc_id
  service_name      = "com.amazonaws.${each.value.region}.${each.value.service_name}"
  vpc_endpoint_type = each.value.vpc_endpoint_type

  # Gateway endpoints use route_table_ids
  route_table_ids = try(each.value.route_table_ids, null)

  # Interface endpoints use these
  subnet_ids          = try(each.value.subnet_ids, null)
  security_group_ids  = try(each.value.security_group_ids, null)
  private_dns_enabled = try(each.value.private_dns_enabled, null)

  tags = merge(each.value.tags, {
    Name = each.key
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags] # Ignore changes to tags to avoid unnecessary updates
  }
}
