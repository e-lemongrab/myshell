#!/bin/bash
cd "$project_path/modules/docker/k6" || exit 1

# Neteja de contenidors k6 antics (de la versio ps1)
if docker ps -a --format '{{.Names}}' | grep -qx "k6"; then
    echo "Se elimina el container"
    docker rm -f k6
fi

echo "Serveis per analitzar:"
ls scripts/
read -rp "Seleccioneu el que voleu fer: " entorn

if [ ! -f "scripts/$entorn/$entorn.js" ]; then
    echo "No existeix scripts/$entorn/$entorn.js"
    exit 1
fi

docker compose run --rm k6 run "/mnt/local/scripts/$entorn/$entorn.js"
# --out csv=/mnt/local/scripts/$entorn/$entorn.csv
