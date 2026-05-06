# =============================================================
# BACKEND DOCKERFILE — Node.js (Express + PostgreSQL)
# Multi-stage build for minimal, secure production image
#
# Stage 1: Builder  — installs ALL dependencies
# Stage 2: Runner   — production deps only, non-root user
# =============================================================

# Stage 1: Builder
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first — Docker caches this layer separately
# Only re-runs npm ci if package.json actually changes
COPY package.json package-lock.json* ./
RUN npm ci

# Copy rest of source
COPY . .

# -----------------------------------------------------------

# Stage 2: Runner — lean, secure production image (~180MB vs ~1.1GB)
FROM node:20-alpine AS runner

WORKDIR /app

# Production dependencies only
COPY package.json package-lock.json* ./
RUN npm ci --only=production && npm cache clean --force

# Copy app from builder stage
COPY --from=builder /app/server.js .

# SECURITY: Create and use non-root user — never run containers as root
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
RUN chown -R appuser:appgroup /app
USER appuser

# Port 3000 — matches app.listen(3000) in server.js
EXPOSE 3000

# Docker health check — uses /api/health (matches actual route in server.js)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]
