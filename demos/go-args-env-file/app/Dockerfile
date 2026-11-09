# ─── Stage 1: build ──────────────────────────────────────────────────────────
# The SCONE Go toolchain routes the runtime's syscalls through SCONE and links a
# position-independent binary that loads with musl, so it can be sconified.
FROM ghcr.io/scontain/golang:1.25.4-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Cache dependencies before copying source (layer-cache friendly)
COPY go.mod* go.sum* ./
RUN go mod download

COPY . .
RUN go build -v -o /usr/local/bin/go-args-env-file .

# ─── Stage 2: runtime ────────────────────────────────────────────────────────
# Only the binary is copied: the builder image ships the SCONE runtime in /opt/scone,
# and scone-td-build skips an image that carries it as already sconified.
# alpine, not scratch, because the binary needs the musl loader. Same Alpine release as the
# builder (3.22.2), so the runtime has the musl the binary was linked against; move both
# together.
FROM alpine:3.22.2

COPY --from=builder /usr/local/bin/go-args-env-file /usr/local/bin/go-args-env-file

# The app reads files from /config at runtime — declare it as a volume hint.
# In Kubernetes the ConfigMap / Secret are mounted here.
VOLUME ["/config"]

ENTRYPOINT ["/usr/local/bin/go-args-env-file"]
