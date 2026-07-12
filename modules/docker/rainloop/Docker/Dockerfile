ARG  DOCKER_REGISTRY_CACHE
ARG IMATGE_BASE
FROM $DOCKER_REGISTRY_CACHE/$IMATGE_BASE
EXPOSE 80
RUN apt update;
RUN apt upgrade -y;
RUN apt install nano unzip curl php php-curl php-dom php-xml -y;
COPY Docker/rainloop-install.bash /rainloop-install.bash
COPY Docker/docker-entrypoint.bash /docker-entrypoint.bash
RUN chmod +x /docker-entrypoint.bash
RUN chmod +x /rainloop-install.bash
WORKDIR /usr/local/apache2/htdocs/
CMD [ "/docker-entrypoint.bash" ]
ENTRYPOINT [ "/bin/bash" ]