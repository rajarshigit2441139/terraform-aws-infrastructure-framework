resource "aws_internet_gateway" "example" {
  for_each = var.igw_parameters
  vpc_id   = each.value.vpc_id
  tags = merge(each.value.tags, {
    Name : each.key
  })
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags] # Ignore changes to tags to avoid unnecessary updates
  }
}