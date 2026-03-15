#!/bin/bash
set -euo pipefail

IMAGE_NAME="my-flask-app"
IMAGE_TAG="latest"
CLUSTER_NAME="my-cluster"
CLUSTER_CONFIG="kind-config.yaml"
DEPLOYMENT_FILE="k8s/deployment.yaml"
SERVICE_FILE="k8s/service.yaml"
NODE_PORT=30000  # Must match service.yaml nodePort AND kind-config.yaml hostPort

echo "=== Deleting old KIND cluster if it exists ==="
kind delete cluster --name "$CLUSTER_NAME" || true

echo "=== Removing old Docker image if it exists ==="
docker rmi -f "$IMAGE_NAME:$IMAGE_TAG" || true

echo "=== Building Docker image ==="
docker build -t "$IMAGE_NAME:$IMAGE_TAG" .

# ===================== Scan Docker image =====================
SCANNER_REPORT="scanner.txt"
echo "=== Scanning Docker image with Trivy ===" | tee "$SCANNER_REPORT"
trivy image "$IMAGE_NAME:$IMAGE_TAG" | tee -a "$SCANNER_REPORT"

echo "=== Scanning Docker image with Grype ===" | tee -a "$SCANNER_REPORT"
grype "$IMAGE_NAME:$IMAGE_TAG" | tee -a "$SCANNER_REPORT"
echo "=== Scan complete! Reports saved in $SCANNER_REPORT ==="
# =============================================================

echo "=== Creating KIND cluster with port mapping ==="
kind create cluster --name "$CLUSTER_NAME" --config "$CLUSTER_CONFIG"

echo "=== Loading Docker image into KIND ==="
kind load docker-image "$IMAGE_NAME:$IMAGE_TAG" --name "$CLUSTER_NAME"

echo "=== Cleaning old deployments/services (if any) ==="
kubectl delete deployment -l app=flask --ignore-not-found || true
kubectl delete service -l app=flask --ignore-not-found || true

echo "=== Deploying Flask app ==="
kubectl apply -f "$DEPLOYMENT_FILE"
kubectl apply -f "$SERVICE_FILE"

# Wait for at least one pod to be created before waiting for readiness
echo "=== Waiting for pod(s) to be created ==="
for i in {1..30}; do
    POD_COUNT=$(kubectl get pods -l app=flask --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$POD_COUNT" -gt 0 ]; then
        echo "Pod(s) found ($POD_COUNT). Waiting for readiness..."
        break
    fi
    echo "No pods yet... ($i/30)"
    sleep 2
done

echo "=== Waiting for pod(s) to be ready ==="
kubectl wait --for=condition=ready pod -l app=flask --timeout=120s

# Wait until Flask responds via NodePort (no port-forward needed!)
echo "=== Waiting for Flask to respond at http://localhost:$NODE_PORT ==="
FLASK_READY=0
for i in {1..15}; do
    if curl -fs "http://localhost:$NODE_PORT" >/dev/null 2>&1; then
        echo "✅ Flask app is ready!"
        FLASK_READY=1
        break
    else
        echo "Waiting for Flask... ($i/15)"
        sleep 2
    fi
done

if [ "$FLASK_READY" -ne 1 ]; then
    echo "❌ Flask never became ready. Check: kubectl logs -l app=flask"
    exit 1
fi

echo ""
echo "==================================================================="
echo " ✅ Deployment complete!"
echo " 🌐 Open your browser at: http://localhost:$NODE_PORT"
echo " (No port-forwarding needed — KIND extraPortMappings handles it)"
echo "==================================================================="