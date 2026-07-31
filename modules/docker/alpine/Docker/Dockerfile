ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMAGE_ALPINE=alpine:3.22.5
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_ALPINE
EXPOSE 27017

# Entrypoint
COPY Docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# System user and service
RUN adduser -s /bin/sh -h /home/mongouser -D mongouser && \
    echo "mongouser:yourpassword" | chpasswd && \
    addgroup mongouser wheel
USER mongouser
ENTRYPOINT [ "/entrypoint.sh" ]
