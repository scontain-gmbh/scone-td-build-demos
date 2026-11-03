# sptd-mode source image for web-server (development only). Build context: web-server/.
# Differences from the demo's own Dockerfile:
#  - static binary on a distroless nonroot base (uid 65532), started as /app/web-server;
#  - /config/<key> are read-only symlinks to the baked descriptor files of the game-demo
#    ConfigMap, numbered by path: game.properties /proc/self/fd/100, player_initial_lives 101,
#    ui_properties_file_name 102, user-interface.properties 103. The sptd dispatcher refuses
#    the build if baked-volumes.json assigns other descriptors.
# Temporary: the symlinks and the bake are removed once CAS delivers these files.
FROM rust:1-bookworm AS build
WORKDIR /src
COPY Cargo.toml ./
COPY src ./src
RUN RUSTFLAGS="-C target-feature=+crt-static" \
    cargo build --release --target x86_64-unknown-linux-gnu \
    && mkdir -p /out/config \
    && cp target/x86_64-unknown-linux-gnu/release/web-server /out/web-server \
    && ln -s /proc/self/fd/100 /out/config/game.properties \
    && ln -s /proc/self/fd/101 /out/config/player_initial_lives \
    && ln -s /proc/self/fd/102 /out/config/ui_properties_file_name \
    && ln -s /proc/self/fd/103 /out/config/user-interface.properties

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/web-server /app/web-server
COPY --from=build /out/config /config
USER 65532:65532
EXPOSE 8000
ENTRYPOINT ["/app/web-server"]
