#!/usr/bin/env bash
LOG_LEVEL="${LOG_LEVEL:-info}"
OBS_INSTALL_DIR="/tmp/obs"
OBS_GIT_URI=https://github.com/obsproject/obs-studio.git

_log() {
  echo "[$(date)] $(echo "$1" | tr '[:lower:]' '[:upper:]'): $2"
}

log_debug() {
  if test "$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" == "debug" || \
    test "$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" == "verbose"
  then
    _log "debug" "$1"
  fi
}

log_info() {
  _log "info" "$1"
}

log_warning() {
  _log "info" "$1"
}

log_error() {
  _log "error" "$1"
}

log_fatal() {
  _log "fatal" "$1"
}

fail() {
  log_fatal "$1"
  exit 1
}

homebrew_installed() {
  log_debug "Checking for Homebrew"
  which brew &>/dev/null
}

install_dependencies_or_fail() {
  log_info "Installing build dependencies"
  if ! brew install akeru-inc/tap/xcnotary cmake cmocka ffmpeg jack mbedtls qt@5 swig vlc
  then
    fail "Unable to install one or more OBS dependencies. See log above for more details."
  fi
}

download_obs_or_fail() {
  log_info "Downloading OBS to $OBS_INSTALL_DIR. This might take a while; please be patient."
  if ! git clone --recursive "$OBS_GIT_URI" "$OBS_INSTALL_DIR"
  then
    fail "Unable to download OBS."
  fi
}

if ! homebrew_installed
then
  fail "Homebrew isn't installed. Please install it."
fi

install_dependencies_or_fail
download_obs_or_fail
