# Habilitar APIs necessárias
resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false # Não desabilita a API ao destruir (evita erros em projetos compartilhados)
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false # Não desabilita a API ao destruir (evita erros em projetos compartilhados)
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
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Desabilita proteção de deleção para facilitar testes/destruição
  deletion_protection = false

  depends_on = [google_project_service.container]
}

# --- Configuração dos Providers para Helm ---
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

# --- Stack de Monitoramento (Prometheus + Grafana) ---
resource "helm_release" "prometheus_stack" {
  name             = "prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "57.0.1"

  depends_on = [google_container_cluster.primary]

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          replicas = 1
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = { requests = { storage = "8Gi" } }
              }
            }
          }
        }
        # Expõe o Prometheus via LoadBalancer
        service = {
          type = "LoadBalancer"
        }
      }
      grafana = {
        persistence = { enabled = true, size = "2Gi" }
        adminPassword = "admin"
        # Expõe o Grafana via LoadBalancer
        service = {
          type = "LoadBalancer"
        }
        sidecar = {
          dashboards = {
            enabled = true
            searchNamespace = "default"
          }
        }
      }
      alertmanager = { enabled = false }
    })
  ]
}