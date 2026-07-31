#!/bin/bash

set -euo pipefail

#INFO
export RELEASE=0.0.0
export APPLICATION_VERSION=testing
export BRANCA=testing
export NAPLICACIO=testing
MOMENTINICI=$(date +"%d-%m-%Y--%H:%M")
export MOMENTINICI
mkdir -p /usr/local/tomcat/webapps/info
printf '%s de %s Compilacio %s %s Iniciat el %s\n' \
	"$NAPLICACIO" "$BCNACT_ENTORN" "$BRANCA" "$RELEASE" "$MOMENTINICI" \
	>/usr/local/tomcat/webapps/info/index.html
#CONFIGURACIO KEYSTORE
keytool -genkey -noprompt \
	-alias AP000 \
	-dname "CN=localhost:4443, OU=SSI, O=BA, L=Barcelona, S=Catalunya, C=ES" \
	-storetype PKCS12 \
	-keyalg RSA \
	-keysize 2048 \
	-keystore /home/AP000.jks \
	-storepass 1nternet! \
	-keypass 1nternet!

keytool -certreq -noprompt \
	-keyalg RSA \
	-keysize 2048 \
	-alias AP000 \
	-file /home/AP000.csr \
	-keystore /home/AP000.jks \
	-storepass 1nternet! \
	-keypass 1nternet!

cp -f "/tmp/entorns/$BCNACT_ENTORN/catalina.bash" /usr/local/tomcat/bin/catalina.sh

# Optional local payloads stay outside the image and can be supplied by the
# existing /tmp/volum bind mount.
[ ! -f /tmp/volum/server.xml ] || cp -f /tmp/volum/server.xml /usr/local/tomcat/conf/server.xml
[ ! -f /tmp/volum/sample.war ] || cp -f /tmp/volum/sample.war /usr/local/tomcat/webapps/sample.war

exec /usr/local/tomcat/bin/catalina.sh run
