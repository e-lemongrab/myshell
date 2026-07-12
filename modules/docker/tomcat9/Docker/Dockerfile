ARG  DOCKER_REGISTRY_CACHE
ARG IMATGE_APLICACIO
FROM $DOCKER_REGISTRY_CACHE/$IMATGE_APLICACIO
EXPOSE 8443
#OS SW
#COPY volum/mysql-connector-java-8.0.25.jar /usr/local/tomcat/lib
#
COPY Docker/entrypoint.bash /
#COPY Docker/certs /certs
COPY Docker/entorns /tpm/entorns
COPY Docker/volum/server.xml /usr/local/tomcat/conf/
COPY Docker/volum/sample.war /usr/local/tomcat/webapps/
ENTRYPOINT ["/entrypoint.bash"]