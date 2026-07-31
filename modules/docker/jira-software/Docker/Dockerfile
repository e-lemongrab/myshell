ARG DOCKER_REGISTRY_CACHE=docker.io
ARG JIRA_IMAGE=atlassian/jira-software:9.12.17
FROM $DOCKER_REGISTRY_CACHE/$JIRA_IMAGE
#Ports
EXPOSE 8080
EXPOSE 8081
#System
RUN apt-get update \
    && apt-get install --no-install-recommends -y cron dos2unix \
    && rm -rf /var/lib/apt/lists/*
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
