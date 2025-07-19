# go:1.24.4
FROM cgr.dev/chainguard/go:latest@sha256:80839bcea32c932733ef1c6206b2b00f569932158bcd2ec9ea813fa56d4ea80d AS healthcheck_builder

WORKDIR /app

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# node:24.1.0
FROM cgr.dev/chainguard/node:latest@sha256:bdf4392ef957016487dea5e10c5226f13e7bdcd0eded6113621852190453ac8b AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:d566e593404d36448929ce07f1ff7c2cf71fd874669db877573f260937608859

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
