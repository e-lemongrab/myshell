ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMATGE_APLICACIO=tomcat:9.0.120-jdk21-temurin-jammy
FROM $DOCKER_REGISTRY_CACHE/$IMATGE_APLICACIO
EXPOSE 8443

COPY Docker/entrypoint.bash /
COPY Docker/entorns /tmp/entorns
RUN chmod +x /entrypoint.bash
ENTRYPOINT ["/entrypoint.bash"]
