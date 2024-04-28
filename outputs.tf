
data "aws_network_interface" "counter" {
  for_each = toset(data.aws_network_interfaces.counter.ids)
  id       = each.key
}

data "aws_network_interfaces" "counter" {
  filter {
    name   = "group-id"
    values = [aws_security_group.counter.id]
  }
}

output "counter_eni" {
  value = [for eni in data.aws_network_interface.counter : eni.association[0].public_ip]
}