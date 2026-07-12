ARG  DOCKER_REGISTRY_CACHE
ARG JIRA_IMAGE
FROM $DOCKER_REGISTRY_CACHE/$JIRA_IMAGE
#Ports
EXPOSE 8080
EXPOSE 8081
#System
RUN apt update -y;apt upgrade -y
RUN apt install dos2unix cron -y
#COPY FILES
COPY Docker/crontab /var/spool/cron/crontabs/root
COPY Docker/1-download-files.bash /
COPY Docker/3-remove-files.bash /
RUN chmod +x /*.bash
#ENTRYPOINT
#COPY Docker/docker-entrypoint.bash /docker-entrypoint.bash
#RUN dos2unix /*.bash
#CMD ["/entrypoint.py"]
#ENTRYPOINT [ "/docker-entrypoint.bash" ]