# =====================================================================
# Schematic Drawing Portal - multi-stage Dockerfile
#   Stage 1 (Node)   : builds the React frontend into static HTML/JS/CSS
#   Stage 2 (Python) : runs the FastAPI backend, which also serves those files
# Result: ONE image, ONE container, ONE port (8000).
# =====================================================================

# ---------- Stage 1: build the frontend ----------
FROM node:24-alpine AS frontend-build
WORKDIR /fe

# Copy only the package files first, so Docker can cache the npm install
# layer and skip it when only the source code changes.
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

# Now copy the source and build it. Output goes to /fe/dist
COPY frontend/ .
RUN npm run build


# ---------- Stage 2: the runtime image ----------
FROM python:3.12-alpine

WORKDIR /app

# Install the Python dependencies (cached unless requirements.txt changes)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the backend code, the symbol library, and the built frontend
# from stage 1. Node and node_modules are NOT carried over, which keeps
# the final image small.
COPY backend/app/ ./app/
COPY backend/symbols/ ./symbols/
COPY --from=frontend-build /fe/dist/ ./static/

# Version label shown by /api/health (override with --build-arg APP_VERSION=1.1)
ARG APP_VERSION=1.0
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Run as a normal user, not root (good security practice)
RUN addgroup -S app && adduser -S -G app app
USER app

# The app listens on port 8000 inside the container
EXPOSE 8000

# Docker marks the container "healthy" once /api/health answers
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health')"]

# Start the web server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
