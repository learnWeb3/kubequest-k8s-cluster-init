module "infra" {
  source     = "./infra"
  project_id = var.GOOGLE_PROJECT_ID
  region     = var.GOOGLE_PROJECT_REGION
}