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
target="/data/mirror/archlinux/"

# Lockfile path
#lock="/dev/shm/sync-archlinux.lck"

# If you want to limit the bandwidth used by rsync set this.
# Use 0 to disable the limit.
# The default unit is KiB (see man rsync /--bwlimit for more)
bwlimit=0

# Upstreams em ordem de preferência para o desempate. A seleção prioriza o
# maior lastupdate e, em caso de empate, o maior lastsync.
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

#exec 9>"${lock}"
#flock -n 9 || exit

# Cleanup any temporary files from old run that might remain.
# Note: You can skip this if you have rsync newer than 3.2.3
# not affected by https://github.com/WayneD/rsync/issues/192
#find "${target}" -name '.~tmp~' -exec rm -r {} +

rsync_cmd() {
  local -a cmd=(rsync -rlptH --safe-links --delete-delay --delay-updates
    "--timeout=600" "--contimeout=60" --no-motd)

  if stty &>/dev/null; then
    cmd+=(-h -v --progress)
  else
    cmd+=(--quiet)
  fi

  if ((bwlimit>0)); then
    cmd+=("--bwlimit=$bwlimit")
  fi

  "${cmd[@]}" "$@"
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

select_upstream() {
  local probe_output i status lastupdate lastsync
  local best=-1 best_lastupdate=-1 best_lastsync=-1
  local -a statuses observed_lastupdates observed_lastsyncs

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

  for i in "${!upstream_names[@]}"; do
    [[ ${statuses[i]:-missing} == ok ]] || continue
    lastupdate=${observed_lastupdates[i]}
    lastsync=${observed_lastsyncs[i]}

    if ((lastupdate > best_lastupdate ||
        (lastupdate == best_lastupdate && lastsync > best_lastsync))); then
      best=$i
      best_lastupdate=$lastupdate
      best_lastsync=$lastsync
    fi
  done

  if ((best < 0)); then
    echo 'Nenhum upstream do Arch Linux forneceu marcadores válidos' >&2
    return 1
  fi

  source_url=${upstream_rsync_urls[best]}
  source_name=${upstream_names[best]}
  source_lastupdate=$best_lastupdate
  source_lastsync=$best_lastsync
}

select_upstream || exit 1

local_lastupdate=-1
if [[ -f $target/lastupdate ]]; then
  value=$(<"$target/lastupdate")
  [[ $value =~ ^[0-9]{10}$ ]] && local_lastupdate=$value
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
  if [[ -f $target/lastsync ]]; then
    value=$(<"$target/lastsync")
    [[ $value =~ ^[0-9]{10}$ ]] && local_lastsync=$value
  fi

  ((source_lastsync > local_lastsync)) || exit 0

  # keep lastsync file in sync for statistics generated by the Arch Linux website
  rsync_cmd "${source_url}lastsync" "$target/lastsync"
  exit 0
fi

printf 'Sincronizando a partir de %s (%s)\n' "$source_name" "$source_url"
rsync_cmd \
  --exclude='*.links.tar.gz*' \
  --exclude='/*-debug' \
  --exclude='/archive' \
  --exclude='/other' \
  --exclude='/pool/packages-debug' \
  --exclude='/sources' \
  "${source_url}" \
  "${target}"

#echo "Last sync was $(date -d @$(cat ${target}/lastsync))"
