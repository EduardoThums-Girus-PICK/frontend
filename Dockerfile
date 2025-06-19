# go:1.24.4
FROM cgr.dev/chainguard/go:latest@sha256:3930f1a74c286cd1ee1d2f4a74b0fc48d0ca36ffdf76e39918161cc6576ccc9d AS healthcheck_builder

WORKDIR /app

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# node:24.1.0
FROM cgr.dev/chainguard/node:latest@sha256:5e85ef0c0868d8b686f405b5b09482433e890cfd0651a9f2f47ccdafdf1bb4cd AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:3f441909e00e45dadfb8b27db23b3045a3a70007b7f7062e86b48b4ddeda8f15

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
