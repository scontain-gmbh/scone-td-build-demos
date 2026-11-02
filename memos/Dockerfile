# memos (https://github.com/usememos/memos), built so that it can be sconified.
# The upstream image links memos statically, and a static binary cannot be sconified,
# so the backend is built here with the SCONE Go toolchain instead.
ARG MEMOS_VERSION=26.11.0

# Stage 1: frontend
FROM node:24-alpine AS frontend
ARG MEMOS_VERSION
RUN apk add --no-cache git && corepack enable
WORKDIR /src
RUN git clone --depth 1 --branch "${MEMOS_VERSION}" https://github.com/usememos/memos.git .
WORKDIR /src/web
# `pnpm release` writes the static files to server/frontend/dist, where the Go build
# embeds them.
RUN pnpm install --frozen-lockfile && pnpm release

# Stage 2: backend
FROM ghcr.io/scontain/golang:1.27.3-alpine3.24 AS backend
ARG MEMOS_VERSION
RUN apk add --no-cache git ca-certificates
WORKDIR /src
COPY --from=frontend /src /src
RUN go mod download
RUN go build -trimpath \
      -ldflags="-X github.com/usememos/memos/internal/version.Version=${MEMOS_VERSION}" \
      -o /usr/local/bin/memos ./cmd/memos

# Stage 3: runtime
# Same Alpine release as the builder (3.24), so the runtime has the musl the binary was
# linked against; move both together. Only the binary is copied: the builder ships the
# SCONE runtime in /opt/scone, and scone-td-build would take an image that carries it as
# already sconified.
FROM alpine:3.24
RUN apk add --no-cache tzdata ca-certificates && mkdir -p /var/opt/memos
COPY --from=backend /usr/local/bin/memos /usr/local/bin/memos
WORKDIR /var/opt/memos
ENV TZ=UTC
EXPOSE 5230
# Runs as root and without the upstream entrypoint script: it changes the owner of the
# data directory and drops privileges with su-exec, which would run outside the enclave.
ENTRYPOINT ["/usr/local/bin/memos", "--port", "5230", "--data", "/var/opt/memos"]
