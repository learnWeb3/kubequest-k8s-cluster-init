# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/28"
}

# [END gke_private_cluster_nat_gke]

# [START vpc_firewall_nat_gke]
resource "google_compute_firewall" "ssh_rule" {
  project = var.project_id
  name    = "allow-ssh"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_service_accounts = [
    "kubequest-cluster-ssh-access@kubequest.iam.gserviceaccount.com",
  ]
}
# [END vpc_firewall_nat_gke]

resource "google_compute_firewall" "istio_rule" {
  name          = "gke-${google_container_cluster.primary.name}-istio"
  network       = google_compute_network.vpc.name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["10250", "443", "15017"]
  }

}

# [START cloudnat_router_nat_gke]
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "nat-router"
  network = google_compute_network.vpc.name
  region  = var.region
}
# [END cloudnat_router_nat_gke]

# [START cloudnat_nat_gke]
module "cloud-nat" {
  source                             = "terraform-google-modules/cloud-nat/google"
  version                            = "~> 5.0"
  project_id                         = var.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  name                               = "nat-config"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
# [END cloudnat_nat_gke]
