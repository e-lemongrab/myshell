#!/bin/bash
source "$mod_colors"
clear
cyan
echo "Docker"
nocolor
yellow
echo "Crear/cargar container - php:7.2-apache es nombre_repo:tag (docker images)"
nocolor
echo "docker run -it debian"
echo "docker run --rm --publish 8080:80 --detach --name apache php:7.2-apache"
yellow
echo "Gestión Containers"
nocolor
yellow
echo "Abrir terminal bash en el container"
nocolor
echo "docker exec -it apache /bin/bash"
yellow
echo "Copiar archivo desde host a dentro del container"
nocolor
echo "docker cp index.html 4f950f3d6c81:/srv/www/htdocs/index.html"
yellow
echo "Entrypoint sempre"
nocolor
echo 'ENTRYPOINT ["tail", "-f", "/dev/null"]'
yellow
echo "Helm"
nocolor
echo "helm install nexus nexus-repository-manager-34.1.0.tgz -n nexus -f values.yaml"
echo "helm delete nexus -n nexus"
