# Builds the Spring PetClinic app from upstream source at a pinned commit.
# Override the commit/tag with: --build-arg PETCLINIC_REF=<ref>
# Default is the commit that is known to work with this demo.
ARG PETCLINIC_REF=51045d1648dad955df586150c1a1a6e22ef400c2

# ---- Stage 1: fetch upstream source at the pinned ref and build the jar ----
FROM maven:3.9-eclipse-temurin-17 AS build
ARG PETCLINIC_REF
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone https://github.com/spring-projects/spring-petclinic.git . \
    && git checkout "${PETCLINIC_REF}"
RUN ./mvnw -B -Dmaven.test.skip=true package \
    && cp target/spring-petclinic-*.jar /petclinic.jar

# ---- Stage 2: runtime image ----
# Pin the runtime base to Ubuntu 24.04 "noble" (glibc 2.39), which matches the
# glibc that SCONE 6.x ships. The rolling `17-jre` tag now resolves to Ubuntu
# 26.04 (glibc 2.43); that skew breaks the enclave link map for java's direct
# deps (libpthread resolves under /usr/lib at runtime but is recorded under /lib
# during sconify), so the enclave aborts with "libpthread ... not found in the
# enclave link map". Keeping glibc aligned with SCONE avoids that.
FROM eclipse-temurin:17-jre-noble
WORKDIR /app
COPY --from=build /petclinic.jar /app/petclinic.jar
EXPOSE 8080
# DB is configured at runtime via env (SPRING_PROFILES_ACTIVE=mysql + datasource).
ENTRYPOINT ["java", "-jar", "/app/petclinic.jar"]
