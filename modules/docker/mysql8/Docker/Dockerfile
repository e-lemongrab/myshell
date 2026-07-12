ARG  DOCKER_REGISTRY_CACHE
ARG IMAGE_MYSQL8
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_MYSQL8
#Port
EXPOSE 3306
#System
RUN microdnf update -y
RUN microdnf upgrade -y
RUN microdnf install dos2unix -y
RUN cp -r -f /usr/share/zoneinfo/Europe/Madrid /etc/localtime && ls -la /etc/localtime
#BASA_DOCKER
COPY Docker/custom-docker-entrypoint.bash /custom-docker-entrypoint.bash
RUN dos2unix /custom-docker-entrypoint.bash
COPY configs /tmp/configs
RUN dos2unix /custom-docker-entrypoint.bash && dos2unix /tmp/configs/**/*.* && chmod +x /custom-docker-entrypoint.bash
CMD [ "/custom-docker-entrypoint.bash" ]
# ENTRYPOINT ["docker-entrypoint.sh"]
# CMD ["mysqld"]