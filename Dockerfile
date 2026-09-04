FROM cirrusci/flutter:stable

# Herramientas para servir el build web
RUN apt-get update && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

EXPOSE 8080