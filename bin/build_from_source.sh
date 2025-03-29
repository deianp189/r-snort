#!/bin/bash

package_install() {
  local archivo="$1"

  # Validar integridad antes de intentar descomprimir
  if [[ "$archivo" == *.tar.gz ]]; then
    gzip -t "$archivo" || error "Archivo corrupto (gzip): $archivo"

  elif [[ "$archivo" == *.tar.xz ]]; then
    if ! command -v xz >/dev/null 2>&1; then
      log "Instalando xz-utils..."
      apt-get update && apt-get install -y xz-utils liblzma-dev || error "No se pudo instalar xz-utils"
    fi

    # Detectar fallo por incompatibilidad de versión de liblzma
    if ! xz -t "$archivo" 2>&1 | grep -qv 'version `XZ_'; then
      log "Corrigiendo incompatibilidad de xz/liblzma..."
      apt-get install --reinstall -y xz-utils liblzma-dev || error "No se pudo reinstalar xz/liblzma"
    fi

    xz -t "$archivo" || error "Archivo corrupto (xz): $archivo"
  fi

  log "Instalando: $(basename "$archivo")"
  tar -xf "$archivo"
  dir=$(find . -mindepth 1 -maxdepth 1 -type d | grep -v '^./\.' | head -n 1)

  if [[ -z "$dir" || ! -d "$dir" ]]; then
    error "No se encontró un directorio válido tras descomprimir $archivo"
  fi

  log "Entrando en directorio: $dir"
  cd "$dir"

  case "$archivo" in
    *luajit*)
      make -j"$(nproc)"
      make install PREFIX=/usr
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
      ;;

    *daq*)
      log "Instalando DAQ con precauciones (desactivando 'set -e' temporalmente)..."
      set +e
      if [[ -f "bootstrap" ]]; then
        chmod +x bootstrap
        ./bootstrap
        bootstrap_status=$?
      else
        bootstrap_status=1
      fi
      if [[ $bootstrap_status -ne 0 && -f "configure.ac" && ! -f "configure" ]]; then
        autoreconf -fi
      fi
      set -e
      ./configure --prefix=/usr --enable-shared
      make -j"$(nproc)"
      make install || error "Fallo al instalar DAQ"
      ;;

    *)
      if [[ -f "configure.ac" && ! -f "configure" ]]; then
        [[ -f "bootstrap" ]] && chmod +x bootstrap && ./bootstrap || autoreconf -fi
      fi
      if [[ -f "configure" ]]; then
        ./configure --prefix=/usr --enable-shared
      else
        cmake . -DCMAKE_INSTALL_PREFIX=/usr
      fi
      make -j"$(nproc)"
      make install || error "Fallo al instalar $(basename "$archivo")"
      ;;
  esac

  cd ..
  rm -rf "$dir"
  success "$(basename "$archivo") instalado."
}

software_package_install() {
  cd "$SOFTWARE_DIR"
  log "Ordenando paquetes para instalación de dependencias primero..."
  for f in $(ls *.tar.gz *.tar.xz 2>/dev/null | sort | grep -vi snort); do
    package_install "$f"
  done
  log "Snort se instalará en una fase posterior. Omitido aquí."

  log "Instalando ClamAV para protección antivirus..."
  apt-get install -y clamav clamav-daemon || error "No se pudo instalar ClamAV"
  freshclam || log "No se pudo actualizar la base de firmas en este momento"
  systemctl enable clamav-freshclam
  systemctl enable clamav-daemon
  systemctl restart clamav-daemon
  systemctl is-active --quiet clamav-daemon && success "ClamAV está activo." || log "ClamAV instalado pero no activo."
}
