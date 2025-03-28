#!/bin/bash
set -euo pipefail

CONFIG_DIR="$(pwd)/configuracion"
SOFTWARE_DIR="$(pwd)/software"
INSTALL_DIR="/usr/local/snort"
LOG_FILE="/var/log/snort_install.log"

source ./bin/core.sh
source ./bin/checks.sh
source ./bin/swap.sh
source ./bin/dependencies.sh
source ./bin/build_from_source.sh
source ./bin/install_snort.sh
source ./bin/configure_snort.sh
source ./bin/stats.sh

exec > >(tee -a "$LOG_FILE") 2>&1

check_root
ascii_banner
log "Instalador R-SNORT iniciado"

IFACE=$(seleccionar_interfaz)
log "Interfaz seleccionada: $IFACE"

mkdir -p "$INSTALL_DIR"/{bin,etc/snort,lib,include,share,logs,rules}

instalar_dependencias
instalar_paquetes_software
instalar_snort3 "$SOFTWARE_DIR" "$INSTALL_DIR"
limpiar_swap_temporal
configurar_snort3 "$CONFIG_DIR" "$INSTALL_DIR" "$IFACE"
mostrar_estadisticas "$IFACE" "$INSTALL_DIR"