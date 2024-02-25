

provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

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
  name        = var.firewall-name
  network     = google_compute_network.custom-vpc.name
  source_ranges = [var.public_gateway]
  target_tags = [var.network_tags]

  allow {
    protocol = "tcp"
    ports    = ["8080","80"]
  }
  depends_on = [google_compute_network.custom-vpc]
}

resource "google_compute_instance" "webapp-host" {
  machine_type = var.machine_type
  name         = var.server_name
  zone         = var.gcp_zone
  boot_disk {
    auto_delete = true
    device_name = var.server_name

    initialize_params {
      image = "projects/${var.project_id}/global/images/${var.image_id}"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    access_config {
      network_tier = var.network_tier
    }    
    stack_type  = var.network_stack
    subnetwork         = google_compute_subnetwork.webapp-subnet.name
    subnetwork_project = google_compute_network.custom-vpc.project
  }
  tags = [var.network_tags]
  depends_on = [google_compute_network.custom-vpc, google_compute_subnetwork.webapp-subnet]
}

