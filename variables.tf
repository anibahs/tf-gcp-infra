variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-east1"
}
variable "project_id" {
  description = "project_id"
  type        = string
  default     = "anibahs-csye6225"
}

variable "custom_vpc" {
  type    = string
  default = "custom-vpc"
}
variable "db_subnet" {
  type    = string
  default = "db"
}

variable "webapp_subnet" {
  type    = string
  default = "webapp"
}
variable "network_route" {
  type    = string
  default = "network-route"
}
variable "db_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "webapp_cidr" {
  type    = string
  default = "10.1.2.0/24"
}

variable "public_gateway" {
  type    = string
  default = "0.0.0.0/0"
}