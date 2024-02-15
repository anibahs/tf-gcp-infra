

provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

resource "google_compute_network" "custom-vpc" {
  name                            = "custom-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "db-subnet" {
  name                     = "db-subnet"
  ip_cidr_range            = "10.1.2.0/24"
  region                   = var.gcp_region
  network                  = google_compute_network.custom-vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "webapp-subnet" {
  name                     = "webapp-subnet"
  ip_cidr_range            = "10.1.3.0/24"
  region                   = var.gcp_region
  network                  = google_compute_network.custom-vpc.id
}

resource "google_compute_route" "network-route" {
  name              = "network-route"
  dest_range        = "0.0.0.0/0"
  network           = google_compute_network.custom-vpc.name
  next_hop_gateway  = "default-internet-gateway"
}