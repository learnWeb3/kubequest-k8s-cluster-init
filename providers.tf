terraform {
  backend "gcs" {
    # bucket = "kubequest"
    bucket = "kubequest-terraform"
    prefix = "/cluster"
  }
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
  required_version = ">= 0.14"
}

provider "google" {
  project = var.GOOGLE_PROJECT_ID
  region  = var.GOOGLE_PROJECT_REGION
}
