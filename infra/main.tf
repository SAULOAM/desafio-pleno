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

  # Configura o node pool diretamente no cluster para evitar problemas de quota com SSDs.
  # Usar o node pool padrão é mais simples para este cenário.
  remove_default_node_pool = false
  initial_node_count       = 1

  node_config {
    # Usa instâncias preemptivas (Spot) para reduzir custos.
    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 10
    # Define explicitamente o tipo de disco como 'pd-standard' para evitar o uso de SSD
    # e contornar o erro de quota 'SSD_TOTAL_GB' excedida.
    disk_type = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Desabilita proteção de deleção para facilitar testes/destruição
  deletion_protection = false

  depends_on = [google_project_service.container]
}