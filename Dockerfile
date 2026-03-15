# Builder stage
FROM python:3.13-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --prefix=/install --no-cache-dir -r requirements.txt

# Final Chainguard stage
FROM cgr.dev/chainguard/python:latest

WORKDIR /app

# Copy installed packages
COPY --from=builder /install /install

# Tell Python where packages are
ENV PYTHONPATH=/install/lib/python3.13/site-packages

COPY app.py .

ENTRYPOINT ["python", "app.py"]