terraform {
  required_version = ">= 1.3" # Garante que o código rode com uma versão compatível do Terraform

  backend "gcs" {
    bucket = "terraform-state-projeto-globo-489614"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = "projeto-globo-489614"
  region  = "us-central1"
}