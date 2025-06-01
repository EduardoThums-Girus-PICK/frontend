# go:1.24.3
FROM cgr.dev/chainguard/go:latest@sha256:86afb531f453caf27580a0c7a11ac7f6c423cc1599a7ef53645e7353353ae302 AS healthcheck_builder

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# node:18.20.8
FROM cgr.dev/chainguard/node:latest@sha256:75e6c806a4654a59f42b957dcced700a25aa6c47c3fa3cfc37fed3cb9a86e5ac AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:8f363d198264b1b799704507065a7f9992ad330e40d6e30aff6a51cabfd0ee50

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

COPY --from=healthcheck_builder /healthcheck /usr/local/bin/healthcheck
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=2s --timeout=5s --start-period=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]
