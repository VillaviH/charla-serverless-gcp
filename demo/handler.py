"""
API REST de Tareas — Demo Serverless GCP
=========================================
Servicios: Cloud Functions (Gen 2) + Firestore
Charla: "Despliega como Senior, paga como estudiante"

Equivalencias AWS → GCP:
  Lambda        → Cloud Functions (Gen 2)
  API Gateway   → URL directa de Cloud Functions (HTTPS automático)
  DynamoDB      → Firestore (NoSQL serverless)
  S3 website    → Cloud Storage (static website)
  IAM Role      → Service Account

Endpoints:
  GET    /tasks          → Lista todas las tareas
  GET    /tasks/{id}     → Obtiene una tarea por ID
  POST   /tasks          → Crea una nueva tarea
  PUT    /tasks/{id}     → Actualiza una tarea
  DELETE /tasks/{id}     → Elimina una tarea
"""

import json
import os
import uuid
from datetime import datetime, timezone

import functions_framework
from google.cloud import firestore

# Cliente de Firestore — usa las credenciales del Service Account automáticamente
db             = firestore.Client()
COLLECTION     = os.environ.get('COLLECTION_NAME', 'tasks')


# ─────────────────────────────────────────
# Entry point — Cloud Functions lo llama aquí
# @functions_framework.http es el equivalente al handler de Lambda
# ─────────────────────────────────────────
@functions_framework.http
def tasks_api(request):
    """HTTP Cloud Function — maneja todos los endpoints de la API."""

    # CORS preflight (OPTIONS)
    if request.method == 'OPTIONS':
        return build_cors_response()

    method = request.method
    path   = request.path

    # Normalizar path (quitar trailing slash)
    path = path.rstrip('/') or '/'

    # Routing
    if method == 'GET' and path == '/tasks':
        return get_all_tasks()

    elif method == 'GET' and path.startswith('/tasks/'):
        task_id = path.split('/')[-1]
        return get_task(task_id)

    elif method == 'POST' and path == '/tasks':
        body = request.get_json(silent=True) or {}
        return create_task(body)

    elif method == 'PUT' and path.startswith('/tasks/'):
        task_id = path.split('/')[-1]
        body    = request.get_json(silent=True) or {}
        return update_task(task_id, body)

    elif method == 'DELETE' and path.startswith('/tasks/'):
        task_id = path.split('/')[-1]
        return delete_task(task_id)

    return build_response(405, {'error': f'Method not allowed: {method} {path}'})


# ─────────────────────────────────────────
# Handlers CRUD
# ─────────────────────────────────────────
def get_all_tasks():
    """Lista todas las tareas de la colección Firestore."""
    docs  = db.collection(COLLECTION).order_by(
        'created_at', direction=firestore.Query.DESCENDING
    ).stream()
    tasks = [{'id': doc.id, **doc.to_dict()} for doc in docs]
    return build_response(200, tasks)


def get_task(task_id):
    """Obtiene una tarea por su ID."""
    doc = db.collection(COLLECTION).document(task_id).get()

    if not doc.exists:
        return build_response(404, {'error': f'Task {task_id} not found'})

    return build_response(200, {'id': doc.id, **doc.to_dict()})


def create_task(body):
    """Crea una nueva tarea."""
    title = (body.get('title') or '').strip()

    if not title:
        return build_response(400, {'error': 'Field "title" is required'})

    task_id = str(uuid.uuid4())
    task    = {
        'title':      title,
        'completed':  False,
        'created_at': datetime.now(timezone.utc).isoformat(),
    }

    db.collection(COLLECTION).document(task_id).set(task)
    return build_response(201, {'id': task_id, **task})


def update_task(task_id, body):
    """Actualiza el título y/o estado de una tarea."""
    ref = db.collection(COLLECTION).document(task_id)
    doc = ref.get()

    if not doc.exists:
        return build_response(404, {'error': f'Task {task_id} not found'})

    title     = (body.get('title') or '').strip()
    completed = body.get('completed')

    if not title:
        return build_response(400, {'error': 'Field "title" is required'})
    if completed is None:
        return build_response(400, {'error': 'Field "completed" is required'})

    ref.update({
        'title':      title,
        'completed':  bool(completed),
        'updated_at': datetime.now(timezone.utc).isoformat(),
    })

    return build_response(200, {'message': 'Task updated', 'id': task_id})


def delete_task(task_id):
    """Elimina una tarea por su ID."""
    ref = db.collection(COLLECTION).document(task_id)
    doc = ref.get()

    if not doc.exists:
        return build_response(404, {'error': f'Task {task_id} not found'})

    ref.delete()
    return build_response(200, {'message': 'Task deleted', 'id': task_id})


# ─────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────
def build_response(status_code, body):
    """Construye la respuesta HTTP con headers CORS."""
    import flask
    response = flask.make_response(
        json.dumps(body, default=str),
        status_code
    )
    response.headers['Content-Type']                = 'application/json'
    response.headers['Access-Control-Allow-Origin']  = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    return response


def build_cors_response():
    """Respuesta para el preflight CORS (OPTIONS)."""
    import flask
    response = flask.make_response('', 204)
    response.headers['Access-Control-Allow-Origin']  = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    return response
