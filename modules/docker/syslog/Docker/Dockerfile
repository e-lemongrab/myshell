ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMATGE_APLICACIO=debian:bookworm-20260623-slim
FROM $DOCKER_REGISTRY_CACHE/$IMATGE_APLICACIO
RUN apt-get update \
    && apt-get install --no-install-recommends -y cron \
    && rm -rf /var/lib/apt/lists/*
COPY Docker/basa-docker-entrypoint.bash /
RUN chmod +x /basa-docker-entrypoint.bash
ENTRYPOINT ["/basa-docker-entrypoint.bash"]
