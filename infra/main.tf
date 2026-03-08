# Habilitar APIs necessárias
resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false # Permite que o terraform destroy desabilite a API
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false # Permite que o terraform destroy desabilite a API
}

# Artifact Registry para armazenar as imagens Docker
resource "google_artifact_registry_repository" "repo" {
  location      = "us-central1"
  repository_id = "desafio-pleno-repo"
  description   = "Repositorio Docker para a API"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifactregistry]
}

# Cluster GKE
resource "google_container_cluster" "primary" {
  name     = "desafio-pleno-cluster"
  location = "us-central1"

  # Remove o node pool padrão para usarmos um gerenciado separadamente
  remove_default_node_pool = true

  # Desabilita proteção de deleção para facilitar testes/destruição
  deletion_protection = false

  depends_on = [google_project_service.container]
}

# Node Pool Gerenciado
resource "google_container_node_pool" "primary_nodes" {
  name       = "desafio-pleno-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1 # 1 nó é suficiente para um teste simples

  node_config {
    preemptible  = true # Mais barato (Spot instances)
    machine_type = "e2-medium"
    disk_size_gb = 20

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}