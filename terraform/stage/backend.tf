

terraform {

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "terr-state-file"
    region     = "ru-central1"
    key        = "stage/terraform.tfstate"
    access_key = "YCAJE7V_ryhfk-9EKPyrG1mVi"
    secret_key = "YCOx3MIZOU48_GD3wC1JwSTaP_xI-8i_HcuTNXHD"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
