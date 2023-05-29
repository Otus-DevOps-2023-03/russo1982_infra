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
  default     = "fd82dkbbdpdktah8ega7" # image created by Packer with installed Ruby named reddit-base-ruby-1683553352
}
variable "db_disk_image" {
  description = "Disk image for reddit db"
  default     = "fd8t80ruels55tjlmf65" # image created by Packer with installed MongoDB named "reddit-base-mdb-1683552819"
}

/*
variable "db_ip" {
  description = "database IP"
}
*/
