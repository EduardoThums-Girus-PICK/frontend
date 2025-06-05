# go:1.24.3
FROM cgr.dev/chainguard/go:latest@sha256:8e97f2e7e99abcff5517be9580c6315fd5d2fb7dfbf1a632534d8e4f6bbbeecb AS healthcheck_builder

WORKDIR /app

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# node:18.20.8
FROM cgr.dev/chainguard/node:latest@sha256:441cfcd28fd397313f2b4f6933e836f2435a87d14555aea755344d202d09c01e AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:b5625cee976b9d0205a5cfab2074c15ad4cc4af41f66f906aad674d6081798a8

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
