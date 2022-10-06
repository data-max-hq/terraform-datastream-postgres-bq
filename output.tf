output "proxy_private_ip" {
  value = google_compute_instance.default.network_interface.0.network_ip
}

output "proxy_nat_ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip 
}

output "db_public_ip" {
  value = google_sql_database_instance.instance.public_ip_address
}