# =============================================================
# FRONTEND DOCKERFILE - Multi-stage build
# Stage 1: Node builder (npm build)
# Stage 2: Nginx (serve static files only - tiny image)
# =============================================================

# Stage 1: Build React app
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first (layer caching)
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Copy source and build
COPY . .
RUN npm run build

# -----------------------------------------------------------

# Stage 2: Serve with nginx (final image ~25MB vs ~1GB with node)
FROM nginx:1.25-alpine AS runner

# Remove default nginx page
RUN rm -rf /usr/share/nginx/html/*

# Copy built React app from builder
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx config for React Router support
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Security: run nginx as non-root
RUN addgroup --system nginxgroup && adduser --system --ingroup nginxgroup nginxuser
RUN chown -R nginxuser:nginxgroup /usr/share/nginx/html && \
    chown -R nginxuser:nginxgroup /var/cache/nginx && \
    chown -R nginxuser:nginxgroup /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginxuser:nginxgroup /var/run/nginx.pid

USER nginxuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --quiet --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
