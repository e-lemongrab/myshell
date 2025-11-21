ARG DOCKER_REGISTRY_CACHE
ARG IMAGE_OPENSUSELEAP
FROM $DOCKER_REGISTRY_CACHE/$IMAGE_OPENSUSELEAP
ARG TARGETARCH
ARG TARGETOS
ENV TARGETARCH=${TARGETARCH}
ENV TARGETOS=${TARGETOS}


# Expose MongoDB port
EXPOSE 27017

# Install MongoDB
RUN rpm --import https://pgp.mongodb.com/server-8.0.asc && \
    zypper addrepo --gpgcheck "https://repo.mongodb.org/zypper/suse/15/mongodb-org/8.0/x86_64/" mongodb && \
    # zypper refresh && \
    # zypper update -y && \
    zypper -n install mongodb-org

# Add system user and group for MongoDB
# RUN groupadd -g 1001 mongouser && \
#     useradd -m -s /bin/bash -u 1001 -g mongouser mongouser && \
#     echo "mongouser:yourpassword" | chpasswd
RUN useradd -m -s /bin/bash -u 1002 -g mongod mongouser
    
# Create /data/db directory and ensure it's owned by mongouser
RUN mkdir -p /data/db && \
    chown -R mongouser:mongod /data/db && \
    chmod -R 760 /data/db

# Set up entrypoint script
COPY Docker/entrypoint.sh /entrypoint.sh
RUN chown mongouser:mongod /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Switch to non-root user
USER mongouser

# Use the entrypoint
ENTRYPOINT [ "/entrypoint.sh" ]