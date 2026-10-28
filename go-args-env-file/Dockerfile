# ─── Stage 1: build ──────────────────────────────────────────────────────────
# The SCONE Go toolchain routes the runtime's syscalls through SCONE and links a
# position-independent binary that loads with musl, so it can be sconified.
FROM ghcr.io/scontain/golang:1.25.4-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Cache dependencies before copying source (layer-cache friendly)
COPY go.mod* go.sum* ./
RUN go mod download 2>/dev/null || true

COPY . .
RUN go build -v -o /usr/local/bin/go-args-env-file .

# ─── Stage 2: runtime ────────────────────────────────────────────────────────
# Only the binary is copied: the builder image ships the SCONE runtime in /opt/scone,
# and scone-td-build skips an image that carries it as already sconified.
# alpine, not scratch, because the binary needs the musl loader.
FROM alpine:3.22

COPY --from=builder /usr/local/bin/go-args-env-file /usr/local/bin/go-args-env-file

# The app reads files from /config at runtime — declare it as a volume hint.
# In Kubernetes the ConfigMap / Secret are mounted here.
VOLUME ["/config"]

ENTRYPOINT ["/usr/local/bin/go-args-env-file"]
