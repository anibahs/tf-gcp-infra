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
  default = "db-subnet"
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
  default = "8080"
}

variable "public_port" {
  type    = string
  default = "80"
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
  default = "webapp"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "firewall-name" {
  type    = string
  default = "internet-firewall"
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
# -----------------------------
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "delete_default_routes_on_create" {
  type    = bool
  default = true
}
variable "auto_create_subnetworks" {
  type    = bool
  default = false
}
variable "private_ip_google_access" {
  type    = bool
  default = true
}
variable "next_hop_gateway" {
  type    = string
  default = "default-internet-gateway"
}
variable "protocol" {
  type    = string
  default = "tcp"
}

variable "endpoint_ip_addr_name" {
  type    = string
  default = "psc-ip-addr"
}
variable "endpoint_ip_addr_type" {
  type    = string
  default = "INTERNAL"
}
variable "webapp_endpoint_ip" {
  type    = string
  default = "10.1.2.3"
}
variable "webapp_endpoint_fwd_rule" {
  type    = string
  default = "webapp-endpoint-fwd-rule"
}
variable "private_vpc_connection_name" {
  type    = string
  default = "servicenetworking.googleapis.com"
}


variable "psc_private_ip_alloc_name" {
  type    = string
  default = "private-ip-alloc"
}
variable "psc_private_ip_alloc_name_purpose" {
  type    = string
  default = "VPC_PEERING"
}
variable "psc_private_ip_alloc_addr_type" {
  type    = string
  default = "INTERNAL"
}
variable "psc_private_ip_alloc_prefix_length" {
  type    = number
  default = 16
}
variable "database_version" {
  type    = string
  default = "POSTGRES_15"
}
variable "sql_instance_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "sql_disk_type" {
  type    = string
  default = "pd-ssd"
}

variable "sql_disk_size" {
  type    = number
  default = 100
}
variable "psc_enable" {
  type    = bool
  default = true
}
variable "ipv4_disable" {
  type    = bool
  default = false
}
variable "backup_enable" {
  type    = bool
  default = true
}
variable "binary_logging_disable" {
  type    = bool
  default = false
}
variable "db_name" {
  type    = string
  default = "webapp"
}
variable "db_user_name" {
  type    = string
  default = "webapp"
}

variable "db_dialect" {
  type    = string
  default = "postgres"
}

variable "db_port" {
  type    = string
  default = "5432"
}

variable "dns_zone_name" {
  type    = string
  default = "anibahscsye6225"
}

variable "dns_zone_dns_name" {
  type    = string
  default = "anibahscsye6225.me."
}
