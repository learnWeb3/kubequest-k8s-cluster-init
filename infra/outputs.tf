output "cluster_endpoint" {
  value       = "https://${google_container_cluster.primary.endpoint}"
  description = "cluster endpoint"
}
output "cluster_ca_certificate" {
  value       = base64encode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  description = "cluster ca certificate"
}
output "access_token" {
  value       = base64encode(data.google_client_config.default.access_token)
  description = "cluster access token"
}
