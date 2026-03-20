#!/usr/bin/env bash

########
#
# This is a simple mirroring script for Arch Linux 32. 
# To save bandwidth it first checks a timestamp via rsync and only runs 
# full rsync when the timestamp differs from the local copy.
#
########

# Directory where the repo is stored locally.
target="/data/mirror/archlinux32/"

# If you want to limit the bandwidth used by rsync set this.
# Use 0 to disable the limit.
# The default unit is KiB (see man rsync /--bwlimit for more)
bwlimit=0

# The source URL of the mirror you want to sync from.
source_url='rsync://buildmaster.archlinux32.org/archlinux32/'

#### END CONFIG

[ ! -d "${target}" ] && mkdir -p "${target}"

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


# If we are called without a tty (cronjob/systemd timer) only run when there are changes.
if ! tty -s && [[ -f "$target/lastupdate" ]]; then
  # Fetch 'lastupdate' and 'lastsync' directly to the target directory.
  # The -t flag preserves timestamps, -i itemizes changes (outputs which files changed).
  changes=$(rsync -ti "${source_url%/}/lastupdate" "${source_url%/}/lastsync" "$target/")
  
  # If rsync succeeded (0) and 'lastupdate' was NOT modified (not in output),
  # we skip the full sync. Both files were already updated if needed.
  if [[ $? -eq 0 ]] && ! echo "$changes" | grep -q "lastupdate"; then
    exit 0
  fi
fi

rsync_cmd \
  "${source_url}" \
  "${target}"
