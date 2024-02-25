variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-east1"
}
variable "gcp_zone" {
  description = "GCP zone"
  type        = string
  default     = "us-east1-b"
}
variable "project_id" {
  description = "project_id"
  type        = string
  default     = "dev-csye6225-414718"
}
variable "routing_mode" {
  type    = string
  default = "REGIONAL"
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
  default = "webapp-subnet"
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

variable "app_port" {
  type    = string
  default = "8080, 80"
}

variable "image_id" {
  type    = string
  default = "centosstream8"
}

variable "disk_size" {
  type    = number
  default = 100
}

variable "disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "server_name" {
  type    = string
  default = "webapp-cs8"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "firewall-name" {
  type    = string
  default = "custom-firewall"
}

variable "network_tags" {
  type    = string
  default = "http-server"
}
variable "network_tier" {
  type    = string
  default = "STANDARD"
}
variable "network_stack" {
  type    = string
  default = "IPV4_ONLY"
}
