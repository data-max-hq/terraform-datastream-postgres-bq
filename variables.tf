variable "project" {
  type    = string
  default = "gcp-iac-data-stack"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "proxy_machine_type" {
  type    = string
  default = "e2-micro"
}

variable "network_name" {
  type    = string
  default = "default"
}