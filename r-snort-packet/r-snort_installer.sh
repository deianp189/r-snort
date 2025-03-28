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
type configurar_snort >/dev/null || { echo "La función configurar_snort no está disponible"; exit 1; }

# Comprobaciones iniciales
check_root
ascii_banner
log "Instalador R-SNORT iniciado"

# Selección de interfaz
seleccionar_interfaz
export IFACE

# Crear estructura de directorios
mkdir -p "$INSTALL_DIR"/{bin,etc/snort,lib,include,share,logs,rules}

# Bandera NUMA desactivada (eliminado completamente)
NUMA_FLAG=""

###############################################################################
#                               Ejecución modular                             #
###############################################################################

instalar_dependencias
instalar_paquetes_software
instalar_snort "$SOFTWARE_DIR" "$INSTALL_DIR" "$NUMA_FLAG"
limpiar_swap_temporal

# Configuración final
if configurar_snort "$CONFIG_DIR" "$INSTALL_DIR" "$IFACE"; then
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
if mostrar_estadisticas "$IFACE" "$INSTALL_DIR"; then
  log "mostrar_estadisticas ejecutado correctamente."
else
  error "mostrar_estadisticas falló."
fi
