# sptd-mode source image for java-args-env-file (development only). GraalVM native-image
# instead of a JVM (no JIT in the TD). Build context: java-args-env-file/.
# /config/configs.yaml and /config/secrets are read-only symlinks to the baked descriptor
# files /dev/fd/100 and /dev/fd/101 (temporary: remove with the dev-only bake once CAS
# delivers these files). The sptd dispatcher checks them against baked-volumes.json.
FROM ghcr.io/graalvm/native-image-community:21 AS build
WORKDIR /src
COPY Main.java .
RUN mkdir -p /out/config \
    && javac Main.java \
    && native-image --no-fallback -cp . Main -o /out/java-args-env-file \
    && ln -s /dev/fd/100 /out/config/configs.yaml \
    && ln -s /dev/fd/101 /out/config/secrets

FROM gcr.io/distroless/base-debian12:nonroot
COPY --from=build /out/java-args-env-file /usr/local/bin/java-args-env-file
COPY --from=build /out/config /config
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/java-args-env-file"]
