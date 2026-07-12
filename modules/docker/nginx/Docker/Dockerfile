ARG  DOCKER_REGISTRY_CACHE
ARG NGINX_IMAGE
FROM $DOCKER_REGISTRY_CACHE/$NGINX_IMAGE
#Ports
EXPOSE 80
#System
RUN apt update -y;apt upgrade -y
RUN apt install dos2unix -y
#ENTRYPOINT
COPY Docker/docker-entrypoint.bash /docker-entrypoint.bash
RUN chmod +x /*.bash
RUN dos2unix /*.bash
ENTRYPOINT [ "/docker-entrypoint.bash" ]