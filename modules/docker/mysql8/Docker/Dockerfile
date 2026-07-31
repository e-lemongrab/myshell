ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMAGE_MYSQL8=mysql:8.4.4
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_MYSQL8

EXPOSE 3306

RUN microdnf install dos2unix -y \
    && microdnf clean all \
    && cp -f /usr/share/zoneinfo/Europe/Madrid /etc/localtime

COPY Docker/custom-docker-entrypoint.bash /custom-docker-entrypoint.bash
COPY configs /tmp/configs
RUN dos2unix /custom-docker-entrypoint.bash \
    && find /tmp/configs -type f -exec dos2unix {} + \
    && chmod +x /custom-docker-entrypoint.bash
CMD [ "/custom-docker-entrypoint.bash" ]
