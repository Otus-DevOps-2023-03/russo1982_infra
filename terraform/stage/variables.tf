variable "cloud_id" {
  description = "Cloud"
}
variable "folder_id" {
  description = "Folder"
}
variable "region_id" {
  description = "region"
  default     = "ru-central1"
}
variable "zone" {
  description = "Zone"
  # Значение по умолчанию
  default = "ru-central1-a"
}
variable "public_key_path" {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}
variable "private_key_path" {
  # Описание переменной
  description = "Path to the private key used for ssh access"
}

variable "image_id" {
  description = "Disk image"
}
##variable "subnet_id" {
##  description = "Subnet"
##}
variable "service_account_key_file" {
  description = "key.json"
}
variable "instances" {
  description = "counts instances"
  default     = 1
}
variable "app_disk_image" {
  description = "Disk image for reddit app"
  default     = "fd8nq8ekekn3nu4uspet" # image created by Packer with installed Ruby named "reddit-ruby-1685274414"
}
variable "db_disk_image" {
  description = "Disk image for reddit db"
  default     = "fd8mg91kqm1cvafurehd" # image created by Packer with installed MongoDB named "reddit-mongodb-1685268210"
}

/*
variable "db_ip" {
  description = "database IP"
}
*/
