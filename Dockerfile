# go:1.24.4
FROM cgr.dev/chainguard/go:latest@sha256:bd397895c47839f07009f97b2dc3ae2cdafd4ef8a031c5bb173de9e670d46a7f AS healthcheck_builder

WORKDIR /app

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# node:24.1.0
FROM cgr.dev/chainguard/node:latest@sha256:b0a17366d818bee0ac52ef0699c171b5771e1d49ca44fdf769855a472439a17d AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:b6d0b84572d9e4c92af070f1047a08daab7a54f9cd33ef5144a7cb6deaaca52e

ARG revision
ARG version

LABEL \
  org.opencontainers.image.title="Girus Frontend" \
  org.opencontainers.image.description="Frontend for the Girus application" \
  org.opencontainers.image.authors="Eduardo Thums <eduardocristiano01@gmail.com>" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="$version" \
  org.opencontainers.image.url="https://linuxtips.io/girus-labs/" \
  org.opencontainers.image.source="https://github.com/EduardoThums-Girus-PICK/frontend" \
  org.opencontainers.image.documentation="https://github.com/EduardoThums-Girus-PICK/frontend/README.md" \
  org.opencontainers.image.revision="$revision"

COPY --from=healthcheck_builder /app/healthcheck /usr/local/bin/healthcheck
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=2s --timeout=5s --start-period=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]
