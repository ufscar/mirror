#!/usr/bin/env bash
set -euo pipefail

# A consulta HTTPS é curta e limitada; somente os pacotes usam rsync.
target=${ARCH32_TARGET:-/data/mirror/archlinux32}
source_url=rsync://buildmaster.archlinux32.org/archlinux32/
metadata_url=https://mirror.archlinux32.org
mkdir -p "$target"

# Mesmo sistema de arquivos do destino, para publicar cada marcador por rename.
metadata=$(mktemp -d "$target/.sync-markers.XXXXXX")
trap 'rm -rf "$metadata"' EXIT
for marker in lastupdate lastsync; do
  value=$(curl --fail --silent --show-error --connect-timeout 5 --max-time 20 \
    "$metadata_url/$marker")
  if [[ ! $value =~ ^[1-9][0-9]{0,11}$ ]]; then
    echo "Timestamp inválido recebido para $marker" >&2
    exit 1
  fi
  printf '%s\n' "$value" > "$metadata/$marker"
done

if [[ ${ARCH32_FORCE_SYNC:-0} == 1 ]] ||
   ! cmp -s "$metadata/lastupdate" "$target/lastupdate"; then
  echo 'Sincronizando pacotes do Arch Linux 32.'
  # Uma transferência interrompida não pode publicar marcadores de sucesso.
  # A exclusão do diretório temporário também o protege das deleções do rsync.
  rsync -rlptH --safe-links --delete-delay --delay-updates \
    --timeout=600 --contimeout=60 --no-motd --quiet \
    --exclude=/lastupdate --exclude=/lastsync --exclude='/.sync-markers.*/' \
    "$source_url" "$target/"
fi

# Publicar lastsync antes de lastupdate mantém a próxima tentativa conservadora
# se o processo for interrompido entre os dois renames.
mv -f "$metadata/lastsync" "$target/lastsync"
mv -f "$metadata/lastupdate" "$target/lastupdate"
echo 'Arch Linux 32 atualizado.'
