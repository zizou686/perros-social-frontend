FROM subfuzion/flutter:latest AS build

WORKDIR /app

# Copiar archivos de dependencias
COPY pubspec.yaml pubspec.lock* ./

# Obtener dependencias
RUN flutter pub get

# Copiar el resto del código
COPY . .

# Construir para web
RUN flutter build web --release

# Servir con nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
