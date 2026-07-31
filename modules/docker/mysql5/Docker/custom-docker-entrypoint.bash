#!/usr/bin/env bash

set -euo pipefail

cp -f "/tmp/configs/$ENVIRONMENT/db.cnf" /etc/mysql/conf.d/db.cnf
cp -f /tmp/configs/General/general.cnf /etc/mysql/conf.d/general.cnf
chmod 755 /etc/mysql/conf.d
chmod 644 /etc/mysql/conf.d/db.cnf /etc/mysql/conf.d/general.cnf

exec docker-entrypoint.sh mysqld
