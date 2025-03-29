#!/bin/bash
###############################################################################
#                           R-SNORT INSTALLER                                 #
###############################################################################
set -euo pipefail
trap 'echo -e "\n\033[0;31m[✗] Fallo en línea $LINENO del script principal\033[0m"' ERR

CONFIG_DIR="$(pwd)/configuracion"
SOFTWARE_DIR="$(pwd)/software"
INSTALL_DIR="/usr/local/snort"
LOG_FILE="/var/log/snort_install.log"

# Redirigir salida a log inmediatamente
exec > >(tee -a "$LOG_FILE") 2>&1

# Importar funciones
source ./bin/core.sh
source ./bin/checks.sh
source ./bin/swap.sh
source ./bin/dependencies.sh
source ./bin/build_from_source.sh
source ./bin/install_snort.sh
source ./bin/configure_snort.sh
source ./bin/stats.sh

# Verificación mínima
type snort_config >/dev/null || { echo "La función snort_config no está disponible"; exit 1; }

# Comprobaciones iniciales
check_root
ascii_banner
log "Instalador R-SNORT iniciado"

# Selección de interfaz
interface_selection
export IFACE

# Crear estructura de directorios
mkdir -p "$INSTALL_DIR"/{bin,etc/snort,lib,include,share,logs,rules}

###############################################################################
#                               Ejecución modular                             #
###############################################################################

dependencies_install
software_package_install
snort_install "$SOFTWARE_DIR" "$INSTALL_DIR"
temp_swap_clean

# Configuración final
if snort_config "$CONFIG_DIR" "$INSTALL_DIR" "$IFACE"; then
  log "configurar_snort ejecutado correctamente."
else
  error "configurar_snort falló."
fi

# Comprobación de estado del servicio
log "Comprobando estado del servicio Snort..."
if systemctl is-enabled --quiet snort && systemctl is-active --quiet snort; then
  log "Snort está activo y habilitado."
else
  error "Snort no se encuentra activo o habilitado. Verifica manualmente con: systemctl status snort"
fi

# Estadísticas
log "Llamando a mostrar_estadisticas con: $IFACE $INSTALL_DIR"
if show_stats "$IFACE" "$INSTALL_DIR"; then
  log "mostrar_estadisticas ejecutado correctamente."
else
  error "mostrar_estadisticas falló."
fi
