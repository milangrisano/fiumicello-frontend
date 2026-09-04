# Multi-stage build: compile Flutter web, then serve with Nginx + proxy /api
FROM cirrusci/flutter:stable AS build

WORKDIR /build
COPY . .
RUN flutter pub get && flutter build web --release --dart-define=API_BASE=/api

FROM nginx:stable-alpine AS runtime
COPY --from=build /build/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]