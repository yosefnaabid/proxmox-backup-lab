#!/bin/bash
# ===========================================================================
# disaster.sh — provoca la pérdida. Destruye por completo una VM del lab
# (la VM y sus discos), simulando un desastre real.
#
#   Uso:  ./disaster.sh [VMID]      (por defecto 113 = fs01, el fileserver)
#
# Se ejecuta en el nodo Proxmox (pve01).
# ===========================================================================
set -euo pipefail

VMID="${1:-113}"
KEY=/root/.ssh/id_lab

echo "=== [disaster] Estado ANTES ==="
if ! qm status "$VMID" >/dev/null 2>&1; then
  echo "La VM $VMID no existe. Nada que destruir."
  exit 1
fi
qm status "$VMID"

# Deja constancia de los datos que había, para contrastar tras la restauración.
IP=$(qm config "$VMID" | grep -oE 'ip=[0-9.]+' | head -1 | cut -d= -f2)
if [ -n "${IP:-}" ]; then
  echo "--- Datos de usuario existentes en $IP (se van a perder con la VM) ---"
  ssh -i "$KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=4 -o BatchMode=yes \
    "labadmin@${IP}" "cat /srv/samba/datos/IMPORTANTE.txt 2>/dev/null | head -2" || true
fi

echo
echo "=== [disaster] DESTRUYENDO la VM $VMID (stop + destroy --purge) ==="
qm stop "$VMID" || true
sleep 2
qm destroy "$VMID" --purge

echo
echo "=== [disaster] Estado DESPUÉS ==="
if qm status "$VMID" >/dev/null 2>&1; then
  echo "ERROR: la VM $VMID sigue existiendo."
  exit 1
else
  echo "La VM $VMID ha desaparecido por completo. Desastre consumado."
fi
