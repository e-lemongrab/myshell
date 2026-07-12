ARG  DOCKER_REGISTRY_CACHE
ARG IMAGE_MAVEN
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_MAVEN
RUN mkdir -p /usr/src/dependencies
RUN mkdir -p ~/.m2/
WORKDIR /usr/src/dependencies
COPY env/pom.xml /usr/src/dependencies
COPY env/settings.xml /usr/share/maven/conf/settings.xml
COPY Docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
