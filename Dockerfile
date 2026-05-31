FROM dart:stable AS build

WORKDIR /app

# Copiar archivos de dependencias
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get

# Copiar el resto del código
COPY . .

# Habilitar web
RUN dart pub global activate flutter_distribute

# Instalar Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:$PATH"

# Obtener dependencias de Flutter
RUN flutter pub get

# Construir para web
RUN flutter build web --release

# Servir con nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
