# sptd-mode source image for hello-world and image-signing (development only). Build context:
# any directory (the README's `cargo new hello-world` project is generated here). Differences from
# the demos' own Dockerfile:
#  - static binary on a distroless nonroot base (uid 65532) instead of the whole rust:latest image,
#    started as /usr/local/bin/hello-world;
#  - --build-arg DEMO=hello-world or DEMO=image-signing sets a label, so the two demos get images
#    with different config digests (the node's profile registry selects a profile by config digest).
FROM rust:1-bookworm AS build
WORKDIR /src
RUN cargo new --vcs none hello-world \
    && cd hello-world \
    && cargo generate-lockfile --offline \
    && RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --locked --target x86_64-unknown-linux-gnu \
    && cp target/x86_64-unknown-linux-gnu/release/hello-world /out-hello-world

FROM gcr.io/distroless/static-debian12:nonroot
ARG DEMO
LABEL org.scontain.sptd.demo=${DEMO}
COPY --from=build /out-hello-world /usr/local/bin/hello-world
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/hello-world"]
