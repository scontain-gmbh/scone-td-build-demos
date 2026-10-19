# sptd-mode source image for go-args-env-file (development only, temporary: remove together
# with the dev-only baked volumes once CAS delivers these files).
# Build context: go-args-env-file/. Differences from the demo's own Dockerfile:
#  - static binary on a distroless nonroot base (uid 65532), no VOLUME;
#  - /config/configs.yaml and /config/secrets are read-only symlinks to the baked descriptor
#    files /proc/self/fd/100 (ConfigMap app-config) and /proc/self/fd/101 (Secret app-secrets). The sptd
#    dispatcher refuses the build if baked-volumes.json assigns other descriptors.
FROM ghcr.io/scontain/golang:1.25.4-alpine AS builder
WORKDIR /src
COPY go.mod* go.sum* ./
RUN go mod download 2>/dev/null || true
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/go-args-env-file . \
    && mkdir -p /out/config \
    && ln -s /proc/self/fd/100 /out/config/configs.yaml \
    && ln -s /proc/self/fd/101 /out/config/secrets

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/go-args-env-file /usr/local/bin/go-args-env-file
COPY --from=builder /out/config /config
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/go-args-env-file"]
