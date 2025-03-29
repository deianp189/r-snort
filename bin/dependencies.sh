#!/bin/bash

dependencies_install() {
  log "Instalando dependencias..."
  apt-get update
  apt-get install -y \
    build-essential cmake libtool libpcap-dev libpcre3-dev \
    libpcre2-dev libdumbnet-dev bison flex zlib1g-dev pkg-config \
    libhwloc-dev liblzma-dev libssl-dev git wget curl autoconf \
    automake check libnuma-dev uuid-dev libunwind-dev libsafec-dev w3m \
    || log "Algunas dependencias opcionales no disponibles."
  success "Dependencias instaladas."
}