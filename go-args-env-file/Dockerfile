# ─── Stage 1: build ──────────────────────────────────────────────────────────
FROM ghcr.io/scontain/golang:1.25.4-alpine AS builder

# Install build essentials (needed for static linking via musl)
RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Cache dependencies before copying source (layer-cache friendly)
COPY go.mod* go.sum* ./
RUN go mod download 2>/dev/null || true

# Copy source and build a fully static binary
COPY . .
RUN go build -v -o /usr/local/bin/go-args-env-file .

# ─── Stage 2: run ────────────────────────────────────────────────────────────
# The app reads files from /config at runtime; in Kubernetes the ConfigMap /
# Secret are mounted there. No VOLUME hint: an image-declared volume becomes an
# anonymous, unprotected runtime volume, which scone-sptd-build refuses. The run
# stage does not inherit the golang base image either, whose config sets
# ArgsEscaped=true (also refused by scone-sptd-build).
FROM alpine:3.22
COPY --from=builder /usr/local/bin/go-args-env-file /usr/local/bin/go-args-env-file

ENTRYPOINT ["/usr/local/bin/go-args-env-file"]
