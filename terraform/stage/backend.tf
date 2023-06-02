

terraform {

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "terr-state-file"
    region     = "ru-central1"
    key        = "stage/terraform.tfstate"
    access_key = "YCAJ"
    secret_key = "YCOx3MIZ"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
