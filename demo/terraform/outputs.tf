output "api_url" {
  description = "URL base de la Cloud Function — úsala para probar con curl"
  value       = "${google_cloudfunctions2_function.tasks_api.service_config[0].uri}/tasks"
}

output "function_name" {
  description = "Nombre de la Cloud Function"
  value       = google_cloudfunctions2_function.tasks_api.name
}

output "firestore_database" {
  description = "Nombre de la base de datos Firestore"
  value       = google_firestore_database.tasks_db.name
}

output "gcp_logs_url" {
  description = "URL directa a los logs de la Cloud Function en Cloud Logging"
  value       = "https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%20resource.labels.service_name%3D%22${google_cloudfunctions2_function.tasks_api.name}%22?project=${var.gcp_project_id}"
}

output "frontend_url" {
  description = "URL del frontend en Cloud Storage — ábrela en el browser"
  value       = "https://storage.googleapis.com/${google_storage_bucket.frontend.name}/index.html"
}

output "service_account_email" {
  description = "Email del Service Account de la Cloud Function"
  value       = google_service_account.function_sa.email
}
