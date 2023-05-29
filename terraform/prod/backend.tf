

terraform {

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "terr-state-file"
    region     = "ru-central1"
    key        = "prod/terraform.tfstate"
    access_key = "YCsdvszdfsdfvsvfdsvmVi"
    secret_key = "YSDVSDVsdadfsdfvfD"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
