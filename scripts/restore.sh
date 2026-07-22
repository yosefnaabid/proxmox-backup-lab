#!/bin/bash
# ===========================================================================
# restore.sh — restaura una VM desde su backup más reciente y VERIFICA que
# vuelve a arrancar y que los datos de usuario siguen intactos.
#
#   Uso:  ./restore.sh [VMID] [IP]     (por defecto 113  10.10.10.13 = fs01)
#
# Se ejecuta en el nodo Proxmox (pve01). Es la contraparte de disaster.sh:
# el sello "respaldar y verificar".
# ===========================================================================
set -euo pipefail

VMID="${1:-113}"
IP="${2:-10.10.10.13}"
STORAGE=local
RESTORE_STORAGE=local-lvm
KEY=/root/.ssh/id_lab

echo "=== [restore] Buscando el backup más reciente de la VM $VMID ==="
BACKUP=$(pvesm list "$STORAGE" --content backup --vmid "$VMID" \
         | awk '/vzdump-qemu-'"$VMID"'-/ {print $1}' | sort | tail -1)
if [ -z "$BACKUP" ]; then
  echo "No hay ningún backup para la VM $VMID. Aborto."
  exit 1
fi
echo "Backup elegido: $BACKUP"

echo
echo "=== [restore] Restaurando la VM desde el backup ==="
qmrestore "$BACKUP" "$VMID" --storage "$RESTORE_STORAGE"

echo
echo "=== [restore] Arrancando la VM $VMID ==="
qm start "$VMID"

echo "=== [restore] Esperando a que responda por SSH ==="
ok=0
for i in $(seq 1 40); do
  if ssh -i "$KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
       "labadmin@${IP}" true 2>/dev/null; then
    echo "SSH OK (~$((i*3))s)"; ok=1; break
  fi
  sleep 3
done
[ "$ok" = 1 ] || { echo "La VM no respondió por SSH tras 120s. Aborto."; exit 1; }

echo
echo "=== [restore] VERIFICACIÓN ==="
run() { ssh -i "$KEY" -o StrictHostKeyChecking=no -o BatchMode=yes "labadmin@${IP}" "$@"; }

echo -n "  Arranque (hostname):       "; run hostname
echo -n "  IP recuperada:             "; run "hostname -I"
echo    "  Datos de usuario intactos: "; run "cat /srv/samba/datos/IMPORTANTE.txt" | sed 's/^/     /'
echo -n "  Servicio Samba activo:     "; run "systemctl is-active smbd"

echo
echo "=== [restore] OK — la VM $VMID ha vuelto a la vida y los datos SOBREVIVEN. ==="
