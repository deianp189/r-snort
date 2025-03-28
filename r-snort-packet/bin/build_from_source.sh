#!/bin/bash

instalar_paquete() {
  local archivo="$1"

  if [[ "$archivo" == *.tar.gz ]]; then
    gzip -t "$archivo" || error "Archivo corrupto (gzip): $archivo"
  elif [[ "$archivo" == *.tar.xz ]]; then
    xz -t "$archivo" || error "Archivo corrupto (xz): $archivo"
  fi

  log "Instalando: $(basename "$archivo")"
  tar -xf "$archivo"
  local dir
  dir="$(tar -tf "$archivo" | head -1 | cut -d/ -f1)"
  cd "$dir"

  case "$archivo" in
    *luajit*)
      make -j"$(nproc)"; make install PREFIX=/usr
      cd ..; rm -rf "$dir"; success "LuaJIT instalado."; return;;
    *openssl*)
      local target
      uname -m | grep -q aarch64 && target="linux-aarch64" || target="linux-generic32"
      ./Configure --prefix=/usr --openssldir=/etc/ssl "$target"
      make -j"$(nproc)"; make install
      cd ..; rm -rf "$dir"; success "OpenSSL instalado."; return;;
  esac

  [[ -f "configure.ac" && ! -f "configure" ]] && ([[ -f "bootstrap" ]] && chmod +x bootstrap && ./bootstrap || autoreconf -fi)
  [[ -f "configure" ]] && ./configure --prefix=/usr --enable-shared || cmake . -DCMAKE_INSTALL_PREFIX=/usr

  make -j"$(nproc)"
  make install
  cd ..; rm -rf "$dir"
  success "$(basename "$archivo") instalado."
}

instalar_paquetes_software() {
  cd "$SOFTWARE_DIR"
  for f in *.tar.gz *.tar.xz; do
    instalar_paquete "$f"
  done
}