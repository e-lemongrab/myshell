ARG DOCKER_REGISTRY_CACHE
ARG IMAGE_ALPINE
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_ALPINE
EXPOSE 27017
# System packages
RUN echo 'https://dl-cdn.alpinelinux.org/alpine/latest-stable/main' >> /etc/apk/repositories; \
    echo 'https://dl-cdn.alpinelinux.org/alpine/latest-stable/community' >> /etc/apk/repositories; \
    apk update; \
    apk upgrade
# Entrypoint
COPY Docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# System user and service
RUN adduser -s /bin/sh -h /home/mongouser -D mongouser && \
    echo "mongouser:yourpassword" | chpasswd && \
    addgroup mongouser wheel
USER mongouser    
ENTRYPOINT [ "/entrypoint.sh" ]