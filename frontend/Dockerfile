# Build stage for Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY frontend/pubspec.* ./
RUN flutter pub get

COPY frontend ./
RUN flutter build web --release

# Serve static web app with Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
