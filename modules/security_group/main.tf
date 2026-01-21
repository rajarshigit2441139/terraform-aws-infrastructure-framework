# Child SG Module

resource "aws_security_group" "example" {
  for_each = var.security_group_parameters
  name     = each.value.name
  vpc_id   = each.value.vpc_id

  tags = merge(each.value.tags, { Name : each.key })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags] # Ignore changes to tags to avoid unnecessary updates
  }
}

resource "aws_vpc_security_group_ingress_rule" "ipv4_ingress_example" {
  for_each = var.ipv4_ingress_rule != {} ? var.ipv4_ingress_rule : {}

  # Resolve SG names to IDs if a mapping was provided (root resolves names->ids).
  # Prefer referenced SG id over CIDR; only set cidr_ipv4 when referenced id is null.
  security_group_id = try(lookup(var.sg_name_to_id_map, each.value.sg_name), each.value.security_group_id)

  referenced_security_group_id = try(lookup(var.sg_name_to_id_map, each.value.source_security_group_name), try(each.value.referenced_security_group_id, null))

  cidr_ipv4 = try(each.value.cidr_ipv4, null)

  # ip_protocol must always be present
  ip_protocol = each.value.protocol

  # Set ports only when protocol is NOT "-1" (all protocols).
  # When protocol == "-1", these evaluate to null and are omitted.
  from_port = each.value.protocol == "-1" ? null : try(each.value.from_port, null)
  to_port   = each.value.protocol == "-1" ? null : try(each.value.to_port, null)
}



resource "aws_vpc_security_group_ingress_rule" "ipv6_ingress_example" {
  for_each          = var.ipv6_ingress_rule != {} ? var.ipv6_ingress_rule : {}
  security_group_id = each.value.security_group_id
  cidr_ipv6         = each.value.cidr_ipv6
  from_port         = each.value.from_port
  ip_protocol       = each.value.protocol
  to_port           = each.value.to_port
}

resource "aws_vpc_security_group_egress_rule" "ipv4_egress_example" {
  for_each = var.ipv4_egress_rule != {} ? var.ipv4_egress_rule : {}

  security_group_id = try(lookup(var.sg_name_to_id_map, each.value.sg_name), each.value.security_group_id)

  referenced_security_group_id = try(lookup(var.sg_name_to_id_map, each.value.source_security_group_name), try(each.value.referenced_security_group_id, null))

  cidr_ipv4 = try(each.value.cidr_ipv4, null)

  ip_protocol = each.value.protocol

  from_port = each.value.protocol == "-1" ? null : try(each.value.from_port, null)
  to_port   = each.value.protocol == "-1" ? null : try(each.value.to_port, null)
}

resource "aws_vpc_security_group_egress_rule" "ipv6_egress_example" {
  for_each          = var.ipv6_egress_rule != {} ? var.ipv6_egress_rule : {}
  security_group_id = try(lookup(var.sg_name_to_id_map, each.value.sg_name), each.value.security_group_id)
  cidr_ipv6         = each.value.cidr_ipv6 # "::/0"
  ip_protocol       = each.value.protocol  # "-1" # semantically equivalent to all ports
}