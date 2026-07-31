ARG DOCKER_REGISTRY_CACHE=docker.io
ARG NODE_IMAGE=node:20.19-bookworm-slim
FROM $DOCKER_REGISTRY_CACHE/$NODE_IMAGE

EXPOSE 8020

RUN apt-get update \
    && apt-get install --no-install-recommends -y curl dos2unix \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /api
COPY Docker/*.js /api/
WORKDIR /api
COPY Docker/docker-entrypoint.bash /docker-entrypoint.bash
RUN dos2unix /docker-entrypoint.bash && chmod +x /docker-entrypoint.bash
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl --fail http://127.0.0.1:8020/health || exit 1
ENTRYPOINT ["/docker-entrypoint.bash"]
