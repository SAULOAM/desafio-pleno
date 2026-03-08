Resolvi Usar a GCP pra deployar a API, estou autenticando com o provider usando os comandos:

gcloud auth login

Adicionei a `required_version` no arquivo `provider.tf` para resolver um aviso do TFLint e garantir que o projeto use uma versão compatível do Terraform, evitando quebras inesperadas no futuro.
