# shellcheck shell=bash
set -euo pipefail

next=$1
worker=$2
host=${3:-deploy@mirror.ufscar.br}
[[ $next =~ ^/nix/store/[a-z0-9]{32}-[a-zA-Z0-9.+_-]+$ ]]
[[ $worker =~ ^/nix/store/[a-z0-9]{32}-[a-zA-Z0-9.+_-]+$ ]]
ssh_options=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
# O comando remoto é construído com caminhos do Nix e identificadores locais.
# shellcheck disable=SC2029
remote() { ssh "${ssh_options[@]}" "$host" "$@"; }

nix copy --to "ssh://$host" "$next" "$worker"

id="$(date -u +%Y%m%dT%H%M%S)-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
transaction="/run/mirror-deploy/$id"
unit="mirror-deploy-$id"
echo "Transação: $transaction; journal: $unit"
# Não usar --pipe, --pty ou --scope: a transação precisa sobreviver ao SSH.
# A resposta pode se perder quando o nginx reiniciar; a consulta abaixo resolve
# essa ambiguidade sem iniciar uma segunda transação.
remote "sudo -n systemd-run --unit=$unit --property=Type=exec --property=StandardOutput=journal --property=StandardError=journal $worker/bin/mirror-deploy-worker $next $transaction" || true

deadline=$((SECONDS + 3900))
last_status=''
while ((SECONDS < deadline)); do
  state=$(remote "sudo -n cat $transaction/status" 2>/dev/null) || state=unreachable
  if [[ $state != "$last_status" ]]; then
    echo "Estado: $state"
    last_status=$state
  fi
  case "$state" in
    awaiting-confirmation)
      # A conexão nova prova que o caminho de administração voltou a funcionar.
      remote "sudo -n touch $transaction/confirm" || true
      ;;
    committed)
      echo 'Implantação concluída e confirmada.'
      exit 0
      ;;
    rolled-back|rollback-failed)
      remote "sudo -n journalctl -u $unit --no-pager -n 100" || true
      exit 1
      ;;
    unreachable)
      # Distingue demora da rede de um worker que falhou antes de criar o estado.
      active=$(remote "systemctl show $unit -p ActiveState --value" 2>/dev/null) || active=''
      if [[ $active == failed || $active == inactive ]]; then
        remote "sudo -n journalctl -u $unit --no-pager -n 100" || true
        exit 1
      fi
      ;;
  esac
  sleep 5
done
echo "Prazo do cliente excedido; consulte $unit. A transação continua no servidor." >&2
exit 1
