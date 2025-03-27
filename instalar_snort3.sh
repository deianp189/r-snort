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

activar_swap_temporal_si_necesario() {
    if free | awk '/^Swap:/ {exit !$2}'; then
        log "Swap ya está activo."
    else
        log "No hay swap activa. Creando archivo de swap temporal (2GB)..."
        falloc_file="/swapfile_snort"
        fallocate -l 2G "$falloc_file" || dd if=/dev/zero of="$falloc_file" bs=1M count=2048
        chmod 600 "$falloc_file"
        mkswap "$falloc_file"
        swapon "$falloc_file"
        log "Swap temporal activada en $falloc_file"
    fi
}

# Etapa 0: Comprobaciones previas
echo "DEBUG: Iniciando script y comprobando usuario..."
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

# Menú de selección para ejecutar solo una parte del script
echo
echo "Selecciona el punto de inicio:"
select START_POINT in \
    "Todo desde el principio" \
    "Solo instalar paquetes comprimidos (DAQ, libdnet, etc.)" \
    "Desde después de OpenSSL (pcre2 en adelante)" \
    "Desde LuaJIT en adelante" \
    "Solo instalar Snort3" \
    "Solo configuración final"; do
    case $REPLY in
        1) START_AT="todo"; break ;;
        2) START_AT="paquetes"; break ;;
        3) START_AT="pcre2"; break ;;
        4) START_AT="luajit"; break ;;
        5) START_AT="snort3"; break ;;
        6) START_AT="config"; break ;;
        *) echo "Opción no válida. Intenta de nuevo." ;;
    esac
done

# Redirigimos salida y errores al archivo de log
exec > >(tee -a "$LOG_FILE") 2>&1

log "Creando directorios necesarios..."
mkdir -p "$INSTALL_DIR"/{bin,etc/snort,lib,include,share,logs,rules}

# Etapa 1: Instalación de dependencias
if [[ "$START_AT" == "todo" ]]; then
    log "Instalando dependencias del sistema..."
    apt-get update
    apt-get install -y \
      build-essential \
      cmake \
      libtool \
      libpcap-dev \
      libpcre3-dev \
      libpcre2-dev \
      libdumbnet-dev \
      bison \
      flex \
      zlib1g-dev \
      pkg-config \
      libhwloc-dev \
      liblzma-dev \
      libssl-dev \
      git \
      wget \
      curl \
      autoconf \
      automake \
      check \
      libnuma-dev \
      uuid-dev \
      libunwind-dev \
      libsafec-dev \
      w3m || log "Algunos paquetes opcionales no se encontraron en esta arquitectura. Continuando..."
fi

# Función para instalar paquetes individuales
instalar_paquete() {
    local archivo="$1"
    log "Instalando $(basename "$archivo")..."
    tar -xf "$archivo"
    local dir="$(tar -tf "$archivo" | head -1 | cut -d/ -f1)"
    cd "$dir"

    case "$archivo" in
    *luajit*)
        make -j"$(nproc)"
        make install PREFIX=/usr
        cd .. && rm -rf "$dir"
        success "LuaJIT instalado correctamente."
        return ;;
    *openssl*)
        local target=$(uname -m | grep -q aarch64 && echo "linux-aarch64" || echo "linux-generic32")
        ./Configure --prefix=/usr --openssldir=/etc/ssl "$target"
        make -j"$(nproc)"
        make install
        cd .. && rm -rf "$dir"
        success "OpenSSL instalado correctamente."
        return ;;
    esac

    if [[ -f "configure.ac" && ! -f "configure" ]]; then
        [[ -f "bootstrap" ]] && chmod +x bootstrap && ./bootstrap || autoreconf -fi
    fi

    if [[ -f "configure" ]]; then
        ./configure --prefix=/usr --enable-shared
    else
        cmake . -DCMAKE_INSTALL_PREFIX=/usr
    fi

    make -j"$(nproc)"
    make install
    cd .. && rm -rf "$dir"
    success "$(basename "$archivo") instalado correctamente."
}

# Etapa 2: Instalación de paquetes comprimidos
if [[ "$START_AT" =~ ^(todo|paquetes|pcre2|luajit)$ ]]; then
    cd "$SOFTWARE_DIR"
    for f in *.tar.gz *.tar.xz; do
        if [[ "$START_AT" == "pcre2" && "$f" != *pcre2* ]]; then continue; fi
        if [[ "$START_AT" == "luajit" && "$f" != *luajit* ]]; then continue; fi
        instalar_paquete "$f"
    done
fi

# Etapa 3: Instalación de Snort 3
if [[ "$START_AT" =~ ^(todo|paquetes|pcre2|luajit|snort3)$ ]]; then
    log "Instalando Snort 3..."
    cd "$SOFTWARE_DIR"
    tar -xzf snort3.tar.gz
    cd "$(find . -maxdepth 1 -type d -name 'snort3*' | head -n 1)"

    # Parche del bug en configure_cmake.sh
    sed -i 's/\[ \"$NUMTHREADS\" -lt \"$MINTHREADS\" \]/[ "${NUMTHREADS:-0}" -lt "${MINTHREADS:-1}" ]/' configure_cmake.sh

    # Forzamos inclusión de libnuma
    export CXXFLAGS="-I/usr/include"
    export LDFLAGS="-lnuma"

    ./configure_cmake.sh --prefix="$INSTALL_DIR"
    cd build

    activar_swap_temporal_si_necesario

    log "Compilando con protección contra OOM..."
    nproc_safe=$(nproc)
    mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if [ "$mem_kb" -lt 1500000 ]; then
        log "Memoria baja. Limitando compilación a un solo hilo."
        nproc_safe=1
    fi

    make -j"$nproc_safe" || error "Fallo en make. Posible error de memoria insuficiente."
    make install
    ldconfig
    success "Snort 3 instalado correctamente."
fi

# Limpieza del swap temporal
if swapon --show | grep -q "/swapfile_snort"; then
    log "Desactivando swap temporal..."
    swapoff /swapfile_snort
    rm -f /swapfile_snort
    success "Swap temporal eliminada."
fi

# Etapa 4: Configuración
if [[ "$START_AT" =~ ^(todo|paquetes|pcre2|luajit|snort3|config)$ ]]; then
    log "Copiando ficheros de configuración..."
    cp "$CONFIG_DIR/snort.lua" "$INSTALL_DIR/etc/snort/"
    cp "$CONFIG_DIR/custom.rules" "$INSTALL_DIR/etc/snort/"
    cp "$CONFIG_DIR/blocklist.rules.txt" "$INSTALL_DIR/etc/snort/"

    log "Configurando snort.service para interfaz $IFACE..."
    cp "$CONFIG_DIR/snort.service" /etc/systemd/system/snort.service
    sed -i "s/-i eth[0-9]\+/-i $IFACE/" /etc/systemd/system/snort.service

    log "Descomprimiendo community rules..."
    mkdir -p "$INSTALL_DIR/etc/snort/rules"
    tar -xzf "$CONFIG_DIR/snort3-community-rules.tar.gz" -C "$INSTALL_DIR/etc/snort/rules" --strip-components=1

    log "Reiniciando servicio snort..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable snort.service
    systemctl restart snort.service

    sleep 3
    systemctl status snort.service --no-pager

    success "Instalación y configuración de Snort 3 completadas exitosamente."
    echo -e "${GREEN}Snort está ahora corriendo en la interfaz $IFACE.${NC}"
fi
