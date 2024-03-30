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
  auto_create_subnetworks         = var.auto_create_subnetworks
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = var.delete_default_routes_on_create
}
resource "google_compute_subnetwork" "db-subnet" {
  name                     = var.db_subnet
  ip_cidr_range            = var.db_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.custom-vpc.id
  private_ip_google_access = var.private_ip_google_access
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
  next_hop_gateway = var.next_hop_gateway
  depends_on       = [google_compute_network.custom-vpc]
}

resource "google_compute_firewall" "public_firewall" {
  name          = var.firewall-name
  network       = google_compute_network.custom-vpc.name
  source_ranges = [var.public_gateway]
  target_tags   = [var.network_tags]

  allow {
    protocol = var.protocol
    ports    = [var.app_port, var.public_port]
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
resource "google_compute_address" "endpoint_ip_addr" { # and forwarding rule from service Endpoint to IP Address 
  # project      = google_compute_network.custom-vpc.project
  name         = var.endpoint_ip_addr_name
  region       = var.gcp_region
  address_type = var.endpoint_ip_addr_type
  subnetwork   = google_compute_subnetwork.webapp-subnet.id
  address      = var.webapp_endpoint_ip
  depends_on   = [google_compute_subnetwork.webapp-subnet]
}

resource "google_compute_forwarding_rule" "endpoint" {
  project = google_compute_network.custom-vpc.project
  name    = var.webapp_endpoint_fwd_rule
  target  = google_sql_database_instance.postgres_vm.psc_service_attachment_link
  network               = google_compute_network.custom-vpc.self_link
  subnetwork            = google_compute_subnetwork.webapp-subnet.id
  ip_address            = google_compute_address.endpoint_ip_addr.id
  load_balancing_scheme = ""
  depends_on            = [google_compute_address.endpoint_ip_addr, google_compute_network.custom-vpc, google_sql_database_instance.postgres_vm]
}

# Create an IP address
resource "google_compute_global_address" "psc_private_ip_alloc" {
  name          = var.psc_private_ip_alloc_name
  purpose       = var.psc_private_ip_alloc_name_purpose
  address_type  = var.psc_private_ip_alloc_addr_type
  prefix_length = var.psc_private_ip_alloc_prefix_length
  network       = google_compute_network.custom-vpc.id
  depends_on = [ google_compute_network.custom-vpc ]
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.custom-vpc.id
  service                 = var.private_vpc_connection_name
  reserved_peering_ranges = [google_compute_global_address.psc_private_ip_alloc.name]
  depends_on              = [google_compute_global_address.psc_private_ip_alloc, google_compute_network.custom-vpc]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "postgres_vm" {
  name                = "private-sql-instance-${random_id.db_name_suffix.hex}"
  region              = var.gcp_region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  # make instance in private service connection
  # psc defaults to auto generated subnet, dns zone, and 
  # connects to forwarding rule
  settings {
    tier              = var.sql_instance_tier
    availability_type = var.routing_mode
    disk_type         = var.sql_disk_type
    disk_size         = var.sql_disk_size
    ip_configuration {
      psc_config {
        psc_enabled               = var.psc_enable
        allowed_consumer_projects = [var.project_id]
      }
      ipv4_enabled = var.ipv4_disable
    }
    backup_configuration {
      enabled            = var.backup_enable
      binary_log_enabled = var.binary_logging_disable
    }
  }
}

resource "google_sql_database" "database" {
  name       = var.db_name
  instance   = google_sql_database_instance.postgres_vm.name
  depends_on = [google_sql_database_instance.postgres_vm, google_sql_user.db_user]
}

resource "google_sql_user" "db_user" {
  name       = var.db_user_name
  instance   = google_sql_database_instance.postgres_vm.name
  password   = "${random_id.db_pswd.hex}"
}

resource "random_id" "db_pswd" {
  byte_length = 8
}
# ---------- # ---------- # ---------- # ---------- # ----------



# ---------- # ---------- # ---------- # ---------- # ----------
# Infra setup for Web Application
# Includes public subnet, route, and 
# firewall rule for public internet access
# ---------- # ---------- # ---------- # ---------- # ----------
# 

locals {
  timestamp = formatdate("MM-DD-hh-mm", timestamp())
}

resource "google_compute_instance" "webapp-host" {
  machine_type = var.machine_type
  name         = "${var.server_name}-${local.timestamp}"
  zone         = var.gcp_zone
  boot_disk {
    auto_delete = true
    device_name = var.server_name

    initialize_params {
      # image = "debian-cloud/debian-11"
      image = "projects/${var.project_id}/global/images/${var.image_id}"
      size = var.disk_size
      type = var.disk_type
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

  metadata = {
    startup-script = <<-EOT
        #!/bin/bash

        set -e
        if [ -f "/opt/webapp/.env" ]; then
          echo "Env file exists:"
          sudo cat "/opt/webapp/.env"
        else 
          # setup env file
          sudo echo "HOST=${google_compute_address.endpoint_ip_addr.address}" > /opt/webapp/.env
          sudo echo "DATABASE=${google_sql_database.database.name}" >> /opt/webapp/.env
          sudo echo "USERNAME=${google_sql_user.db_user.name}" >> /opt/webapp/.env
          sudo echo "PASSWORD=${google_sql_user.db_user.password}" >> /opt/webapp/.env
          sudo echo "DIALECT=${var.db_dialect}" >> /opt/webapp/.env
          sudo echo "DB_PORT=${var.db_port}" >> /opt/webapp/.env
          sudo echo "LOGPATH=/var/log/webapp/webapp.log" >> /opt/webapp/.env
          echo "Env file generated"
        fi

        echo "Restart ops agent"
        sudo systemctl restart google-cloud-ops-agent
        sudo systemctl status google-cloud-ops-agent --no-pager

        echo "Setting up webapp service"
        sudo cat /opt/webapp/packer/setup_service.sh
        sudo /opt/webapp/packer/setup_service.sh
        EOT
  }
        # sudo echo "HOST=${google_sql_database_instance.ip_address.0.ip_address}" >> /opt/webapp/.env
  tags       = [var.network_tags]
  depends_on = [google_compute_network.custom-vpc, google_compute_subnetwork.webapp-subnet]
  service_account {
    email  = google_service_account.webapp_service_account.email
    # scopes = ["logging-write","monitoring-read","monitoring-write"]
    scopes = [
                  "https://www.googleapis.com/auth/logging.write",
                  "https://www.googleapis.com/auth/monitoring.write"
                  ]
  }
  allow_stopping_for_update = true
}
# ---------- # ---------- # ---------- # ---------- # ----------
resource "google_dns_record_set" "routing_policy" {
  project = var.project_id
  name      = var.dns_zone_dns_name
  type      = "A"
  ttl       = 60  # Time to live in seconds
  managed_zone = var.dns_zone_name

  rrdatas = [
    # google_compute_instance.webapp-host.network_interface.0.network_ip
    google_compute_instance.webapp-host.network_interface[0].access_config[0].nat_ip
  ]
}

resource "google_service_account" "webapp_service_account" {
  account_id   = "webapp-service-account-id"
  display_name = "Webapp Service Account"
}

resource "google_project_iam_binding" "log_admin" {
  project = var.project_id
  role    = "roles/logging.admin"

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}"
  ]
}

resource "google_project_iam_binding" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}"
  ]
}