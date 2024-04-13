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

resource "google_compute_subnetwork" "proxy_only" {
  name          = var.proxy_only
  ip_cidr_range = var.proxy_cidr
  network       = google_compute_network.custom-vpc.id
  region        = var.gcp_region
}

resource "google_compute_route" "network-route" {
  name             = var.network_route
  dest_range       = var.public_gateway
  network          = google_compute_network.custom-vpc.name
  next_hop_gateway = var.next_hop_gateway
  depends_on       = [google_compute_network.custom-vpc]
}

# enable ssh for demo
# resource "google_compute_firewall" "ssh_firewall" {
#   name    = var.firewall-name
#   network = google_compute_network.custom-vpc.name
#   source_ranges = ["35.235.240.0/20"]
#   # source_ranges = [var.public_gateway]
#   target_tags   = [var.network_tags]

#   allow {
#     protocol = var.protocol
#     ports    = ["22"]
#     # ports = [var.app_port, var.public_port]
#   }
#   depends_on = [google_compute_network.custom-vpc]
# }

resource "google_compute_global_address" "lb_ip_addr" {
  name         = var.lb_ip_addr
  address_type = var.load_balancing_scheme
}

resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  project               = google_compute_network.custom-vpc.project
  name                  = var.lb_forwarding_rule
  target                = google_compute_target_https_proxy.lb_target_proxy.self_link
  port_range            = var.https_default_port
  load_balancing_scheme = var.load_balancing_scheme
  ip_protocol           = var.https_protocol
  ip_address            = google_compute_global_address.lb_ip_addr.id
  depends_on            = [google_compute_global_address.lb_ip_addr]
}

resource "google_compute_firewall" "lb-firewall" {
  name    = var.lb-firewall
  network = google_compute_network.custom-vpc.self_link
  allow {
    protocol = var.lb_firewall_protocol
    ports    = [var.lb_firewall_port]
  }
  source_ranges = [google_compute_subnetwork.proxy_only.ip_cidr_range, google_compute_global_forwarding_rule.lb_forwarding_rule.ip_address, "35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = [var.network_tags]
  depends_on    = [
    google_compute_global_forwarding_rule.lb_forwarding_rule, 
    google_compute_global_address.lb_ip_addr
    ]
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
  name         = var.endpoint_ip_addr_name
  region       = var.gcp_region
  address_type = var.endpoint_ip_addr_type
  subnetwork   = google_compute_subnetwork.webapp-subnet.id
  address      = var.webapp_endpoint_ip
  depends_on   = [google_compute_subnetwork.webapp-subnet]
}

resource "google_compute_forwarding_rule" "endpoint" {
  project               = google_compute_network.custom-vpc.project
  name                  = var.webapp_endpoint_fwd_rule
  target                = google_sql_database_instance.postgres_vm.psc_service_attachment_link
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
  depends_on    = [google_compute_network.custom-vpc]
}

# PSC on vpc
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.custom-vpc.id
  service                 = var.private_vpc_connection_name
  reserved_peering_ranges = [google_compute_global_address.psc_private_ip_alloc.name]
  depends_on              = [google_compute_global_address.psc_private_ip_alloc, google_compute_network.custom-vpc]
}


resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  service  = "sqladmin.googleapis.com"
  project = var.project_id
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "postgres_vm" {
  name                = "private-sql-instance-${random_id.db_name_suffix.hex}"
  region              = var.gcp_region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection
  encryption_key_name = data.google_kms_crypto_key.sql-key.id
  
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
  depends_on = [ google_project_service_identity.gcp_sa_cloud_sql,google_kms_crypto_key_iam_binding.sql-key-binding ]
}

resource "google_sql_database" "database" {
  name       = var.db_name
  instance   = google_sql_database_instance.postgres_vm.name
  depends_on = [google_sql_database_instance.postgres_vm, google_sql_user.db_user]
}

resource "google_sql_user" "db_user" {
  name     = var.db_user_name
  instance = google_sql_database_instance.postgres_vm.name
  password = random_id.db_pswd.hex
}

resource "random_id" "db_pswd" {
  byte_length = 8
}

# ---------- # ---------- # ---------- # ---------- # ----------

resource "google_dns_record_set" "routing_policy" {
  project      = var.project_id
  name         = var.dns_zone_dns_name
  type         = "A"
  ttl          = var.routing_policy_ttl
  managed_zone = var.dns_zone_name
  rrdatas = [
    google_compute_global_forwarding_rule.lb_forwarding_rule.ip_address
  ]
  depends_on = [
    google_compute_global_forwarding_rule.lb_forwarding_rule, 
    google_compute_global_address.lb_ip_addr
    ]
}

resource "google_service_account" "webapp_service_account" {
  account_id   = var.webapp_service_account_id
  display_name = var.webapp_service_account_name
}

resource "google_project_iam_binding" "log_admin" {
  project = var.project_id
  role    = var.iam_binding_logging

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}"
  ]
}

resource "google_project_iam_binding" "metric_writer" {
  project = var.project_id
  role    = var.iam_binding_metric

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}"
  ]
}

resource "google_project_iam_binding" "pubsub_publisher" {
  project = var.project_id
  role    = var.pubsub_publisher

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}"
  ]
}


# ---------- # ---------- # ---------- # ---------- # ----------
# Infra setup for Pub/Sub
# Includes pub sub topic, subscription, cloud function
#
# ---------- # ---------- # ---------- # ---------- # ----------
resource "google_service_account" "cloudfunction_service_account" {
  account_id   = var.cloudfunction_service_account_id
  display_name = var.cloudfunction_service_account_name
}

resource "google_pubsub_topic" "trigger_email" {
  name                       = var.pubsub_topic
  message_retention_duration = var.pubsub_topic_mrd
}

resource "google_pubsub_subscription" "check_user" {
  name  = var.pubsub_subscription
  topic = google_pubsub_topic.trigger_email.id

  message_retention_duration = var.pubsub_subscription_mrd
  retain_acked_messages      = var.retain_acked
  ack_deadline_seconds       = var.ack_deadline
  retry_policy {
    minimum_backoff = var.retry_min
  }
  enable_message_ordering = var.message_ordering
}

resource "google_storage_bucket" "dev-csye6225-func-bucket-us" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.gcp_region
  encryption {
   default_kms_key_name = data.google_kms_crypto_key.storage-key.id
  }
  force_destroy = true
  depends_on = [google_kms_crypto_key_iam_binding.storage-key-binding]
}

resource "google_storage_bucket_object" "serverless_zip" {
  name   = var.source_archive_object
  source = "./../${var.source_archive_object}"
  bucket = google_storage_bucket.dev-csye6225-func-bucket-us.name
  depends_on = [ google_storage_bucket.dev-csye6225-func-bucket-us ]
}

data "google_storage_project_service_account" "bucket_service_account" {
}

resource "google_cloudfunctions_function" "email_verification" {
  name    = var.email_verification_name
  runtime = var.node_runtime

  available_memory_mb   = var.cloud_func_memory
  source_archive_bucket = var.bucket_name
  source_archive_object = var.source_archive_object
  event_trigger {
    event_type = var.pubsub_trigger_event
    resource   = google_pubsub_topic.trigger_email.name
    //"projects/${var.project_id}/topics/${google_pubsub_topic.trigger_email.name}"
  }
  entry_point = var.entry_point
  timeout     = var.cloud_function_timeout

  environment_variables = {
    BUCKET_NAME = var.bucket_name
    TOPIC_NAME  = google_pubsub_topic.trigger_email.name
    DATABASE    = var.db_name
    USERNAME    = google_sql_user.db_user.name
    PASSWORD    = google_sql_user.db_user.password
    HOST        = google_compute_address.endpoint_ip_addr.address
    DIALECT     = var.db_dialect
    DB_PORT     = var.db_port
    API_KEY     = var.api_key
    DOMAIN      = var.domain
  }

  service_account_email = google_service_account.cloudfunction_service_account.email
  vpc_connector         = google_vpc_access_connector.vpc_connector.name
  depends_on = [ google_storage_bucket_object.serverless_zip, google_storage_bucket.dev-csye6225-func-bucket-us ]
}

resource "google_cloudfunctions_function_iam_binding" "func_binding" {
  project        = google_cloudfunctions_function.email_verification.project
  region         = google_cloudfunctions_function.email_verification.region
  cloud_function = google_cloudfunctions_function.email_verification.name
  role           = var.viewer_role
  members = [
    "serviceAccount:${google_service_account.cloudfunction_service_account.email}"
  ]
}

resource "google_pubsub_subscription_iam_binding" "pubsub_editor" {
  subscription = google_pubsub_subscription.check_user.name
  role         = var.editor_role
  members = [
    "serviceAccount:${google_service_account.cloudfunction_service_account.email}"
  ]
}

resource "google_pubsub_topic_iam_binding" "binding" {
  project = google_pubsub_topic.trigger_email.project
  topic   = google_pubsub_topic.trigger_email.name
  role    = var.viewer_role
  members = [
    "serviceAccount:${google_service_account.cloudfunction_service_account.email}"
  ]
}

resource "google_vpc_access_connector" "vpc_connector" {
  name          = var.vpc_connector_name
  network       = google_compute_network.custom-vpc.self_link
  ip_cidr_range = var.ip_cidr_range
}
# ---------- # ---------- # ---------- # ---------- # ----------


# ---------- # ---------- # ---------- # ---------- # ----------
# Managed Instance Group
# Regional Instance Template
#
# ---------- # ---------- # ---------- # ---------- # ----------

# IAM binding on the service account used by Cloud Functions
resource "google_project_iam_binding" "cloud_function_invoker" {
  project = var.project_id
  role    = var.cloud_function_invoker

  members = [
    "serviceAccount:${google_service_account.cloudfunction_service_account.email}"
  ]
}

resource "google_project_iam_binding" "cloudsql_client_binding" {
  project = var.project_id
  role    = var.cloud_sql_client

  members = [
    "serviceAccount:${google_service_account.cloudfunction_service_account.email}"
  ]
}

resource "google_project_iam_binding" "disk_admin_binding" {
  project = var.project_id
  role    = var.compute_admin

  members = [
    "serviceAccount:${google_service_account.cloudfunction_service_account.email}"
  ]
}
locals {
  timestamp = formatdate("MMDDhhmmss", timestamp())
}
# Infra
resource "google_compute_region_instance_template" "webapp_template" {
  # name         = var.webapp_template
  name         = "${var.webapp_template}-${local.timestamp}"
  machine_type = var.machine_type
  
  disk {
    auto_delete  = true
    device_name  = var.server_name
    source_image = "projects/${var.project_id}/global/images/${var.image_id}"
    disk_size_gb = var.disk_size
    disk_type    = var.disk_type
    disk_encryption_key {
      kms_key_self_link = data.google_kms_crypto_key.vm-key.id
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

  service_account {
    email  = google_service_account.webapp_service_account.email
    scopes = ["logging-write", "monitoring-read", "monitoring-write", "cloud-platform"]
  }

  depends_on = [
    google_sql_database_instance.postgres_vm,
    google_sql_user.db_user,
    google_compute_address.endpoint_ip_addr,
    google_service_account.webapp_service_account,
    google_project_iam_binding.log_admin,
    google_project_iam_binding.metric_writer,
    google_project_iam_binding.pubsub_publisher
  ]
  tags = [var.network_tags]
}

resource "google_compute_region_instance_group_manager" "mig_mgr" {
  name                      = var.mig_mgr
  region                    = var.gcp_region
  distribution_policy_zones = [var.gcp_zone, var.gcp_zone_c, var.gcp_zone_d]
  base_instance_name        = var.server_name
  version {
    instance_template = google_compute_region_instance_template.webapp_template.self_link
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.http-health-check.self_link
    initial_delay_sec = var.auto_healing_init_delay
  }
  instance_lifecycle_policy {
    force_update_on_repair    = var.force_repair
    default_action_on_failure = var.repair_on_failure
  }
  named_port {
    name = var.named_port_name
    port = var.named_port
  }
  depends_on = [google_compute_region_instance_template.webapp_template]
}

resource "google_compute_region_autoscaler" "webapp_autoscaler" {
  name   = var.webapp_autoscaler
  region = var.gcp_region
  target = google_compute_region_instance_group_manager.mig_mgr.id

  autoscaling_policy {
    max_replicas    = var.max_instance_count
    min_replicas    = var.min_instance_count
    cooldown_period = var.auto_scaling_cooldown

    cpu_utilization {
      target = var.cpu_util
    }
  }
  depends_on = [google_compute_region_instance_group_manager.mig_mgr]
}

# Load balancing
resource "google_compute_health_check" "http-health-check" {
  name = var.http_health_check

  timeout_sec         = var.hc_check_interval_sec
  check_interval_sec  = var.hc_check_interval_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port         = var.http_hc_port
    port_name    = var.http_hc_port_name
    request_path = var.http_hc_request_path
  }
  log_config {
    enable = var.http_hc_logging
  }
}

resource "google_compute_url_map" "lb_mapping" {
  name            = var.lb_mapping
  default_service = google_compute_backend_service.webapp_backend_service.self_link
}

resource "google_compute_backend_service" "webapp_backend_service" {
  name                  = var.webapp_backend_service
  load_balancing_scheme = var.load_balancing_scheme
  health_checks         = [google_compute_health_check.http-health-check.self_link]
  protocol              = var.backend_protocol
  port_name             = var.backend_port_name
  log_config {
    enable = true
  }
  backend {
    group = google_compute_region_instance_group_manager.mig_mgr.instance_group
  }
}

resource "google_compute_managed_ssl_certificate" "lb_ssl_certificate" {
  name = var.ssl_cert
  managed {
    domains = var.ssl_cert_domains
  }
}

resource "google_compute_target_https_proxy" "lb_target_proxy" {
  name    = var.lb_https_proxy
  url_map = google_compute_url_map.lb_mapping.self_link
  ssl_certificates = [
    google_compute_managed_ssl_certificate.lb_ssl_certificate.id
  ]
}
# ---------- # ---------- # ---------- # ---------- # ----------

# ---------- # ---------- # ---------- # ---------- # ----------
# CMEK
# 
#
# ---------- # ---------- # ---------- # ---------- # ----------
#
#
#
#

# data "google_kms_key_ring" "keyring" {
#   name     = "keyring"
#   location = "global"
# }

# resource "google_kms_key_ring" "keyring-us" {
#   name     = "keyring"
#   location = var.gcp_region
# }

data "google_kms_key_ring" "keyring-us" {
  name     = "keyring"
  location = var.gcp_region
}

data "google_kms_crypto_key" "storage-key" {
  key_ring        = data.google_kms_key_ring.keyring-us.id
  name            = "storage-key"
  depends_on = [data.google_kms_key_ring.keyring-us]
}

data "google_kms_crypto_key" "sql-key" {
  key_ring        = data.google_kms_key_ring.keyring-us.id
  name            = "sql-key"
  depends_on = [data.google_kms_key_ring.keyring-us]
}

data "google_kms_crypto_key" "vm-key" {
  key_ring        = data.google_kms_key_ring.keyring-us.id
  name            = "vm-key"
  depends_on = [data.google_kms_key_ring.keyring-us]
}

# resource "google_kms_crypto_key" "vm-key" {
#   name            = "vm-key"
#   key_ring        = data.google_kms_key_ring.keyring-us.id
#   rotation_period = var.rotation_period

#   lifecycle {
#     prevent_destroy = false
#   }
#   depends_on = [data.google_kms_key_ring.keyring-us]
# }

# resource "google_kms_crypto_key" "sql-key" {
#   name            = "sql-key"
#   key_ring        = data.google_kms_key_ring.keyring-us.id
#   rotation_period = var.rotation_period

#   lifecycle {
#     prevent_destroy = false
#   }
#   depends_on = [data.google_kms_key_ring.keyring-us]
# }

# resource "google_kms_crypto_key" "storage-key" {
#   name            = "storage-key"
#   key_ring        = data.google_kms_key_ring.keyring-us.id
#   rotation_period = var.rotation_period

#   lifecycle {
#     prevent_destroy = false
#   }
#   depends_on = [data.google_kms_key_ring.keyring-us]
# }

resource "google_kms_key_ring_iam_binding" "keyring-binding" {
  key_ring_id = data.google_kms_key_ring.keyring-us.id
  role          = var.kms_admin_role

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}",
    //"serviceAccount:${data.google_storage_project_service_account.bucket_service_account.email_address}"
  ]
}

resource "google_kms_crypto_key_iam_binding" "vm-key-binding" {
  crypto_key_id = data.google_kms_crypto_key.vm-key.id
  role          = var.key_binding

  members = [
    "serviceAccount:${google_service_account.webapp_service_account.email}"
  ]
}

resource "google_kms_crypto_key_iam_binding" "sql-key-binding" {
  crypto_key_id = data.google_kms_crypto_key.sql-key.id
  role          = var.key_binding

  members = [
    //"serviceAccount:${google_sql_database_instance.postgres_vm.service_account_email_address}",
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}"
  ]
}

resource "google_project_iam_binding" "project" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}"
  ]
}


resource "google_kms_crypto_key_iam_binding" "storage-key-binding" {
  crypto_key_id = data.google_kms_crypto_key.storage-key.id
  role          = var.key_binding

  members = [
    # "serviceAccount:${google_service_account.webapp_service_account.email}",
    # "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
    "serviceAccount:${data.google_storage_project_service_account.bucket_service_account.email_address}"
  ]
}



