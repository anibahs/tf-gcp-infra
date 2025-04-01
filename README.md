# tf-gcp-infra

This Infrastructure hosts the [webapp](https://github.com/anibahs-csye6225/webapp) by setting up the required IAM, Networking, Database, Pub/Sub, Managed Instance Group, and Load Balancing resources.

## Technology:

- Terraform
- Google Cloud Platform
  
## Enable API Service on Google Cloud Platform

- Enable below APIs 
  - Compute Engine API
  - Service Networking API
  - Cloud DNS API
  - Cloud Logging API
  - Stackdriver Monitoring API
  - Artifact Registry API
  - Cloud Build API
  - Cloud Functions API
  - Cloud Key Management Service (KMS) API
  - Cloud Resource Manager API
  - Container Registry API
  - Cloud Deployment Manager V2 API
  - Global Edge Cache Service
  - Eventarc API
  - Cloud Monitoring API
  - Network Management API
  - Cloud OS Login API
  - Cloud Pub/Sub API
  - Cloud Run Admin API
  - Service Directory API
  - Legacy Cloud Source Repositories API
  - Cloud SQL Admin API
  - Google Cloud Storage JSON API
  - Cloud Storage
  - Serverless VPC Access API

## Resources

-  Networking
  -  google_compute_network
  -  google_compute_subnetwork - database, webapp, proxy
  -  google_compute_route
  -  google_compute_global_address
  -  google_compute_global_forwarding_rule
  -  google_compute_firewall
-  Database
  -  google_compute_address
  -  google_compute_forwarding_rule
  -  google_compute_global_address
  -  google_service_networking_connection
  -  random_id - db name and password
  -  google_sql_database_instance
  -  google_sql_database
  -  google_sql_user
  -  google_dns_record_set
  -  google_service_account
  -  google_project_iam_binding - log_admin, metric_writer, pubsub publisher
-  MIG
  -  google_project_iam_binding - cloud_function_invoker, cloudsql_client_binding, disk_admin_binding
  -  google_compute_region_instance_template
  -  google_compute_region_instance_group_manager
  -  google_compute_region_autoscaler
  -  google_compute_url_map
  -  google_compute_backend_service
  -  google_compute_managed_ssl_certificate
  -  google_compute_target_https_proxy
-  Pub/Sub
  -  google_pubsub_topic
  -  google_pubsub_subscription
  -  google_cloudfunctions_function
  -  google_cloudfunctions_function_iam_binding
  -  google_pubsub_subscription_iam_binding - pubsub editor
  -  google_pubsub_topic_iam_binding
  -  google_vpc_access_connector

## Infrastructure deployment

- Clone repository 
- Setup and login to GCLI, as it sets up the credentials
- Setup terraform.tfvars / pass variables through cli
- Run terraform init, plan
- Run Terraform apply to deploy resources.

## Lessons learned

The project covered several topics like applying autoscaling and maintaining high availability for the webapp service, and setting up an event driven architecture to handle asynchronous user verification.

