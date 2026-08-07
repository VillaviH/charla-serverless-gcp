terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ─────────────────────────────────────────
# APIs de GCP — habilitar los servicios necesarios
# Equivalente a que AWS tenga los servicios disponibles por defecto
# ─────────────────────────────────────────
resource "google_project_service" "cloudfunctions" {
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# ─────────────────────────────────────────
# Firestore — Base de datos NoSQL
# Equivalente a DynamoDB en AWS
# Serverless: pagas por operación, no por capacidad
# ─────────────────────────────────────────
resource "google_firestore_database" "tasks_db" {
  name        = "(default)"
  location_id = var.gcp_region
  type        = "FIRESTORE_NATIVE"

  # Al hacer `terraform destroy` la base de datos se elimina también.
  # Útil para repetir el demo desde cero; en producción usa "ABANDON".
  deletion_policy = "DELETE"

  depends_on = [google_project_service.firestore]
}

# ─────────────────────────────────────────
# Service Account — Identidad de la Cloud Function
# Equivalente al IAM Role de Lambda en AWS
# ─────────────────────────────────────────
resource "google_service_account" "function_sa" {
  account_id   = "${var.project_name}-fn-sa"
  display_name = "${var.project_name} Cloud Function Service Account"
}

# Permiso para leer/escribir en Firestore
resource "google_project_iam_member" "function_firestore" {
  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# ─────────────────────────────────────────
# Cloud Storage — Bucket para el código fuente
# Cloud Functions Gen 2 requiere subir el código a GCS primero
# ─────────────────────────────────────────
resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_name}-fn-source-${random_id.suffix.hex}"
  location                    = var.gcp_region
  force_destroy               = true
  uniform_bucket_level_access = true

  labels = {
    project = var.project_name
    env     = var.environment
  }
}

# Empaquetar el código de la función en un ZIP
data "archive_file" "function_zip" {
  type        = "zip"
  output_path = "${path.module}/function.zip"

  source {
    content  = file("${path.module}/../handler.py")
    filename = "main.py"   # GCP espera main.py por convención
  }

  source {
    content  = file("${path.module}/../requirements.txt")
    filename = "requirements.txt"
  }
}

# Subir el ZIP al bucket de código fuente
resource "google_storage_bucket_object" "function_zip" {
  name   = "function-${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_zip.output_path
}

# ─────────────────────────────────────────
# Cloud Function (Gen 2) — Lógica de la API
# Equivalente a Lambda en AWS
# Gen 2 usa Cloud Run internamente → mejor cold start y más features
# ─────────────────────────────────────────
resource "google_cloudfunctions2_function" "tasks_api" {
  name     = "${var.project_name}-api"
  location = var.gcp_region

  build_config {
    runtime     = "python312"
    entry_point = "tasks_api"   # Nombre de la función en handler.py (main.py)

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0          # Serverless: escala a cero cuando no hay tráfico
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.function_sa.email

    environment_variables = {
      COLLECTION_NAME = "tasks"
      ENVIRONMENT     = var.environment
    }
  }

  labels = {
    project = var.project_name
    env     = var.environment
  }

  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild,
    google_project_service.run,
    google_project_service.artifactregistry,
    google_firestore_database.tasks_db,
  ]
}

# Permitir invocaciones públicas (sin autenticación)
# Equivalente al aws_lambda_permission para API Gateway
resource "google_cloud_run_service_iam_member" "public_invoker" {
  project  = var.gcp_project_id
  location = var.gcp_region
  service  = google_cloudfunctions2_function.tasks_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ─────────────────────────────────────────
# Cloud Storage — Frontend estático
# Equivalente a S3 static website hosting en AWS
# ─────────────────────────────────────────
resource "google_storage_bucket" "frontend" {
  name                        = "${var.project_name}-frontend-${random_id.suffix.hex}"
  location                    = var.gcp_region
  force_destroy               = true
  uniform_bucket_level_access = false   # Necesario para ACLs públicas en website hosting

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  labels = {
    project = var.project_name
    env     = var.environment
  }
}

# Acceso público de lectura al bucket del frontend
resource "google_storage_bucket_iam_member" "frontend_public" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Inyectar la URL de la Cloud Function en el HTML y subirlo
resource "google_storage_bucket_object" "index_html" {
  name   = "index.html"
  bucket = google_storage_bucket.frontend.name

  content = replace(
    file("${path.module}/../frontend/index.html"),
    "API_GATEWAY_URL_PLACEHOLDER",
    google_cloudfunctions2_function.tasks_api.service_config[0].uri
  )

  content_type = "text/html"
}
