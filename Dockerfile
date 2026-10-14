# Multi-stage build: compile Flutter web, then serve with Nginx + proxy /api
#
# Uses a pinned, current stable Flutter SDK. NOTE: the old base
# `cirrusci/flutter:stable` was frozen at Flutter 3.7.7 / Dart 2.19 (2023),
# so we install the official Flutter SDK tarball directly on a lean Debian
# base. Bump FLUTTER_VERSION when you want a newer stable.
FROM debian:bookworm-slim AS flutter-sdk

ARG FLUTTER_VERSION=3.47.2

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates xz-utils unzip git bash \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar xJ -C /opt \
    && git config --global --add safe.directory /opt/flutter

ENV FLUTTER_ROOT=/opt/flutter
ENV PATH="${FLUTTER_ROOT}/bin:${FLUTTER_ROOT}/bin/cache/dart-sdk/bin:${PATH}"

# Warm up the tool and disable analytics so `flutter pub get`/`build` in the
# build stage don't block or phone home on first run.
RUN flutter config --no-analytics

FROM flutter-sdk AS build

ARG APP_VERSION=1.0.0
WORKDIR /build
COPY . .
RUN flutter pub get && flutter build web --release --dart-define=API_BASE=/api --dart-define=APP_VERSION=${APP_VERSION}

FROM nginx:stable-alpine AS runtime
ARG APP_VERSION=1.0.0
COPY --from=build /build/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# PWA: se CONSERVA el service worker (flutter_service_worker.js) para permitir
# la instalacion como app. La actualizacion segura se garantiza con:
#  - nginx 'Cache-Control: no-cache' para index.html, version.json, flutter.js y
#    el propio service worker (siempre se piden al server).
#  - el auto-reload por version.json en index.html (recarga al detectar un build
#    nuevo), evitando servir un bundle viejo.
#
# version.json se reescribe con el hash del bundle -> cambia en CADA deploy, y el
# auto-reload de index.html detecta la nueva version y recarga una vez.
RUN H=$(md5sum /usr/share/nginx/html/main.dart.js | cut -c1-10); \
    printf '{"version":"%s"}' "$H" > /usr/share/nginx/html/version.json; \
    cat /usr/share/nginx/html/version.json

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]