#!/bin/bash
# Install/update bws (Bitwarden Secrets Manager CLI) from bitwarden/sdk-sm releases.
# Espejo de bw-install.bash. Target: x86_64 Linux (glibc/gnu). Instala en el mismo dir que bw.
# Get latest bws release tag (bws-vX.Y.Z)
version=$(curl -s "https://api.github.com/repos/bitwarden/sdk-sm/releases?per_page=30" | jq -r '[.[] | select(.tag_name | test("bws-v"))][0].tag_name')
# Download latest bws (x86_64 linux gnu)
mkdir -p "$HOME/.config/Bitwarden CLI"
curl -s "https://api.github.com/repos/bitwarden/sdk-sm/releases?per_page=30" | jq -r '[.[] | select(.tag_name | test("bws-v"))][0].assets[] | select(.name | test("x86_64-unknown-linux-gnu")) | .browser_download_url' | head -n 1 | xargs -I {} curl -L -o "$HOME/.config/Bitwarden CLI"/bws-$version.zip {}
# Extract content
unzip -o "$HOME/.config/Bitwarden CLI"/bws-$version.zip -d "$HOME/.config/Bitwarden CLI"/
rm "$HOME/.config/Bitwarden CLI"/bws-$version.zip
chmod +x "$HOME/.config/Bitwarden CLI"/bws
