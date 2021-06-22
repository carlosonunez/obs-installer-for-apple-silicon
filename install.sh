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
  if ! test -d "$OBS_INSTALL_DIR"
  then
    log_info "Downloading OBS to $OBS_INSTALL_DIR. This might take a while; please be patient."
    if ! git clone --recursive "$OBS_GIT_URI" "$OBS_INSTALL_DIR"
    then
      fail "Unable to download OBS."
    fi
  else
    log_debug "OBS repo already downloaded; skipping."
  fi
}

copy_modified_files_into_cloned_repo() {
  while read -r file
  do
    dest="$OBS_INSTALL_DIR/$(echo "$file" | sed 's#files/##')"
    log_info "Copying [$file] into [$dest]"
    cp "$file" "$dest"
  done < <(find files -type f)
}

copy_templates_into_cloned_repo() {
  _create_folder_for_file_if_not_exist() {
    file="$1"
    dir_to_create="$(dirname "$file")"
    if ! test -d "$dir_to_create"
    then
      log_info "Creating directory [$dir_to_create]"
      mkdir -p "$dir_to_create"
    fi
  }

  while read -r template
  do
    dest="$OBS_INSTALL_DIR/$(echo "$template" | sed 's#template/##')"
    _create_folder_for_file_if_not_exist "$dest"
    log_info "Copying template [$template] into [$dest]"
    cp "$template" "$dest"
  done < <(find template -type f | grep -Ev '(Instructions|DS_Store)')
}

build_obs() {
  pushd "$OBS_INSTALL_DIR"
  if !  cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
      -DDISABLE_PYTHON=ON \
      ..//waitmake//waitcd \
      rundir/RelWithDebInfo/bin
  then
    popd &>/dev/null
    fail "Unable to build OBS; see above logs for more info."
  fi
  popd &>/dev/null
}

if ! homebrew_installed
then
  fail "Homebrew isn't installed. Please install it."
fi

install_dependencies_or_fail
download_obs_or_fail
copy_modified_files_into_cloned_repo
copy_templates_into_cloned_repo
build_obs
