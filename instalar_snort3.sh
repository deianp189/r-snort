#!/bin/bash

###############################################################################
#                           R-SNORT INSTALLER                                 #
###############################################################################
set -euo pipefail

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

ascii_banner() {
cat << 'EOF'
██████╗       ███████╗███╗   ██╗ ██████╗ ██████╗ ████████╗
██╔══██╗      ██╔════╝████╗  ██║██╔═══██╗██╔══██╗╚══██╔══╝
██████╔╝█████╗███████╗██╔██╗ ██║██║   ██║██████╔╝   ██║   
██╔══██╗╚════╝╚════██║██║╚██╗██║██║   ██║██╔══██╗   ██║   
██║  ██║      ███████║██║ ╚████║╚██████╔╝██║  ██║   ██║   
╚═╝  ╚═╝      ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   
Snort 3.7 Installer
EOF
}

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

###############################################################################
#                    Swap condicional según la memoria RAM                    #
###############################################################################
activar_swap_temporal_si_necesario() {
  local mem_kb
  mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  
  # Solo activa swap si hay menos de ~1.5 GB de RAM
  if [ "$mem_kb" -lt 1500000 ]; then
    if free | awk '/^Swap:/ {exit !$2}'; then
      log "Swap detectada y activa, no se creará otra."
    else
      log "Poca RAM (<1.5 GB). Creando swap temporal (2GB)."
      local falloc_file="/swapfile_snort"
      fallocate -l 2G "$falloc_file" || dd if=/dev/zero of="$falloc_file" bs=1M count=2048
      chmod 600 "$falloc_file"
      mkswap "$falloc_file"
      swapon "$falloc_file"
      log "Swap temporal creada en: $falloc_file"
    fi
  else
    log "≥1.5GB RAM detectada: no se crea swap."
  fi
}

###############################################################################
#                              Comprobaciones previas                          #
###############################################################################
if [ "$(id -u)" -ne 0 ]; then
  error "Este script debe ejecutarse como root."
fi

ascii_banner

echo
log "Bienvenido a la instalación de R-SNORT."

log "Detectando interfaces de red disponibles..."

# Obtener interfaces excluyendo 'lo'
mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

if [ "${#interfaces[@]}" -eq 0 ]; then
  error "No se encontraron interfaces de red válidas."
fi

echo "Seleccione una interfaz de red:"
for i in "${!interfaces[@]}"; do
  echo "  [$i] ${interfaces[$i]}"
done

read -rp "Introduce el número correspondiente a la interfaz: " selected_index

# Validación de entrada
if ! [[ "$selected_index" =~ ^[0-9]+$ ]]; then
  error "Entrada inválida. Debe ser un número."
fi

if (( selected_index < 0 || selected_index >= ${#interfaces[@]} )); then
  error "Número fuera de rango. Selección no válida."
fi

IFACE="${interfaces[$selected_index]}"
log "Se usará la interfaz: $IFACE"

###############################################################################
#                          Variables y archivos base                           #
###############################################################################
CONFIG_DIR="$(pwd)/configuracion"
SOFTWARE_DIR="$(pwd)/software"
INSTALL_DIR="/usr/local/snort"
LOG_FILE="/var/log/snort_install.log"

log "Creando rutas base en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"/{bin,etc/snort,lib,include,share,logs,rules}

# Redirige salida a un archivo de log
exec > >(tee -a "$LOG_FILE") 2>&1

###############################################################################
#               Etapa 1: Instalar dependencias del sistema (apt)              #
###############################################################################
log "Instalando dependencias básicas y opcionales..."
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
  w3m || log "Algunas dependencias opcionales no se encontraron en esta arquitectura. Continuando..."

success "Dependencias de sistema instaladas."

###############################################################################
#          Función instalar_paquete(): para cada tar.gz que encuentres        #
###############################################################################
instalar_paquete() {
  local archivo="$1"
  log "Instalando: $(basename "$archivo")"
  tar -xf "$archivo"
  local dir
  dir="$(tar -tf "$archivo" | head -1 | cut -d/ -f1)"
  cd "$dir"

  case "$archivo" in
    *luajit*)
      make -j"$(nproc)"
      make install PREFIX=/usr
      cd ..
      rm -rf "$dir"
      success "LuaJIT instalado."
      return
      ;;
    *openssl*)
      local target
      if uname -m | grep -q aarch64; then
        target="linux-aarch64"
      else
        target="linux-generic32"
      fi
      ./Configure --prefix=/usr --openssldir=/etc/ssl "$target"
      make -j"$(nproc)"
      make install
      cd ..
      rm -rf "$dir"
      success "OpenSSL instalado."
      return
      ;;
  esac

  # Manejo bootstrap/configure/cmake
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

  cd ..
  rm -rf "$dir"
  success "$(basename "$archivo") instalado."
}

###############################################################################
#          Etapa 2: Instala todos los .tar.* en la carpeta 'software'         #
###############################################################################
log "Instalando paquetes comprimidos..."
cd "$SOFTWARE_DIR"
for f in *.tar.gz *.tar.xz; do
  instalar_paquete "$f"
done

###############################################################################
#            Etapa 3: Instalar Snort 3 Principal                              #
###############################################################################
log "Preparando instalación de Snort 3..."
tar -xzf snort3.tar.gz
cd "$(find . -maxdepth 1 -type d -name 'snort3*' | head -n 1)"

# Corrige bug de threads en configure_cmake.sh
sed -i 's/\[ \"\$NUMTHREADS\" -lt \"\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh

./configure_cmake.sh --prefix="$INSTALL_DIR"

cd build
activar_swap_temporal_si_necesario

log "Compilando Snort 3. Puede tardar un rato..."
make -j"$(nproc)" || error "Fallo en make al compilar Snort 3."
make install
ldconfig

# Crea symlink para poder ejecutar 'snort' sin ruta completa
ln -sf /usr/local/snort/bin/snort /usr/local/bin/snort

success "Snort 3 instalado con éxito."

###############################################################################
#                    Limpieza del swap si se creó temporal                    #
###############################################################################
if swapon --show | grep -q "/swapfile_snort"; then
  log "Desactivando swap temporal..."
  swapoff /swapfile_snort
  rm -f /swapfile_snort
  success "Swap temporal eliminada."
fi

###############################################################################
#                 Etapa 4: Configuración final de Snort 3                     #
###############################################################################
log "Copiando archivos de configuración finales..."
cp "$CONFIG_DIR/snort.lua" "$INSTALL_DIR/etc/snort/"
cp "$CONFIG_DIR/custom.rules" "$INSTALL_DIR/etc/snort/"

# Asegura directorios y archivos
log "Creando reputación y community rules..."
mkdir -p "$INSTALL_DIR/etc/snort/reputation"
mkdir -p "$INSTALL_DIR/etc/snort/snort3-community-rules"
touch "$INSTALL_DIR/etc/snort/reputation/interface.info"

log "Descomprimiendo community rules en la carpeta esperada..."
tar -xzf "$CONFIG_DIR/snort3-community-rules.tar.gz" -C "$INSTALL_DIR/etc/snort/snort3-community-rules" --strip-components=1

# Genera el servicio systemd dinámicamente
log "Creando servicio systemd para interfaz $IFACE"
cat > /etc/systemd/system/snort.service <<EOF
[Unit]
Description=Snort NIDS Daemon
After=network.target

[Service]
ExecStart=$INSTALL_DIR/bin/snort -c $INSTALL_DIR/etc/snort/snort.lua -i $IFACE -A alert_fast
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
User=root
Group=root
LimitCORE=infinity
LimitNOFILE=65536
LimitNPROC=65536
PIDFile=/var/run/snort.pid

[Install]
WantedBy=multi-user.target
EOF

log "Activando e iniciando servicio Snort..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable snort.service
systemctl restart snort.service || error "No se pudo iniciar el servicio Snort."
sleep 2
systemctl status snort.service --no-pager

success "Snort 3 instalado y configurado completamente."
echo -e "${GREEN}Snort 3 está en ejecución en la interfaz: ${IFACE}.${NC}"