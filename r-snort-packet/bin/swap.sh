#!/bin/bash
instalar_paquete() {
  local archivo="$1"

  # Validar integridad antes de intentar descomprimir
  if [[ "$archivo" == *.tar.gz ]]; then
    gzip -t "$archivo" || error "Archivo corrupto (gzip): $archivo"
  elif [[ "$archivo" == *.tar.xz ]]; then
    xz -t "$archivo" || error "Archivo corrupto (xz): $archivo"
  fi

  log "Instalando: $(basename "$archivo")"
  tar -xf "$archivo"
  #tar -xf "$archivo"
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
      cd ..
      rm -rf "$dir"
      success "LuaJIT instalado."
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
      ;;

    *daq*)
      log "Instalando DAQ con precauciones (desactivando 'set -e' temporalmente)..."

      set +e  # Desactivar terminación por error
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
      set -e  # Rehabilitar 'set -e' tras preparación

      ./configure --prefix=/usr --enable-shared
      make -j"$(nproc)"
      make install || error "Fallo al instalar DAQ"

      cd ..
      rm -rf "$dir"
      success "DAQ instalado."
      ;;

    *)
      # Fallback general: bootstrap/autoreconf/configure/cmake
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

      cd ..
      rm -rf "$dir"
      success "$(basename "$archivo") instalado."
      ;;
  esac
}

instalar_paquetes_software() {
  cd "$SOFTWARE_DIR"
  for f in *.tar.gz *.tar.xz; do
    instalar_paquete "$f"
  done
}
