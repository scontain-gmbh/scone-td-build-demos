# sptd-mode source images for configmap (development only). Build context: configmap/folder-reader/.
# The demo's Job runs two readers of one image with different ConfigMap items at /config. A signed
# Pod plan can't carry two roles of one image, so sptd mode builds one image per reader
# (--build-arg READER=1 or 2). Differences from the demo's own Dockerfile:
#  - static binary on a distroless nonroot base (uid 65532), started as /usr/local/bin/folder-reader;
#  - /config is a directory of read-only symlinks to the reader's baked descriptor files, numbered
#    by path: reader 1 file1.txt /proc/self/fd/100, file2.json 101; reader 2 server.crt 100,
#    your_python_script.py 101. The sptd dispatcher refuses the build if baked-volumes.json
#    assigns other descriptors.
# Temporary: the symlinks and the bake are removed once CAS delivers these files.
FROM rust:1-bookworm AS build
ARG READER
WORKDIR /src
COPY Cargo.toml ./
COPY src ./src
RUN case "$READER" in \
      1) set -- file1.txt file2.json ;; \
      2) set -- server.crt your_python_script.py ;; \
      *) echo "READER must be 1 or 2" >&2; exit 1 ;; \
    esac \
    && RUSTFLAGS="-C target-feature=+crt-static" \
       cargo build --release --target x86_64-unknown-linux-gnu \
    && mkdir -p /out/config \
    && cp target/x86_64-unknown-linux-gnu/release/folder-reader /out/folder-reader \
    && ln -s /proc/self/fd/100 "/out/config/$1" \
    && ln -s /proc/self/fd/101 "/out/config/$2"

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/folder-reader /usr/local/bin/folder-reader
COPY --from=build /out/config /config
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/folder-reader"]
