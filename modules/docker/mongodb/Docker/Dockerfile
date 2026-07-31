ARG DOCKER_REGISTRY_CACHE=docker.io
ARG IMAGE_OPENSUSELEAP=opensuse/leap:15.6
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_OPENSUSELEAP
ARG MONGODB_VERSION=8.0.28
ARG MONGODB_SERIES=8.0

EXPOSE 27017

RUN rpm --import "https://pgp.mongodb.com/server-${MONGODB_SERIES}.asc" && \
    zypper addrepo --gpgcheck "https://repo.mongodb.org/zypper/suse/15/mongodb-org/${MONGODB_SERIES}/x86_64/" mongodb && \
    zypper --non-interactive --gpg-auto-import-keys refresh && \
    zypper --non-interactive install --no-recommends "mongodb-org=${MONGODB_VERSION}" && \
    zypper clean --all

RUN useradd -m -s /bin/bash -u 1002 -g mongod mongouser

RUN mkdir -p /data/db && \
    chown -R mongouser:mongod /data/db && \
    chmod -R 760 /data/db

COPY Docker/entrypoint.sh /entrypoint.sh
RUN chown mongouser:mongod /entrypoint.sh && \
    chmod +x /entrypoint.sh

USER mongouser
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
    CMD mongosh --quiet --eval "db.adminCommand('ping').ok" || exit 1
ENTRYPOINT [ "/entrypoint.sh" ]
