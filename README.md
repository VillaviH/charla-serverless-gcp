# Despliega como Senior, paga como estudiante
### Serverless en GCP: Cloud Functions + Firestore + Cloud Storage + Terraform

> Versión GCP de la charla presentada para la Universidad de Cuenca · 2026  
> AWS User Group Quito

---

## Equivalencias AWS → GCP

| AWS | GCP | Para qué |
|-----|-----|----------|
| Lambda | Cloud Functions (Gen 2) | Lógica de la API |
| API Gateway | URL directa de Cloud Functions | Endpoints HTTP públicos |
| DynamoDB | Firestore | Base de datos NoSQL serverless |
| S3 static website | Cloud Storage (website hosting) | Frontend estático |
| IAM Role | Service Account | Permisos de la función |
| CloudWatch Logs | Cloud Logging | Logs y observabilidad |

```
Browser → Cloud Function (HTTPS) → Firestore
              ↑
    Cloud Storage (frontend estático)
```

**Costo total: $0** — todo entra en el Free Tier de GCP.

---

## Prerrequisitos

| Herramienta | Versión mínima | Instalación |
|-------------|---------------|-------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.0 | `brew install terraform` |
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | >= 450 | `brew install --cask google-cloud-sdk` |
| Cuenta GCP | Free Tier | [cloud.google.com/free](https://cloud.google.com/free) |
| Python | >= 3.10 | Solo para leer el código |

---

## Configurar credenciales GCP

```bash
# 1. Autenticarse con tu cuenta Google
gcloud auth login

# 2. Crear o seleccionar un proyecto
gcloud projects create mi-proyecto-serverless   # o usa uno existente
gcloud config set project mi-proyecto-serverless

# 3. Habilitar credenciales para Terraform (Application Default Credentials)
gcloud auth application-default login

# 4. Verificar que funciona
gcloud config get-value project
```

> **Nota:** Terraform usa Application Default Credentials automáticamente.  
> No necesitas crear ni descargar claves JSON.

---

## Desplegar en 3 comandos

```bash
# 1. Entrar a la carpeta de Terraform
cd charla-serverless-gcp/demo/terraform

# 2. Inicializar Terraform (descarga el provider de GCP)
terraform init

# 3. Desplegar toda la infraestructura
terraform apply -var="gcp_project_id=TU_PROJECT_ID"
# → Escribe "yes" cuando te lo pida
# → Espera ~2-3 minutos (el build de Cloud Functions tarda un poco más que Lambda)
```

Al terminar, Terraform imprime las URLs:

```
api_url      = "https://us-central1-mi-proyecto.cloudfunctions.net/tasks-demo-api/tasks"
frontend_url = "https://storage.googleapis.com/tasks-demo-frontend-xxxx/index.html"
```

Abre `frontend_url` en el browser y ya tienes la app funcionando.

---

## Probar la API con curl

```bash
# Guardar la URL base
export BASE=$(terraform output -raw api_url | sed 's|/tasks||')

# Crear una tarea
curl -s -X POST "$BASE/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "Mi primera tarea serverless en GCP ☁️"}' | python3 -m json.tool

# Listar tareas
curl -s "$BASE/tasks" | python3 -m json.tool

# O usar el script automático
BASE_URL=$BASE ../test-api.sh
```

---

## Estructura del proyecto

```
charla-serverless-gcp/
└── demo/
    ├── handler.py               # Código de la Cloud Function — toda la lógica de la API
    ├── requirements.txt         # Dependencias Python (functions-framework, firestore)
    ├── test-api.sh              # Script para probar todos los endpoints
    ├── frontend/
    │   └── index.html           # Frontend estático (Terraform lo sube a Cloud Storage)
    └── terraform/
        ├── main.tf              # Recursos: Firestore, Cloud Function, Cloud Storage
        ├── variables.tf         # Parámetros configurables
        └── outputs.tf           # URLs que imprime Terraform al terminar
```

---

## Recursos que crea Terraform

| Recurso | Nombre | Para qué |
|---------|--------|----------|
| `google_firestore_database` | `(default)` | Base de datos NoSQL |
| `google_cloudfunctions2_function` | `tasks-demo-api` | Lógica de la API |
| `google_storage_bucket` (código) | `tasks-demo-fn-source-xxxx` | ZIP del código fuente |
| `google_storage_bucket` (frontend) | `tasks-demo-frontend-xxxx` | Frontend estático |
| `google_service_account` | `tasks-demo-fn-sa` | Identidad de la función |

---

## Diferencias clave vs la versión AWS

### Routing más simple
En AWS necesitabas API Gateway con recursos, métodos e integraciones.  
En GCP, Cloud Functions Gen 2 expone una URL HTTPS directamente — el routing lo hace el código Python.

### Sin módulos de Terraform para métodos HTTP
El `main.tf` de AWS tenía módulos `lambda_method` y `cors_options` para cada endpoint.  
En GCP no existe ese concepto: una sola función maneja todos los métodos.

### Firestore vs DynamoDB
- DynamoDB usa `hash_key` y `billing_mode = "PAY_PER_REQUEST"`
- Firestore usa colecciones/documentos sin esquema, sin configuración de capacidad

### Build en la nube
Cloud Functions Gen 2 compila el código en Cloud Build (en la nube).  
Lambda ejecuta el ZIP directamente.

---

## Limpiar todo al terminar

```bash
terraform destroy -var="gcp_project_id=TU_PROJECT_ID"
# → Escribe "yes"
# → En ~1 minuto borra todo
```

---

## Personalizar el proyecto

Edita `demo/terraform/variables.tf` o pasa variables en el comando:

```bash
terraform apply \
  -var="gcp_project_id=mi-proyecto" \
  -var="gcp_region=southamerica-east1" \
  -var="project_name=mi-app"
```

> **Regiones cercanas a Latinoamérica:**  
> `southamerica-east1` (São Paulo) · `northamerica-northeast1` (Montreal)

---

## Solución de problemas comunes

| Error | Causa | Solución |
|-------|-------|----------|
| `Error 403: The caller does not have permission` | APIs no habilitadas | Terraform las habilita automáticamente, espera 1 min y reintenta |
| `Error creating Database: ... already exists` | Firestore ya existe en el proyecto | Importa: `terraform import google_firestore_database.tasks_db "(default)"` |
| `Build failed` en Cloud Functions | Error en requirements.txt | Revisa versiones en `requirements.txt` |
| `502` en la función | Error en el código Python | `gcloud functions logs read tasks-demo-api --region=us-central1` |
| `Application Default Credentials not found` | gcloud no autenticado | `gcloud auth application-default login` |

---

## Recursos para seguir aprendiendo

- [GCP Free Tier](https://cloud.google.com/free) — crea tu cuenta gratis
- [Cloud Functions Gen 2 docs](https://cloud.google.com/functions/docs/concepts/version-comparison)
- [Firestore docs](https://cloud.google.com/firestore/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [functions-framework-python](https://github.com/GoogleCloudPlatform/functions-framework-python)

---

## Autor

**Hernán Villavicencio**  
AWS User Group Quito  
[linkedin.com/in/hvillavicencio](https://linkedin.com/in/hvillavicencio)
