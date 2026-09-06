# Multi-stage build: compile Flutter web, then serve with Nginx + proxy /api
FROM cirrusci/flutter:stable AS build

ARG APP_VERSION=1.0.0
WORKDIR /build
COPY . .
RUN flutter pub get && flutter build web --release --dart-define=API_BASE=/api --dart-define=APP_VERSION=${APP_VERSION}

FROM nginx:stable-alpine AS runtime
ARG APP_VERSION=1.0.0
COPY --from=build /build/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Remove the Flutter service worker so it never serves a stale cached bundle
# (the browser cache for .js is handled by nginx 'Cache-Control: no-cache').
RUN rm -f /usr/share/nginx/html/flutter_service_worker.js \
        /usr/share/nginx/html/flutter_service_worker.js.map; \
    sed -i '/flutter_service_worker\.js/d' /usr/share/nginx/html/index.html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]