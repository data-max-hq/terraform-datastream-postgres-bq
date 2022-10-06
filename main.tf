# Network

data "google_compute_network" "network" {
  provider = google-beta
  project  = var.project

  name = var.network_name
}

# Cloud SQL Private Postgres

resource "google_compute_global_address" "private_ip_address" {
  provider = google-beta
  project  = var.project

  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = data.google_compute_network.network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

data "external" "current_ip" {
  program = ["bash", "-c", "curl -s 'https://api.ipify.org?format=json'"]
}

resource "google_sql_database_instance" "instance" {
  provider = google-beta
  project  = var.project
  region   = var.region

  name             = "private-instance-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_14"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.db_tier
    ip_configuration {
      ipv4_enabled    = true
      private_network = data.google_compute_network.network.id

      authorized_networks {
        name = "on-prem"
        value = "${data.external.current_ip.result.ip}/32"
      }
    }

    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }
  }
}

# Datastream private connection

resource "google_datastream_private_connection" "default" {
  project               = var.project
  display_name          = "Private connection profile"
  location              = var.region
  private_connection_id = "my-connection"

  vpc_peering_config {
    vpc    = data.google_compute_network.network.id
    subnet = "10.1.0.0/29"
  }
}

resource "google_compute_firewall" "default" {
  project = var.project
  name    = "datastream-proxy-access"
  network = data.google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = [google_datastream_private_connection.default.vpc_peering_config.0.subnet]
}

# Proxy VM

resource "google_compute_instance" "default" {
  project      = var.project
  name         = "datastream-proxy"
  machine_type = var.proxy_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = data.google_compute_network.network.name

     access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<EOT
#!/bin/sh
apt-get update
sudo apt-get install wget
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
chmod +x cloud_sql_proxy
./cloud_sql_proxy -instances=${google_sql_database_instance.instance.connection_name}:pg-source=tcp:0.0.0.0:5432
  EOT

  service_account {
    scopes = ["cloud-platform"]
  }
}