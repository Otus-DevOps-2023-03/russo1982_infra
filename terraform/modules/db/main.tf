# File name /modules/bd/main.tf
# copied from db.tf

/*
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.89.0"
    }
  }
}
*/

resource "yandex_compute_instance" "db" {
  ## count    = var.instances
  name     = "reddit-db" ## -${count.index}"
  hostname = "reddit-db" ## -${count.index}"
  zone     = var.zone

  labels = {
    tags = "reddit-db"
  }

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    initialize_params {
      # Указать id образа
      image_id = var.db_disk_image
    }
  }

  scheduling_policy {
    preemptible = true
  }
  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }


  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  connection {
    type  = "ssh"
    host  = self.network_interface.0.nat_ip_address
    user  = "ubuntu"
    agent = false
    # путь до приватного ключа
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    script = "${path.module}/mongodb.sh"
  }

}
