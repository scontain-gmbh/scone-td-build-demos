# sptd-mode source image for pet-clinic (development only). Spring PetClinic as a GraalVM
# native-image instead of a JVM (no JIT in the TD), from the same pinned upstream commit as
# the demo's Dockerfile. Build context: pet-clinic/ (unused; sources are cloned).
ARG PETCLINIC_REF=51045d1648dad955df586150c1a1a6e22ef400c2

FROM ghcr.io/graalvm/native-image-community:21 AS build
ARG PETCLINIC_REF
RUN microdnf install -y git findutils && microdnf clean all
WORKDIR /src
RUN git clone https://github.com/spring-projects/spring-petclinic.git . \
    && git checkout "${PETCLINIC_REF}"
RUN ./mvnw -B -Pnative -DskipTests native:compile \
    && cp target/spring-petclinic /out-petclinic

FROM gcr.io/distroless/base-debian12:nonroot
COPY --from=build /out-petclinic /app/petclinic
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/petclinic"]
