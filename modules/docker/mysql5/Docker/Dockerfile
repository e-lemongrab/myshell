ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMAGE_MYSQL5=mysql:5.7.43
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_MYSQL5

EXPOSE 3306

RUN yum install dos2unix -y \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && cp -f /usr/share/zoneinfo/Europe/Madrid /etc/localtime

COPY Docker/custom-docker-entrypoint.bash /custom-docker-entrypoint.bash
COPY configs /tmp/configs
RUN dos2unix /custom-docker-entrypoint.bash \
    && find /tmp/configs -type f -exec dos2unix {} + \
    && chmod +x /custom-docker-entrypoint.bash
CMD [ "/custom-docker-entrypoint.bash" ]
