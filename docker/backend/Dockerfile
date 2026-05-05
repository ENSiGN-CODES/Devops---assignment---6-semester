# =============================================================
# BACKEND DOCKERFILE - Multi-stage build for production
# Stage 1: Builder (installs dependencies)
# Stage 2: Runner (minimal final image)
# =============================================================

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies only in builder stage
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first (layer caching - faster rebuilds)
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# -----------------------------------------------------------

# Stage 2: Runner (final production image)
FROM python:3.11-slim AS runner

WORKDIR /app

# Install only runtime dependencies (no build tools = smaller image)
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder (not the full build toolchain)
COPY --from=builder /root/.local /root/.local

# Copy application source code
COPY . .

# Security: run as non-root user
# Never run containers as root in production
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
RUN chown -R appuser:appgroup /app
USER appuser

# Expose application port
EXPOSE 8000

# Health check - Docker will mark container unhealthy if this fails
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Start command
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
