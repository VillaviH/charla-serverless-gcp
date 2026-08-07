variable "gcp_project_id" {
  description = "ID del proyecto GCP donde se despliega la infraestructura"
  type        = string
  # Obtén tu project ID con: gcloud config get-value project
}

variable "gcp_region" {
  description = "Región de GCP donde se despliegan los recursos"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Nombre del proyecto (se usa como prefijo en todos los recursos)"
  type        = string
  default     = "tasks-demo"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "prod"
}
