# Flask on KIND — Local CI/CD PoC

A proof-of-concept that builds a minimal Flask app, packages it as a Docker image, deploys it to a local [KIND](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) cluster, and runs a smoke test — matching what the GitHub Actions CI/CD pipeline does.

## Project Structure

```
poc/
├── app.py                        # Flask application
├── Dockerfile                    # Multi-stage build (python:3.13-slim → Chainguard)
├── requirements.txt              # Python dependencies
├── kind-config.yaml              # KIND cluster config (maps localhost:30000 → NodePort)
├── run_local_ci.sh               # Local CI script (mirrors the GH Actions pipeline)
├── k8s/
│   ├── deployment.yaml           # Kubernetes Deployment (1 replica, readiness probe)
│   └── service.yaml              # NodePort Service (nodePort: 30000)
└── .github/workflows/
    └── cicd.yml                  # GitHub Actions CI/CD pipeline
```

## Prerequisites

| Tool | Install |
|------|---------|
| [Docker](https://docs.docker.com/get-docker/) | `brew install --cask docker` |
| [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/) | `brew install kind` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | `brew install kubectl` |
| curl | Pre-installed on macOS |

## Run Locally

```bash
chmod +x run_local_ci.sh
./run_local_ci.sh
```

The script will:
1. Delete any existing KIND cluster named `my-cluster`
2. Remove any stale Docker image
3. Build the Docker image from the `Dockerfile`
4. Create a fresh KIND cluster using `kind-config.yaml` (with port mapping)
5. Load the image into the cluster
6. Apply the Kubernetes manifests (`k8s/deployment.yaml`, `k8s/service.yaml`)
7. Wait for the pod to be created, then wait for it to pass its readiness probe
8. Smoke-test the app with `curl` directly via NodePort

Once running, open your browser at **http://localhost:30000** — no port-forwarding needed.

> **Why `localhost:30000` works without port-forwarding:**  
> KIND runs cluster nodes inside Docker containers. On Mac, Docker adds a VM layer,
> so NodePorts on cluster nodes are not reachable from `localhost` by default.
> The `kind-config.yaml` uses `extraPortMappings` to bridge `localhost:30000` on your
> Mac directly to the node's port `30000`, bypassing this limitation entirely.

## GitHub Actions CI/CD

The pipeline (`.github/workflows/cicd.yml`) triggers on every push or pull request to `main`:

1. **Build** — builds the Docker image
2. **Install** — downloads `kind` and `kubectl`
3. **Cluster** — creates a KIND cluster named `flask-cluster`
4. **Load** — loads the image into the cluster (no registry needed)
5. **Deploy** — applies the Kubernetes manifests
6. **Wait** — waits for pod readiness (60 s timeout)
7. **Test** — port-forwards the pod and smoke-tests with `curl`
8. **Cleanup** — deletes the cluster (runs even on failure)

## Flask App

`app.py` exposes a single route:

| Method | Path | Response |
|--------|------|----------|
| `GET`  | `/`  | `Hello from Flask! Python code test` |

## Docker Build

The `Dockerfile` uses a two-stage build:

- **Stage 1 (`builder`)** — installs Python dependencies into `/install` using `python:3.13-slim`
- **Stage 2 (runtime)** — copies the installed packages into the distroless [Chainguard Python image](https://images.chainguard.dev/directory/image/python/overview) for a minimal, secure final image

## Kubernetes Manifests

| Resource | Details |
|----------|---------|
| `Deployment` | 1 replica, `imagePullPolicy: IfNotPresent` (uses locally loaded image), HTTP readiness probe on `/` |
| `Service` | `NodePort`, cluster port `5000`, node port `30000` |