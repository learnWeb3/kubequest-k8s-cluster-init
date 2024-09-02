# GKE cluster
data "google_container_engine_versions" "gke_version" {
  location       = var.region
  version_prefix = "1.30."
}

resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location = "${var.region}-a"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  release_channel {
    channel = "RAPID"
  }

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "10.13.0.0/28"
  }

  # required for k8s api server oidc authentication (gke (vendor) specific)
  identity_service_config {
    enabled = true
  }

  # explicitly allows all ips ranges to access the master 
  # This is required to access the public endpoint as well
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
    }
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.11.0.0/21"
    services_ipv4_cidr_block = "10.12.0.0/21"
  }
  /** REQUIREMENT FOR ISTIO */

  // Required for Calico, optional otherwise.
  // Configuration options for the NetworkPolicy feature
  network_policy {
    enabled  = true
    provider = "CALICO" // CALICO is currently the only supported provider
  }

  // Required for network_policy enabled cluster, optional otherwise
  // Addons config supports other options as well, see:
  // https://www.terraform.io/docs/providers/google/r/container_cluster.html#addons_config
  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  // This is required to workaround a perma-diff bug in terraform:
  // see: https://github.com/terraform-providers/terraform-provider-google/issues/1382
  lifecycle {
    ignore_changes = [
      ip_allocation_policy,
      network,
      subnetwork,
    ]
  }
}


# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name     = google_container_cluster.primary.name
  location = "${var.region}-a"
  cluster  = google_container_cluster.primary.name

  version    = data.google_container_engine_versions.gke_version.release_channel_latest_version["RAPID"]
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = "e2-standard-2"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Specify disk storage
    disk_size_gb = 50            # Set the disk size in GB, e.g., 50 GB
    disk_type    = "pd-standard" # Specify disk type, e.g., "pd-standard" or "pd-ssd"
  }
}


data "google_client_config" "default" {}

data "template_file" "kubeconfig" {
  template = file("kubeconfig.tpl")

  vars = {
    cluster_name           = google_container_cluster.primary.name
    cluster_endpoint       = "https://${google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    access_token           = data.google_client_config.default.access_token
  }
}

resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "kubeconfig"
}


