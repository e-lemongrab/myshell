ARG  DOCKER_REGISTRY_CACHE
ARG JIRA_IMAGE
FROM $DOCKER_REGISTRY_CACHE/$JIRA_IMAGE
#Ports
EXPOSE 8020
#System
RUN apt update -y;apt upgrade -y
RUN apt install nano dos2unix cron  curl gpg gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates -y
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN NODE_MAJOR=20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt install nodejs -y
#COPY FILES
#COPY Docker/crontab /var/spool/cron/crontabs/root
#Nodejs
RUN mkdir /api
COPY Docker/*.js /api/
#
#ENTRYPOINT
WORKDIR /api
COPY Docker/docker-entrypoint.bash /docker-entrypoint.bash
RUN dos2unix /*.bash
ENTRYPOINT ["/docker-entrypoint.bash"]