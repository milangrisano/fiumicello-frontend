# Multi-stage build: compile Flutter web, then serve with Nginx
FROM cirrusci/flutter:stable AS build

WORKDIR /build
COPY . .
RUN flutter pub get && flutter build web --release

FROM nginx:stable-alpine AS runtime
COPY --from=build /build/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]