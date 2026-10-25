# sptd-mode source images for network-policy (development only). Build context:
# network-policy/client/ or network-policy/server/ with --build-arg ROLE=client or ROLE=server, plus
# --build-context sptd=scripts/sptd/images/network-policy for the pinned <role>.Cargo.lock (the demo
# ships none), so the build runs with --locked.
# Differences from the demo's own Dockerfiles:
#  - one pinned rust:1-bookworm builder for both roles;
#  - distroless base (glibc, libssl) with nonroot uid 65532 instead of debian:bookworm-slim as root;
#  - the binary is /usr/local/bin/<role>-rust, the absolute command the manifest already sets.
FROM rust:1-bookworm AS build
ARG ROLE
WORKDIR /app
COPY . .
COPY --from=sptd client.Cargo.lock server.Cargo.lock /locks/
RUN case "$ROLE" in client|server) ;; *) echo "ROLE must be client or server" >&2; exit 1 ;; esac \
    && cp "/locks/$ROLE.Cargo.lock" Cargo.lock \
    && cargo build --release --locked \
    && cp "target/release/$ROLE-rust" /out-binary

FROM gcr.io/distroless/base-debian12:nonroot
ARG ROLE
COPY --from=build /out-binary /usr/local/bin/${ROLE}-rust
USER 65532:65532
# No ENTRYPOINT: exec-form ENTRYPOINT doesn't expand build args, and the manifest sets the command.
