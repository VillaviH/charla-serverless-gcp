#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# test-api.sh — Prueba todos los endpoints de la API en GCP
# Uso: BASE_URL=https://xxx.cloudfunctions.net/tasks-demo-api ./test-api.sh
# ─────────────────────────────────────────────────────────────

BASE_URL="${BASE_URL:-$(cd "$(dirname "$0")/terraform" && terraform output -raw api_url | sed 's|/tasks||')}"

echo ""
echo "🧪 Probando API en: $BASE_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Crear tarea
echo ""
echo "1️⃣  POST /tasks — Crear tarea"
TASK=$(curl -s -X POST "$BASE_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "Mi primera tarea serverless en GCP ☁️"}')
echo "$TASK" | python3 -m json.tool
TASK_ID=$(echo "$TASK" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# 2. Listar tareas
echo ""
echo "2️⃣  GET /tasks — Listar todas"
curl -s "$BASE_URL/tasks" | python3 -m json.tool

# 3. Obtener por ID
echo ""
echo "3️⃣  GET /tasks/$TASK_ID — Obtener por ID"
curl -s "$BASE_URL/tasks/$TASK_ID" | python3 -m json.tool

# 4. Actualizar
echo ""
echo "4️⃣  PUT /tasks/$TASK_ID — Actualizar"
curl -s -X PUT "$BASE_URL/tasks/$TASK_ID" \
  -H "Content-Type: application/json" \
  -d '{"title": "Tarea actualizada ✅", "completed": true}' | python3 -m json.tool

# 5. Eliminar
echo ""
echo "5️⃣  DELETE /tasks/$TASK_ID — Eliminar"
curl -s -X DELETE "$BASE_URL/tasks/$TASK_ID" | python3 -m json.tool

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Tests completados"
