# File name /modules/app/main.tf
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

resource "yandex_compute_instance" "app" {
  ##count    = var.instances
  name     = "reddit-app" ##-${count.index}"
  hostname = "reddit-app" ##-${count.index}"
  zone     = var.zone

  labels = {
    tags = "reddit-app"
  }

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    initialize_params {
      # Указать id образа
      image_id = var.app_disk_image
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
    /*  user-data = <<-EOF
                  #!/bin/bash
                  echo "DATABASE_URL=${var.db_ip}:27017" >> /etc/environment
                  EOF
                  */
  }
}
/*
  provisioner "file" {
    ## source = "${path.module}/puma.service"
    content     = templatefile("${path.module}/puma.service", { database_url = "${var.db_ip}" })
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    script = "${path.module}/deploy.sh"
  }

  connection {
    type  = "ssh"
    host  = self.network_interface.0.nat_ip_address
    user  = "ubuntu"
    agent = false
    # путь до приватного ключа
    private_key = file(var.private_key_path)
  }
*/
