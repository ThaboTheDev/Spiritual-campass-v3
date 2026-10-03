# Build with the pinned Flutter/Dart toolchain. The API itself is plain Dart;
# the Flutter image supplies Dart for resolving the shared workspace packages.
FROM ghcr.io/cirruslabs/flutter:3.41.0 AS build
WORKDIR /workspace
COPY pubspec.yaml ./
COPY packages/core/pubspec.yaml packages/core/pubspec.yaml
COPY packages/core/lib packages/core/lib
COPY apps/api/pubspec.yaml apps/api/pubspec.yaml
COPY apps/api/lib apps/api/lib
COPY apps/api/bin apps/api/bin
COPY apps/app/pubspec.yaml apps/app/pubspec.yaml
# Flutter workspace packages require Flutter's pub client during workspace resolution.
RUN flutter pub get
RUN dart compile exe apps/api/bin/server.dart -o /workspace/server

FROM gcr.io/distroless/cc-debian12:nonroot
WORKDIR /app
COPY --from=build --chown=nonroot:nonroot /workspace/server /app/server
ENV PORT=8080
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/server"]
