# hadolint ignore=DL3007
FROM cgr.dev/chainguard/node:latest AS builder

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

RUN npm run build

# hadolint ignore=DL3007
FROM cgr.dev/chainguard/nginx:latest

ARG revision

LABEL \
  org.opencontainers.image.title="Girus Frontend" \
  org.opencontainers.image.description="Frontend for the Girus application" \
  org.opencontainers.image.authors="Eduardo Thums <eduardocristiano01@gmail.com>" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="1.0.0" \
  org.opencontainers.image.url="https://linuxtips.io/girus-labs/" \
  org.opencontainers.image.source="https://github.com/eduardothums/girus-pick/web" \
  org.opencontainers.image.documentation="https://github.com/eduardothums/girus-pick/web/README.md" \
  org.opencontainers.image.revision="$revision"

COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80
