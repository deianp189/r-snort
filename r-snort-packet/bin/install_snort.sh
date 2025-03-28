#!/bin/bash

instalar_snort() {
  local SOFTWARE_DIR="$1"
  local INSTALL_DIR="$2"
  local EXTRA_FLAGS="$3"

  log "Preparando instalación de Snort 3..."

  cd "$SOFTWARE_DIR"
  tar -xzf snort3.tar.gz
  cd "$(find . -maxdepth 1 -type d -name 'snort3*' | head -n 1)"

  # 🔥 Parcheo crítico: desactiva llamadas directas a NUMA desde el código fuente
  log "Parcheando código fuente de NUMA (numa_available, numa_max_node)..."
  sed -i 's/numa_available()/0 \/\/ desactivado manualmente/g' src/main/numa.h
  sed -i 's/numa_max_node()/0 \/\/ desactivado manualmente/g' src/main/numa.h

  # Parchea la configuración para evitar intentar usar NUMA desde CMake
  sed -i 's/--enable-numa/--disable-numa/g' configure_cmake.sh
  sed -i 's/NUMA=ON/NUMA=OFF/' CMakeLists.txt 2>/dev/null || true
  sed -i 's/find_package(NUMA REQUIRED)/#find_package(NUMA REQUIRED)/' CMakeLists.txt 2>/dev/null || true

  # Corrige bug de hilos si es necesario
  sed -i 's/\[ \"\\$NUMTHREADS\" -lt \"\\$MINTHREADS\" \]/[ \"${NUMTHREADS:-0}\" -lt \"${MINTHREADS:-1}\" ]/' configure_cmake.sh

  # Limpia flags para evitar arrastrar -lnuma
  unset LDFLAGS
  unset CXXFLAGS
  export LDFLAGS=""
  export CXXFLAGS=""

  # Ejecuta el script de configuración de Snort sin NUMA
  export CXXFLAGS="-Wno-deprecated-declarations"
  ./configure_cmake.sh --prefix="$INSTALL_DIR" --disable-numa

  cd build
  activar_swap_temporal_si_necesario

  log "Compilando Snort 3. Puede tardar un rato..."
  make -j"$(nproc)" || error "Fallo en make al compilar Snort 3."
  make install
  ldconfig

  # Crea symlink para 'snort'
  ln -sf "$INSTALL_DIR/bin/snort" /usr/local/bin/snort

  success "Snort 3 instalado con éxito."
}
