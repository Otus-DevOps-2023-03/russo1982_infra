

terraform {

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "terr-state-file"
    region     = "ru-central1"
    key        = "prod/terraform.tfstate"
    access_key = "YCsdvszd"
    secret_key = "YSDVS"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
