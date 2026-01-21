output "eips" {
  description = "All Elastic IP resources created by this module."
  value = {
    for k, eip in aws_eip.example :
    k => {
      id                = eip.id
      public_ip         = eip.public_ip
      private_ip        = eip.private_ip
      public_dns        = eip.public_dns
      network_interface = eip.network_interface
      instance          = eip.instance
      allocation_id     = eip.allocation_id
      association_id    = eip.association_id
      domain            = eip.domain
      tags              = eip.tags
    }
  }
}
