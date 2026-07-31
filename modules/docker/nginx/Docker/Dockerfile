ARG DOCKER_REGISTRY_CACHE=docker.io
ARG NGINX_IMAGE=nginx:1.30.4
FROM $DOCKER_REGISTRY_CACHE/$NGINX_IMAGE
#Ports
EXPOSE 80
# System
RUN apt-get update \
    && apt-get install --no-install-recommends -y dos2unix \
    && rm -rf /var/lib/apt/lists/*
#ENTRYPOINT
COPY Docker/docker-entrypoint.bash /docker-entrypoint.bash
RUN dos2unix /docker-entrypoint.bash && chmod +x /docker-entrypoint.bash
ENTRYPOINT [ "/docker-entrypoint.bash" ]
