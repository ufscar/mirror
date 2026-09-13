# shellcheck shell=bash
# Executado como serviço do systemd, sem descritores ligados à sessão SSH.
set -euo pipefail

next=$1
transaction=$2
confirm_timeout=${3:-120}
[[ $next =~ ^/nix/store/[a-z0-9]{32}-[a-zA-Z0-9.+_-]+$ ]]
[[ $transaction =~ ^/run/mirror-deploy/[a-zA-Z0-9-]+$ ]]
[[ $confirm_timeout =~ ^[1-9][0-9]*$ ]]

mkdir -p /run/mirror-deploy
exec 9>/run/mirror-deploy/lock
flock -n 9 || { echo 'Já existe uma implantação em andamento.' >&2; exit 1; }
mkdir -m 0700 "$transaction"
previous=$(readlink -f /run/current-system)
profile=/nix/var/nix/profiles/system
# As raízes protegem ambas as configurações contra o coletor durante a transação.
ln -s "$previous" "$transaction/previous"
ln -s "$next" "$transaction/next"
ln -sfn "$previous" /nix/var/nix/gcroots/mirror-deploy-previous
ln -sfn "$next" /nix/var/nix/gcroots/mirror-deploy-next

status() {
  printf '%s\n' "$1" > "$transaction/status.new"
  mv "$transaction/status.new" "$transaction/status"
}

healthy() {
  local service
  for service in nginx syncthing datadog-agent rsync; do
    systemctl is-active --quiet "$service" || return 1
  done
  curl --fail --silent --max-time 10 http://127.0.0.1:8384/rest/noauth/health >/dev/null
}

wait_healthy() {
  local _attempt
  for _attempt in {1..30}; do
    healthy && return 0
    sleep 2
  done
  return 1
}

# Chamado pelo trap EXIT, inclusive quando a ativação falha.
# shellcheck disable=SC2329
finish() {
  local result=$?
  trap - EXIT
  if [[ $(cat "$transaction/status") != committed ]]; then
    status rolling-back
    echo "Restaurando $previous"
    # O resultado de switch pode incluir falhas de tarefas periódicas. Mesmo
    # nesse caso, verificamos explicitamente a recuperação dos serviços contínuos.
    if nix-env --profile "$profile" --set "$previous" &&
       "$previous/bin/switch-to-configuration" switch; then
      echo 'Configuração anterior reativada.'
    else
      echo 'A reativação anterior reportou erro.' >&2
    fi
    if [[ $(readlink -f /run/current-system) == "$previous" ]] && wait_healthy; then
      status rolled-back
    else
      status rollback-failed
    fi
    result=1
  fi
  rm -f /nix/var/nix/gcroots/mirror-deploy-{previous,next}
  exit "$result"
}
status activating
trap finish EXIT
trap 'exit 1' TERM INT

nix-env --profile "$profile" --set "$next"
"$next/bin/switch-to-configuration" switch
wait_healthy
status awaiting-confirmation
echo 'Aguardando confirmação por uma nova conexão SSH.'
deadline=$((SECONDS + confirm_timeout))
while ((SECONDS < deadline)); do
  if [[ -f $transaction/confirm ]] && healthy; then
    status committed
    echo 'Implantação confirmada.'
    exit 0
  fi
  sleep 2
done
echo 'A confirmação não chegou dentro do prazo.' >&2
exit 1
