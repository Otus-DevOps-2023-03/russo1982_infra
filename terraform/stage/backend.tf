

terraform {

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "terr-state-file"
    region     = "ru-central1"
    key        = "stage/terraform.tfstate"
    access_key = "YCsdvsdvvvVi"
    secret_key = "YCOavravvD"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
