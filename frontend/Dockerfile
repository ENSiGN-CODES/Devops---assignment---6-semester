# Serve static HTML with Nginx (ultra-lightweight)
FROM nginx:alpine

# Remove default nginx page
RUN rm /usr/share/nginx/html/*

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
