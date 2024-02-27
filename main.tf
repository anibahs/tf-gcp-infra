provider "google" {
  project = var.project_id
  region  = var.gcp_region
}


# ---------- # ---------- # ---------- # ---------- # ----------
# Infra setup for Networks
# private subnet
# public subnet, route, firewall to connect to internet
# ---------- # ---------- # ---------- # ---------- # ----------
# 
# 
# 
# 
resource "google_compute_network" "custom-vpc" {
  name                            = var.custom_vpc
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}
resource "google_compute_subnetwork" "db-subnet" {
  name                     = var.db_subnet
  ip_cidr_range            = var.db_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.custom-vpc.id
  private_ip_google_access = true
  depends_on               = [google_compute_network.custom-vpc]
}
resource "google_compute_subnetwork" "webapp-subnet" {
  name          = var.webapp_subnet
  ip_cidr_range = var.webapp_cidr
  region        = var.gcp_region
  network       = google_compute_network.custom-vpc.id
  depends_on    = [google_compute_network.custom-vpc]

}

resource "google_compute_route" "network-route" {
  name             = var.network_route
  dest_range       = var.public_gateway
  network          = google_compute_network.custom-vpc.name
  next_hop_gateway = "default-internet-gateway"
  depends_on       = [google_compute_network.custom-vpc]

}

resource "google_compute_firewall" "default" {
  name          = var.firewall-name
  network       = google_compute_network.custom-vpc.name
  source_ranges = [var.public_gateway]
  target_tags   = [var.network_tags]

  allow {
    protocol = "tcp"
    ports    = ["8080", "80"]
  }
  depends_on = [google_compute_network.custom-vpc]
}
# ---------- # ---------- # ---------- # ---------- # ----------





# ---------- # ---------- # ---------- # ---------- # ----------
# Infra setup for Database
# Includes 
# private service connection in shared vpc
# ip address, and forwarding rule
# instance to host db, postgres database, sql user
# ---------- # ---------- # ---------- # ---------- # ----------
# 
# 
# 
resource "google_compute_address" "psc_ip_addr" { # and forwarding rule from service Endpoint to IP Address 
  # project      = google_compute_network.custom-vpc.project
  name         = "psc-ip-addr"
  region       = var.gcp_region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.webapp-subnet.id
  address      = "10.1.2.3"
  depends_on   = [google_compute_subnetwork.webapp-subnet]
}

resource "google_compute_forwarding_rule" "endpoint" {
  project               = google_compute_network.custom-vpc.project
  name                  = "globalrule"
  target                = google_sql_database_instance.postgres_vm.psc_service_attachment_link
  # "all-apis"
  # backend_service       = google_sql_database_instance.postgres_vm.psc_service_attachment_link
  network               = google_compute_network.custom-vpc.self_link
  subnetwork            = google_compute_subnetwork.webapp-subnet.id
  ip_address            = google_compute_address.psc_ip_addr.id
  load_balancing_scheme = ""
  depends_on = [ google_compute_address.psc_ip_addr, google_compute_network.custom-vpc, google_sql_database_instance.postgres_vm]
}

# Create an IP address
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.custom-vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.custom-vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  depends_on = [ google_compute_global_address.private_ip_alloc, google_compute_network.custom-vpc]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "postgres_vm" {
  name                = "private-instance-${random_id.db_name_suffix.hex}"
  region              = var.gcp_region
  database_version    = "POSTGRES_15"
  deletion_protection = var.deletion_protection

  # make network private
  settings {
    tier      = "db-f1-micro"
    availability_type = var.routing_mode
    disk_type = "pd_ssd"
    disk_size = 100
    ip_configuration {
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
      ipv4_enabled = false
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = false
    }
  }
}

resource "google_sql_database" "postgres_host" {
  name     = "my-database"
  instance = google_sql_database_instance.postgres_vm.name
  depends_on = [ google_sql_database_instance.postgres_vm ]
}

resource "google_sql_user" "users" {
  name     = "postgres"
  instance = google_sql_database_instance.postgres_vm.name
  # host     = "localhost"
  password = "postgres"
  depends_on = [ google_sql_database_instance.postgres_vm ]
}
# ---------- # ---------- # ---------- # ---------- # ----------



# ---------- # ---------- # ---------- # ---------- # ----------
# Infra setup for Web Application
# Includes public subnet, route, and 
# firewall rule for public internet access
# ---------- # ---------- # ---------- # ---------- # ----------
# 
# 
# 
resource "google_compute_instance" "webapp-host" {
  machine_type = var.machine_type
  name         = var.server_name
  zone         = var.gcp_zone
  boot_disk {
    auto_delete = true
    device_name = var.server_name

    initialize_params {
      image = "debian-cloud/debian-11"
      # image = "projects/${var.project_id}/global/images/${var.image_id}"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    access_config {
      network_tier = var.network_tier
    }
    stack_type         = var.network_stack
    subnetwork         = google_compute_subnetwork.webapp-subnet.name
    subnetwork_project = google_compute_network.custom-vpc.project
  }
  tags       = [var.network_tags]
  depends_on = [google_compute_network.custom-vpc, google_compute_subnetwork.webapp-subnet]
}
# ---------- # ---------- # ---------- # ---------- # ----------

