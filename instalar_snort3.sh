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

echo "DEBUG: CONFIG_DIR=$CONFIG_DIR"
echo "DEBUG: SOFTWARE_DIR=$SOFTWARE_DIR"
echo "DEBUG: INSTALL_DIR=$INSTALL_DIR"
echo "DEBUG: LOG_FILE=$LOG_FILE"

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

echo "DEBUG: Has seleccionado: $START_AT"

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
      libnuma-dev
fi

# Función para instalar cada paquete (DAQ, libdnet, etc.)
instalar_paquete() {
    local archivo="$1"
    log "Instalando $(basename "$archivo")..."
    echo "DEBUG: Empezando función instalar_paquete con '$archivo'"

    echo "DEBUG: Descomprimiendo '$archivo' en $(pwd)"
    tar -xf "$archivo"
    echo "DEBUG: Completada la descompresión de '$archivo'"

    echo "DEBUG: Voy a listar el contenido de $archivo con 'tar -tf':"
    tar -tf "$archivo" || echo "DEBUG: 'tar -tf' devolvió error $?"
    set +e
    echo "DEBUG: Voy a capturar la primera línea con head/cut:"
    local dir
    dir="$(tar -tf "$archivo" | head -1 | cut -d/ -f1)"
    echo "DEBUG: Directorio detectado tras descompresión: '$dir'"
    set -e

    cd "$dir"
    echo "DEBUG: Ahora en $(pwd)"

    case "$archivo" in
    *luajit*)
        echo "DEBUG: Instalación especial para LuaJIT"
        make -j"$(nproc)"
        make install PREFIX=/usr
        cd ..
        rm -rf "$dir"
        success "LuaJIT instalado correctamente."
        return
        ;;
    *openssl*)
        echo "DEBUG: Instalación especial para OpenSSL"
        arch=$(uname -m)
        if [[ "$arch" == "aarch64" ]]; then
            target="linux-aarch64"
        else
            target="linux-generic32"
        fi
        ./Configure --prefix=/usr --openssldir=/etc/ssl "$target"

        make -j"$(nproc)"
        make install
        cd ..
        rm -rf "$dir"
        success "OpenSSL instalado correctamente."
        return
        ;;
    esac



    # 3. Si tenemos configure.ac y no existe configure,
    #    generamos configure con bootstrap/autoreconf
    if [[ -f "configure.ac" && ! -f "configure" ]]; then
        echo "DEBUG: Se encontró configure.ac pero no configure. Intentando generar configure..."
        if [[ -f "bootstrap" ]]; then
            echo "DEBUG: bootstrap encontrado. Otorgando permiso de ejecución..."
            chmod +x bootstrap
            echo "DEBUG: Ejecutando ./bootstrap..."
            ./bootstrap
            echo "DEBUG: Finalizó bootstrap"
        else
            echo "DEBUG: No existe bootstrap, probando autoreconf -fi..."
            autoreconf -fi
            echo "DEBUG: Finalizado autoreconf"
        fi
    else
        echo "DEBUG: No hace falta bootstrap/autoreconf. O ya existe configure o no hay configure.ac."
    fi

    # 4. Ahora comprobamos si se ha generado configure
    if [[ -f "configure" ]]; then
        echo "DEBUG: 'configure' existe, lanzando ./configure --prefix=/usr --enable-shared"
        ./configure --prefix=/usr --enable-shared
        echo "DEBUG: Finalizó ./configure"

        echo "DEBUG: Ejecutando make -j$(nproc)"
        make -j"$(nproc)"
        echo "DEBUG: Finalizó make"

        echo "DEBUG: Ejecutando make install"
        make install
        echo "DEBUG: Finalizó make install"
    else
        echo "DEBUG: 'configure' NO existe, intentamos CMake..."
        cmake . -DCMAKE_INSTALL_PREFIX=/usr
        echo "DEBUG: Finalizó cmake"

        echo "DEBUG: Ejecutando make -j$(nproc)"
        make -j"$(nproc)"
        echo "DEBUG: Finalizó make"

        echo "DEBUG: Ejecutando make install"
        make install
        echo "DEBUG: Finalizó make install"
    fi

    # 6. Volvemos al directorio software y limpiamos
    echo "DEBUG: Limpiando carpeta extraída. Saliendo de $(pwd)"
    cd ..
    rm -rf "$dir"
    success "$(basename "$archivo") instalado correctamente."
    echo "DEBUG: Terminada función instalar_paquete para '$archivo'"
}

# Etapa 2: Descompresión e instalación de cada componente
if [[ "$START_AT" == "todo" || "$START_AT" == "paquetes" || "$START_AT" == "pcre2" || "$START_AT" == "luajit" ]]; then
    cd "$SOFTWARE_DIR"
    echo "DEBUG: Iniciando bucle de instalación de cada paquete en $(pwd)"
    SKIP=0
    for f in *.tar.gz *.tar.xz; do
        if [[ "$START_AT" == "pcre2" && "$SKIP" -eq 0 && "$f" != *pcre2* ]]; then
            continue
        fi
        if [[ "$START_AT" == "luajit" && "$SKIP" -eq 0 && "$f" != *luajit* ]]; then
            continue
        fi
        SKIP=1
        echo "DEBUG: Llamando a instalar_paquete con '$f'"
        instalar_paquete "$f"
        echo "DEBUG: Finalizado instalar_paquete para '$f'"
    done
fi

# Etapa 3: Instalación de Snort
if [[ "$START_AT" == "todo" || "$START_AT" == "paquetes" || "$START_AT" == "pcre2" || "$START_AT" == "luajit" || "$START_AT" == "snort3" ]]; then
    log "Instalando Snort 3..."
    echo "DEBUG: Vamos a extraer 'snort3.tar.gz'"
    cd "$SOFTWARE_DIR"
    tar -xzf snort3.tar.gz
    echo "DEBUG: Hecho tar -xzf snort3.tar.gz"

    echo "DEBUG: Buscando carpeta snort3*..."
    cd snort3*
    echo "DEBUG: Ahora en $(pwd), lanzamos ./configure_cmake.sh --prefix=$INSTALL_DIR"
    ./configure_cmake.sh --prefix="$INSTALL_DIR"
    echo "DEBUG: Finalizado configure_cmake.sh, ahora cd build..."

    cd build
    echo "DEBUG: En $(pwd), lanzamos make -j$(nproc)"
    make -j"$(nproc)"
    echo "DEBUG: Finalizó make, lanzamos make install"
    make install
    ldconfig
    success "Snort 3 instalado correctamente."
fi

# Etapa 4: Configuración
if [[ "$START_AT" == "todo" || "$START_AT" == "paquetes" || "$START_AT" == "pcre2" || "$START_AT" == "luajit" || "$START_AT" == "snort3" || "$START_AT" == "config" ]]; then
    log "Copiando ficheros de configuración..."
    cp "$CONFIG_DIR/snort.lua" "$INSTALL_DIR/etc/snort/"
    cp "$CONFIG_DIR/custom.rules" "$INSTALL_DIR/etc/snort/"
    cp "$CONFIG_DIR/blocklist.rules.txt" "$INSTALL_DIR/etc/snort/"

    log "Configurando snort.service para interfaz $IFACE..."
    cp "$CONFIG_DIR/snort.service" /etc/systemd/system/snort.service
    sed -i "s/-i eth0/-i $IFACE/" /etc/systemd/system/snort.service

    log "Descomprimiendo community rules..."
    mkdir -p "$INSTALL_DIR/etc/snort/rules"
    tar -xzf "$CONFIG_DIR/snort3-community-rules.tar.gz" -C "$INSTALL_DIR/etc/snort/rules" --strip-components=1

    log "Reiniciando servicio snort..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable snort.service
    systemctl restart snort.service

    log "Esperando unos segundos para comprobar el estado del servicio..."
    sleep 3
    systemctl status snort.service --no-pager

    success "Instalación y configuración de Snort 3 completadas exitosamente."
    echo -e "${GREEN}Snort está ahora corriendo en la interfaz $IFACE.${NC}"
fi
