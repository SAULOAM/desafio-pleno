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

# Service Account dedicada para os nós do GKE
resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes-sa"
  display_name = "GKE Nodes Service Account"
}

# Permissão para ler imagens do Artifact Registry
resource "google_artifact_registry_repository_iam_member" "gke_nodes_artifact_registry" {
  project    = google_artifact_registry_repository.repo.project
  location   = google_artifact_registry_repository.repo.location
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Cluster GKE
resource "google_container_cluster" "primary" {
  name     = "desafio-pleno-cluster"
  location = "us-central1-a"

  # Configura o node pool diretamente no cluster para evitar problemas de quota com SSDs.
  # Usar o node pool padrão é mais simples para este cenário.
  remove_default_node_pool = false
  initial_node_count       = 2

  node_config {
    # Usa instâncias preemptivas (Spot) para reduzir custos.
    preemptible     = true
    machine_type    = "e2-medium"
    disk_size_gb    = 30
    service_account = google_service_account.gke_nodes.email
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

# --- Configuração dos Providers para Helm e Kubernetes ---
# Estes providers são configurados dinamicamente para que o Terraform possa
# se autenticar no cluster GKE recém-criado e instalar os charts do Helm.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}
# --- Netdata para Monitoramento em Tempo Real ---
resource "helm_release" "netdata" {
  name             = "netdata"
  repository       = "https://netdata.github.io/helmchart/"
  chart            = "netdata"
  namespace        = "netdata"
  create_namespace = true

  depends_on = [google_container_cluster.primary]

  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
      }
      parent = {
        claiming = {
          enabled = false
        }
      }
    })
  ]
}