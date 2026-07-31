ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMATGE_BASEDEDADES=cockroachdb/cockroach:v22.1.1
FROM $DOCKER_REGISTRY_CACHE/$IMATGE_BASEDEDADES
#Port
EXPOSE 26257
#System
RUN cp -r -f /usr/share/zoneinfo/Europe/Madrid /etc/localtime && ls -la /etc/localtime
#BASA_DOCKER
COPY Docker/basa-docker-entrypoint.bash /basa-docker-entrypoint.bash
#RUN dos2unix /basa-docker-entrypoint.bash
RUN chmod +x /basa-docker-entrypoint.bash
ENTRYPOINT [ "/basa-docker-entrypoint.bash" ]
#ENTRYPOINT [ "/cockroach/cockroach.bash" ]
#CMD [ "start-single-node" ]
