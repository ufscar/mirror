# shellcheck shell=bash

########
#
# Copyright © 2014-2019 Florian Pritz <bluewind@xinu.at>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.
#
########
#
# This is a simple mirroring script. To save bandwidth it first checks a
# timestamp via HTTP and only runs rsync when the timestamp differs from the
# local copy. As of 2016, a single rsync run without changes transfers roughly
# 6MiB of data which adds up to roughly 250GiB of traffic per month when rsync
# is run every minute. Performing a simple check via HTTP first can thus save a
# lot of traffic.

# Directory where the repo is stored locally. Example: /srv/repo
target="${ARCH_MIRROR_TARGET:-/data/mirror/archlinux/}"
state_dir="${ARCH_MIRROR_STATE_DIR:-${STATE_DIRECTORY:-/var/lib/sync-archlinux}}"

# Uma sincronização saudável normalmente termina em menos de um minuto. O
# limite total impede que tráfego muito lento mantenha o serviço bloqueado
# indefinidamente, mesmo quando ainda há atividade e o --timeout do rsync não
# é acionado.
transfer_timeout="${ARCH_MIRROR_TRANSFER_TIMEOUT:-300}"
cooldown_seconds="${ARCH_MIRROR_COOLDOWN:-1800}"

# Lockfile path
#lock="/dev/shm/sync-archlinux.lck"

# If you want to limit the bandwidth used by rsync set this.
# Use 0 to disable the limit.
# The default unit is KiB (see man rsync /--bwlimit for more)
bwlimit=0

# Upstreams em ordem de preferência. O maior lastupdate sempre vence; quando
# vários upstreams possuem a mesma geração, esta ordem evita trocas de origem
# desnecessárias. O lastsync serve para monitoramento, não para desempate de
# uma sincronização completa.
upstream_names=(umea uni-plovdiv constant moson ubrco)
upstream_rsync_urls=(
  'rsync://umea.mirror.pkgbuild.com/packages/'
  'rsync://mirrors.uni-plovdiv.net/archlinux/'
  'rsync://arch.mirror.constant.com/archlinux/'
  'rsync://mirror.moson.org/arch/'
  'rsync://mirror.ubrco.de/archlinux/'
)
upstream_http_urls=(
  'https://umea.mirror.pkgbuild.com'
  'https://mirrors.uni-plovdiv.net/archlinux'
  'https://arch.mirror.constant.com'
  'https://mirror.moson.org/arch'
  'https://mirror.ubrco.de/archlinux'
)

#### END CONFIG

[ ! -d "${target}" ] && mkdir -p "${target}"
mkdir -p "$state_dir"

if [[ ! $transfer_timeout =~ ^[1-9][0-9]*$ ||
      ! $cooldown_seconds =~ ^[1-9][0-9]*$ ]]; then
  echo 'Os tempos de sincronização e cooldown precisam ser inteiros positivos' >&2
  exit 1
fi

#exec 9>"${lock}"
#flock -n 9 || exit

# Cleanup any temporary files from old run that might remain.
# Note: You can skip this if you have rsync newer than 3.2.3
# not affected by https://github.com/WayneD/rsync/issues/192
#find "${target}" -name '.~tmp~' -exec rm -r {} +

rsync_cmd() {
  local deadline=$1
  shift
  local -a cmd=(rsync -rlptH --safe-links --delete-delay --delay-updates
    "--timeout=60" "--contimeout=15" --no-motd)

  if stty &>/dev/null; then
    cmd+=(-h -v --progress)
  else
    cmd+=(--quiet)
  fi

  if ((bwlimit>0)); then
    cmd+=("--bwlimit=$bwlimit")
  fi

  if ((deadline > 0)); then
    timeout --signal=TERM --kill-after=30s "${deadline}s" \
      "${cmd[@]}" "$@"
  else
    "${cmd[@]}" "$@"
  fi
}

probe_upstream() {
  local i=$1 lastupdate lastsync now

  if ! lastupdate=$(curl --fail --silent --location \
      --connect-timeout 3 --max-time 8 \
      "${upstream_http_urls[i]}/lastupdate"); then
    printf '%s\thttp-error\t0\t0\n' "$i"
    return
  fi

  if ! lastsync=$(curl --fail --silent --location \
      --connect-timeout 3 --max-time 8 \
      "${upstream_http_urls[i]}/lastsync"); then
    printf '%s\thttp-error\t0\t0\n' "$i"
    return
  fi

  # Limita o formato antes de repassar os valores para o processo principal.
  if [[ ! $lastupdate =~ ^[0-9]{10}$ || ! $lastsync =~ ^[0-9]{10}$ ]]; then
    printf '%s\tinvalid\t0\t0\n' "$i"
    return
  fi

  now=$(date +%s)
  if ((lastupdate > now + 300 || lastsync > now + 300 || lastsync < lastupdate)); then
    printf '%s\tinvalid\t0\t0\n' "$i"
    return
  fi

  printf '%s\tok\t%s\t%s\n' "$i" "$lastupdate" "$lastsync"
}

declare -a statuses observed_lastupdates observed_lastsyncs
declare -A cooldowns attempted
health_file="$state_dir/upstream-cooldowns"

load_cooldowns() {
  local name until now
  now=$(date +%s)
  [[ -f $health_file ]] || return

  while read -r name until; do
    [[ $until =~ ^[0-9]+$ ]] || continue
    ((until > now)) || continue
    cooldowns[$name]=$until
  done < "$health_file"
}

save_cooldowns() {
  local name temporary
  temporary="$health_file.$$"
  : > "$temporary"
  for name in "${!cooldowns[@]}"; do
    printf '%s %s\n' "$name" "${cooldowns[$name]}" >> "$temporary"
  done
  mv "$temporary" "$health_file"
}

mark_failed() {
  local i=$1 reason=$2 now
  now=$(date +%s)
  cooldowns[${upstream_names[i]}]=$((now + cooldown_seconds))
  attempted[$i]=1
  save_cooldowns
  printf 'Upstream %s falhou (%s); suspenso por %ss\n' \
    "${upstream_names[i]}" "$reason" "$cooldown_seconds" >&2
}

mark_healthy() {
  local i=$1
  unset "cooldowns[${upstream_names[i]}]"
  save_cooldowns
}

probe_upstreams() {
  local probe_output i status lastupdate lastsync

  statuses=()
  observed_lastupdates=()
  observed_lastsyncs=()

  # Cada candidato exige duas requisições. Executá-las em paralelo evita que
  # a escolha do upstream consuma quase todo o intervalo do timer.
  probe_output=$(
    for i in "${!upstream_names[@]}"; do
      probe_upstream "$i" &
    done
    wait
  )

  while IFS=$'\t' read -r i status lastupdate lastsync; do
    statuses[i]=$status
    observed_lastupdates[i]=$lastupdate
    observed_lastsyncs[i]=$lastsync
  done <<< "$probe_output"
}

select_upstream() {
  local minimum_lastupdate=$1 i lastupdate now cooldown_until
  local best=-1 best_lastupdate=-1

  probe_upstreams
  now=$(date +%s)

  for i in "${!upstream_names[@]}"; do
    [[ ${statuses[i]:-missing} == ok ]] || continue
    [[ -z ${attempted[$i]:-} ]] || continue

    cooldown_until=${cooldowns[${upstream_names[i]}]:-0}
    if ((cooldown_until > now)); then
      continue
    fi

    lastupdate=${observed_lastupdates[i]}
    ((lastupdate >= minimum_lastupdate)) || continue

    # Em empate, o primeiro elemento da lista permanece selecionado.
    if ((lastupdate > best_lastupdate)); then
      best=$i
      best_lastupdate=$lastupdate
    fi
  done

  ((best >= 0)) || return 1

  source_index=$best
  source_url=${upstream_rsync_urls[best]}
  source_name=${upstream_names[best]}
  source_lastupdate=$best_lastupdate
  source_lastsync=${observed_lastsyncs[best]}
}

read_local_timestamp() {
  local path=$1 value
  [[ -f $path ]] || return 1
  value=$(<"$path")
  [[ $value =~ ^[0-9]{10}$ ]] || return 1
  printf '%s\n' "$value"
}

write_timestamp() {
  local path=$1 value=$2 temporary
  temporary="${path}.$$"
  printf '%s\n' "$value" > "$temporary"
  chmod 0644 "$temporary"
  mv "$temporary" "$path"
}

verify_rsync_marker() {
  local i=$1 temporary marker
  temporary="$state_dir/lastupdate.${upstream_names[i]}.$$"

  if ! rsync_cmd 30 "${upstream_rsync_urls[i]}lastupdate" "$temporary"; then
    rm -f -- "$temporary"
    return 1
  fi

  marker=$(<"$temporary")
  rm -- "$temporary"
  [[ $marker =~ ^[0-9]{10}$ &&
     $marker -eq ${observed_lastupdates[i]} ]]
}

load_cooldowns

local_lastupdate=-1
value=$(read_local_timestamp "$target/lastupdate") && local_lastupdate=$value

if [[ ${ARCH_MIRROR_PROBE_ONLY:-0} == 1 ]]; then
  probe_upstreams
  now=$(date +%s)
  for i in "${!upstream_names[@]}"; do
    cooldown_until=${cooldowns[${upstream_names[i]}]:-0}
    cooldown_remaining=0
    ((cooldown_until > now)) && cooldown_remaining=$((cooldown_until - now))
    printf '%-12s status=%-10s lastupdate=%s lastsync=%s cooldown=%s\n' \
      "${upstream_names[i]}" "${statuses[i]:-missing}" \
      "${observed_lastupdates[i]:-0}" "${observed_lastsyncs[i]:-0}" \
      "$cooldown_remaining"
  done
  exit 0
fi

if ! select_upstream "$local_lastupdate"; then
  echo 'Nenhum upstream válido e saudável está tão atualizado quanto o mirror local' >&2
  exit 1
fi

# Um conjunto fixo de upstreams não impede regressões quando o mais atual está
# indisponível. Nunca substitua uma geração local por outra mais antiga.
if ((source_lastupdate < local_lastupdate)); then
  printf 'Todos os upstreams válidos estão atrás do mirror local; mantendo lastupdate=%s\n' \
    "$local_lastupdate" >&2
  exit 0
fi

# if we are called without a tty (cronjob) only run when there are changes
if ! tty -s && ((source_lastupdate == local_lastupdate)); then
  local_lastsync=-1
  value=$(read_local_timestamp "$target/lastsync") && local_lastsync=$value

  # Para atualizar apenas o marcador, use o maior lastsync da geração local.
  for i in "${!upstream_names[@]}"; do
    [[ ${statuses[i]:-missing} == ok ]] || continue
    ((observed_lastupdates[i] == local_lastupdate)) || continue
    if ((observed_lastsyncs[i] > source_lastsync)); then
      source_index=$i
      source_url=${upstream_rsync_urls[i]}
      source_name=${upstream_names[i]}
      source_lastsync=${observed_lastsyncs[i]}
    fi
  done

  ((source_lastsync > local_lastsync)) || exit 0

  # O valor já veio do endpoint HTTPS e foi validado. Gravá-lo diretamente
  # evita uma conexão rsync adicional no caminho executado a cada 15 segundos.
  write_timestamp "$target/lastsync" "$source_lastsync"
  exit 0
fi

while :; do
  printf 'Sincronizando a partir de %s (%s), com limite de %ss\n' \
    "$source_name" "$source_url" "$transfer_timeout"

  if ! verify_rsync_marker "$source_index"; then
    mark_failed "$source_index" 'marcador rsync indisponível ou divergente do HTTP'
  elif rsync_cmd "$transfer_timeout" \
      --exclude='*.links.tar.gz*' \
      --exclude='/*-debug' \
      --exclude='/archive' \
      --exclude='/other' \
      --exclude='/pool/packages-debug' \
      --exclude='/sources' \
      "${source_url}" \
      "${target}"; then
    synced_lastupdate=$(read_local_timestamp "$target/lastupdate") || synced_lastupdate=-1
    synced_lastsync=$(read_local_timestamp "$target/lastsync") || synced_lastsync=-1

    if ((synced_lastupdate >= source_lastupdate &&
        synced_lastsync >= synced_lastupdate)); then
      mark_healthy "$source_index"
      exit 0
    fi
    mark_failed "$source_index" 'marcadores inválidos após a sincronização'
  else
    status=$?
    if ((status == 124 || status == 137)); then
      mark_failed "$source_index" "limite total de ${transfer_timeout}s excedido"
    else
      mark_failed "$source_index" "rsync terminou com status $status"
    fi
  fi

  # Consulte novamente todos os marcadores: durante uma tentativa longa, os
  # demais upstreams podem ter alcançado a geração que estava à frente.
  value=$(read_local_timestamp "$target/lastupdate") || value=-1
  ((value > local_lastupdate)) && local_lastupdate=$value
  if ! select_upstream "$source_lastupdate"; then
    echo 'Todos os upstreams elegíveis falharam ou estão em cooldown' >&2
    exit 1
  fi
done

#echo "Last sync was $(date -d @$(cat ${target}/lastsync))"
