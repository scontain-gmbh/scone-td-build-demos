# sptd-mode source images for the Python demos (development only), run as measured CPython script
# targets (scripts/sptd/policies/python-script*.json: the real interpreter /usr/local/bin/python3.11).
# Build context: the demo directory, plus --build-context sptd=scripts/sptd/images/python, with
#   --build-arg APP=software-updates-v1 | software-updates-v2   (context software-updates/)
#   --build-arg APP=flask-redis-netshield                       (context flask-redis-netshield/)
# Differences from the demos' own Dockerfiles:
#  - nonroot uid 65532 (a TD runs no uid 0 target);
#  - the script is /app/print_env.py or /app/app.py, the absolute command of the sptd overrides;
#  - flask-redis-netshield's packages come from the hash-pinned wheel list
#    flask-redis-netshield.requirements.lock (--require-hashes --no-deps --only-binary=:all:);
#  - no CMD: the overrides set the script as the command.
FROM python:3.11-slim AS build
ARG APP
COPY . /src/
COPY --from=sptd flask-redis-netshield.requirements.lock /locks/
RUN set -eu; mkdir -p /out/app /out/site; \
    case "$APP" in \
      software-updates-v1) install -m 0644 /src/print_env1.py /out/app/print_env.py ;; \
      software-updates-v2) install -m 0644 /src/print_env2.py /out/app/print_env.py ;; \
      flask-redis-netshield) \
        pip install --no-cache-dir --no-deps --only-binary=:all: --require-hashes --target /out/site \
          -r /locks/flask-redis-netshield.requirements.lock; \
        install -m 0644 /src/app.py /out/app/app.py ;; \
      *) echo "APP must be software-updates-v1, software-updates-v2 or flask-redis-netshield" >&2; exit 1 ;; \
    esac

FROM python:3.11-slim
COPY --from=build /out/site/ /usr/local/lib/python3.11/site-packages/
COPY --from=build /out/app/ /app/
WORKDIR /app
USER 65532:65532
