#!/usr/bin/env bash

set -euo pipefail

cp -f "/tmp/configs/$ENVIRONMENT/db.cnf" /etc/mysql/conf.d/db.cnf
cp -f /tmp/configs/General/general.cnf /etc/mysql/conf.d/general.cnf
chmod 755 /etc/mysql/conf.d
chmod 644 /etc/mysql/conf.d/db.cnf /etc/mysql/conf.d/general.cnf

mkdir -p /etc/mysql/ssl
if [ -f "/tmp/configs/$ENVIRONMENT/ca.crt" ]; then
	cp -f "/tmp/configs/$ENVIRONMENT/ca.crt" "/tmp/configs/$ENVIRONMENT/cert.crt" \
		"/tmp/configs/$ENVIRONMENT/key.key" /etc/mysql/ssl/
	chown -R mysql:mysql /etc/mysql/ssl
	chmod 700 /etc/mysql/ssl
	chmod 600 /etc/mysql/ssl/*
fi

exec docker-entrypoint.sh mysqld
