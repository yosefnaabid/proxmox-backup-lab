# Capturas

Capturas de pantalla reales del lab en marcha: el panel web de Proxmox y
sesiones de terminal contra el nodo `pve01`.

### 1 · Las VMs y el registro de tareas
![VMs y tareas](01-vms-panel.png)

Panel de Proxmox: las tres VMs (`dns01`, `web01`, `fs01`) más la plantilla
cloud-init. Abajo, el registro de tareas con la secuencia del desastre y la
recuperación: `VM 113: Parar → Destruir → Restaurar → Iniciar`, todo en OK.

### 2 · La red interna
![Red vmbr1](02-red-vmbr1.png)

`pve01 → Sistema → Red`: el bridge de gestión `vmbr0` (192.168.1.40/24) y el
bridge interno del lab `vmbr1` (10.10.10.1/24), creado y gestionado por Ansible.

### 3 · El backup programado
![Backups](03-backups.png)

`Centro de datos → Respaldo`: job diario a las 02:00 sobre las tres VMs
(`111,112,113`), almacenamiento `local`, retención `keep-daily=3, keep-weekly=2`.

### 4 · VMs y DNS interno por terminal
![Terminal VMs y DNS](04-terminal-vms-dns.png)

Sesión SSH al nodo: `qm list` muestra las tres VMs en marcha, y Ansible resuelve
`fs01.infra.lab` a `10.10.10.13` a través del DNS interno.

### 5 · Desastre y restauración (la estrella)
![Desastre](05-desastre-restauracion-1.png)

`disaster.sh` destruye `fs01` por completo; acto seguido `restore.sh` la
restaura desde su backup.

![Verificación](05-desastre-restauracion-2.png)

La verificación tras restaurar: la VM arranca (`fs01`), recupera su IP
(`10.10.10.13`), **los datos de usuario siguen intactos** y el servicio Samba
vuelve a estar `active`.

### 6 · Idempotencia
![Idempotencia](06-idempotencia.png)

`ansible-playbook site.yml` relanzado: `changed=0` en todos los hosts. Es
infraestructura como código, reproducible, no configuración a mano.
