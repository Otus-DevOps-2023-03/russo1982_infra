# /modules/db/output.tf


output "subnet" {
  value = yandex_vpc_subnet.app-subnet.id
}

output "app-network" {
  value = yandex_vpc_network.app-network.id
}
