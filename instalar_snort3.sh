#!/bin/bash

set -euo pipefail

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[*] $1${NC}"
}

success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

error() {
    echo -e "${RED}[✗] $1${NC}" >&2
    exit 1
}

# Etapa 0: Comprobaciones previas
if [ "$(id -u)" -ne 0 ]; then
    error "Este script debe ejecutarse como root"
fi

log "Interfaces de red disponibles:"
ip -o link show | awk -F': ' '{print $2}' | grep -v lo
read -p "Introduce la interfaz que quieres usar con Snort3: " IFACE
log "Usando la interfaz: $IFACE"

# Variables
CONFIG_DIR="$(pwd)/configuracion"
SOFTWARE_DIR="$(pwd)/software"
INSTALL_DIR="/usr/local/snort"
LOG_FILE="/var/log/snort_install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log "Creando directorios necesarios..."
mkdir -p $INSTALL_DIR/{bin,etc/snort,lib,include,share,logs,rules}

# Etapa 1: Instalación de dependencias
log "Instalando dependencias del sistema..."
apt-get update
apt-get install -y build-essential cmake libtool libpcap-dev libpcre3-dev     libdumbnet-dev bison flex zlib1g-dev pkg-config libhwloc-dev     liblzma-dev libssl-dev git wget curl

# Etapa 2: Descompresión e instalación de cada componente
instalar_paquete() {
    local archivo=$1
    local nombre=$(basename "$archivo" | cut -d'.' -f1)
    log "Instalando $nombre..."
    tar -xf "$archivo"
    cd "$nombre"*
    ./configure --prefix=/usr --enable-shared || cmake . -DCMAKE_INSTALL_PREFIX=/usr
    make -j"$(nproc)"
    make install
    cd ..
    rm -rf "$nombre"*
    success "$nombre instalado correctamente."
}

cd "$SOFTWARE_DIR"
for f in *.tar.gz *.tar.xz; do
    instalar_paquete "$f"
done

# Etapa 3: Instalación de Snort
log "Instalando Snort 3..."
cd "$SOFTWARE_DIR"
tar -xzf snort3.tar.gz
cd snort3*
./configure_cmake.sh --prefix="$INSTALL_DIR"
cd build
make -j"$(nproc)"
make install
ldconfig
success "Snort 3 instalado correctamente."

# Etapa 4: Configuración
log "Copiando ficheros de configuración..."
cp "$CONFIG_DIR/snort.lua" "$INSTALL_DIR/etc/snort/"
cp "$CONFIG_DIR/custom.rules" "$INSTALL_DIR/etc/snort/"
cp "$CONFIG_DIR/blocklist.rules.txt" "$INSTALL_DIR/etc/snort/"

# Adaptar snort.service con la interfaz seleccionada
log "Configurando snort.service para interfaz $IFACE..."
cp "$CONFIG_DIR/snort.service" /etc/systemd/system/snort.service
sed -i "s/-i eth0/-i $IFACE/" /etc/systemd/system/snort.service

# Habilitar el servicio
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable snort.service
systemctl restart snort.service

log "Esperando unos segundos para comprobar el estado del servicio..."
sleep 3
systemctl status snort.service --no-pager

success "Instalación y configuración de Snort 3 completadas exitosamente."
echo -e "${GREEN}Snort está ahora corriendo en la interfaz $IFACE.${NC}"
