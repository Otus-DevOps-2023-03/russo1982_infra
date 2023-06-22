# Terraform main config taken from OTUS course webinar PDF
#
#
#


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

provider "yandex" {
  #  token     = "t1.9euelZqPko_"
  #              token of terraform service account "cloud-editor"
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}


module "vpc" {
  source = "../modules/vpc"
}

module "app" {
  source          = "../modules/app"
  public_key_path = var.public_key_path
  app_disk_image  = var.app_disk_image
  subnet_id       = module.vpc.subnet
  db_ip           = module.db.internal_ip_address_db
}

module "db" {
  source          = "../modules/db"
  public_key_path = var.public_key_path
  db_disk_image   = var.db_disk_image
  subnet_id       = module.vpc.subnet
}

resource "local_file" "app_inventory" {
  filename = "../../ansible/inventory.json"
  content  = <<-EOF
  {
  "all": {
    "children": {
      "app": {
        "hosts": {
          "app-server": {
            "ansible_host": ${module.app.external_ip_address_app}
          }
        }
      },
      "db": {
        "hosts": {
          "db-server": {
            "ansible_host": ${module.db.external_ip_address_db}
          }
        }
      }
    }
  }
}

EOF
}
resource "yandex_vpc_security_group" "web-server" {
  name        = "HTTPD security group"
  description = "Security group to route the trafic into web server"
  network_id  = module.vpc.app-network

  ingress {
    protocol       = "TCP"
    description    = "HTTP trafic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH trafic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow any outoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = -1
    to_port        = -1
  }
}

/*
resource "yandex_storage_bucket" "s3-bucket" {
  bucket        = var.bucket_name
  access_key    = var.access_key
  secret_key    = var.secret_key
  force_destroy = "true"
}

  provisioner "file"{
  source = "files/puma.service"
  destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
  script = "files/deploy.sh"
  }

  connection {
  type = "ssh"
  host  = self.network_interface.0.nat_ip_address
  user = "ubuntu"
  agent = false
  # путь до приватного ключа
  private_key = file(var.private_key_path)
  }
*/
