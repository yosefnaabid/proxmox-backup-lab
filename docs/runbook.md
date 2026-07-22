# Runbook de recuperación de proxmox-backup-lab

Procedimientos operativos para recuperar el lab cuando algo se rompe. Todo se
ejecuta desde el nodo Proxmox (`pve01`) salvo que se indique lo contrario.

## Mapa rápido

| VM   | VMID | IP           | Servicio            |
|------|------|--------------|---------------------|
| dns01| 111  | 10.10.10.11  | DNS interno (bind9) |
| web01| 112  | 10.10.10.12  | Web (nginx + HTTPS) |
| fs01 | 113  | 10.10.10.13  | Ficheros (Samba)    |

- Nodo Proxmox: `pve01` (192.168.1.40), web UI en `https://192.168.1.40:8006`.
- Red interna: `vmbr1`, 10.10.10.0/24, salida a internet por NAT.
- Backups: almacenamiento `local` (`/var/lib/vz/dump`), job diario a las 02:00,
  retención 3 diarios + 2 semanales.

---

## 1. Restaurar una VM caída

Cuando una VM se ha perdido, corrompido o no arranca.

```bash
# Restaura desde el backup más reciente y verifica arranque + datos:
/root/proxmox-backup-lab/scripts/restore.sh <VMID> <IP>
# Ejemplo, fileserver:
/root/proxmox-backup-lab/scripts/restore.sh 113 10.10.10.13
```

El script elige el backup más reciente, hace `qmrestore`, arranca la VM, espera
al SSH y comprueba hostname, IP, datos de usuario y servicio.

> **Nota:** si el desastre se provocó con `qm destroy --purge`, la VM se quita
> también del job de backup programado. Tras restaurarla, re-registrala con
> `ansible-playbook site.yml --tags backup` (el rol se autorrepara y vuelve a
> incluir la VM en el job).

**A mano**, si se quiere control fino:

```bash
# 1. Backup más reciente de la VM:
pvesm list local --content backup --vmid 113

# 2. Restaurar (la VM no debe existir; si existe, añadir --force):
qmrestore local:backup/vzdump-qemu-113-FECHA.vma.zst 113 --storage local-lvm

# 3. Arrancar y comprobar:
qm start 113
qm status 113
```

---

## 2. Recuperar los ficheros de un usuario

Cuando no hace falta restaurar la VM entera, solo rescatar ficheros de un
backup. El backup `.vma.zst` se puede montar sin sobrescribir la VM en marcha.

```bash
# Opción A: restaurar a una VMID temporal y copiar los ficheros:
qmrestore local:backup/vzdump-qemu-113-FECHA.vma.zst 999 --storage local-lvm
qm set 999 --net0 virtio,bridge=vmbr1 --ipconfig0 ip=10.10.10.99/24,gw=10.10.10.1
qm start 999
scp -i /root/.ssh/id_lab labadmin@10.10.10.99:/srv/samba/datos/FICHERO ./
qm stop 999 && qm destroy 999 --purge   # limpiar la temporal

# Opción B: extraer el disco del backup con vma:
mkdir -p /var/tmp/restore
zstd -d -c /var/lib/vz/dump/vzdump-qemu-113-FECHA.vma.zst | vma extract - /var/tmp/restore
# ...montar la imagen resultante con guestmount/kpartx y copiar.
```

---

## 3. Simular el desastre (para demostrar la recuperación)

```bash
# DESTRUYE por completo la VM indicada (la VM y sus discos):
/root/proxmox-backup-lab/scripts/disaster.sh 113
```

Después, recuperar con el paso 1. Esta pareja disaster/restore es la prueba de
que los backups sirven de verdad.

---

## 4. Comprobar que los backups están al día

```bash
# Backups presentes por VM:
pvesm list local --content backup

# Estado del job programado:
pvesh get /cluster/backup --output-format yaml

# Lanzar un backup manual ya mismo:
vzdump 111 112 113 --storage local --mode snapshot --compress zstd \
  --prune-backups keep-daily=3,keep-weekly=2
```

---

## 5. Rehacer el lab desde cero

Si hay que reconstruirlo entero (nodo nuevo o VMs borradas):

```bash
cd /root/proxmox-backup-lab/ansible
ansible-playbook site.yml            # crea red, plantilla, VMs y servicios
ansible-playbook site.yml --tags backup   # configura backups y toma el primero
```

El playbook es idempotente: se puede relanzar sin miedo, solo cambia lo que
haga falta.
