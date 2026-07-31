ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMATGE_APLICACIO=liferay/portal:7.2.1-ga2
FROM $DOCKER_REGISTRY_CACHE/$IMATGE_APLICACIO
EXPOSE 8080
COPY Docker/basa-docker-entrypoint.bash /basa-docker-entrypoint.bash
#-------------------------------------------------
COPY Docker/PreparaImatge.bash /
COPY Docker/setenv.bash /opt/liferay/tomcat/bin/setenv.bash
USER root
RUN . /PreparaImatge.bash
RUN chown liferay:liferay /opt/liferay/tomcat/bin/setenv.bash && dos2unix /opt/liferay/tomcat/bin/setenv.bash
#-------------------------------------------------
#COPY src/???? /???/???
COPY RELEASE.txt /etc
ENTRYPOINT [ "bash" ]
CMD [ "/basa-docker-entrypoint.bash" ]
