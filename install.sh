#!/usr/bin/env bash
#
# Interested in contributing? Thank you!
# The easiest way to read this is to start from the bottom and work upwards!
#
REMOVE_INSTALLATION_DIRS="${REMOVE_INSTALLATION_DIRS:-true}"
LOG_LEVEL="${LOG_LEVEL:-info}"
OBS_INSTALL_DIR="/tmp/obs"
OBS_DEPS_DIR="/tmp/obsdeps"
OBS_GIT_URI=https://github.com/obsproject/obs-studio.git
OBS_DEPS_GIT_URI=https://github.com/obsproject/obs-deps.git
OBS_DMG_PATH=obs-studio-x64-27.0.1-2-g3cc4feb8d-modified.dmg
FINAL_OBS_DMG_PATH="$HOME/Downloads/$OBS_DMG_PATH"
SPEEX_DIR=/tmp/speexdsp
SPEEX_URI=https://github.com/xiph/speexdsp.git

_log() {
  echo "[$(date)] $(echo "$1" | tr '[:lower:]' '[:upper:]'): $2"
}

_fetch() {
  name="$1"
  dest="$2"
  git_uri="$3"
  if ! test -d "$dest"
  then
    log_info "Downloading [$name] from [$git_uri] to $dest. This might take a while; please be patient."
    if ! git clone --recursive "$git_uri" "$dest"
    then
      fail "Unable to download [$name]."
    fi
  else
    log_debug "[$name] repo already downloaded; skipping."
  fi
}

this_is_not_an_m1_mac() {
  test "$(uname)" != "Darwin" || test "$(uname -p)" != "arm64"
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
  _fetch "OBS" "$OBS_INSTALL_DIR" "$OBS_GIT_URI"
}

download_obs_deps_or_fail() {
  _fetch "OBS Dependencies" "$OBS_DEPS_DIR" "$OBS_DEPS_GIT_URI"
}

fetch_speexdsp_source() {
  _fetch "SpeexDSP" "$SPEEX_DIR" "$SPEEX_URI"
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

build_obs_or_fail() {
  pushd "$OBS_INSTALL_DIR/cmake"
  if ! (
    cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 -DDISABLE_PYTHON=ON \
      -DCMAKE_PREFIX_PATH="/opt/homebrew/opt/qt@5" \
      -DSPEEXDSP_INCLUDE_DIR="$SPEEX_DIR/include" \
      -DSWIGDIR="$OBS_DEPS_DIR" \
      -DDepsPath="$OBS_DEPS_DIR" .. &&
    make &&
    stat rundir/RelWithDebInfo/bin/obs 1>/dev/null
  )
  then
    popd &>/dev/null
    fail "Unable to build OBS; see above logs for more info."
  fi
  popd &>/dev/null
}

package_obs_or_fail() {
  if ! test -f "$OBS_INSTALL_DIR/cmake/$OBS_DMG_PATH"
  then
    log_info "Packaging OBS"
    pushd "$OBS_INSTALL_DIR/cmake"
    if ! ( cpack && test -f "$OBS_INSTALL_DIR/cmake/$OBS_DMG_PATH" )
    then
      popd &>/dev/null
      fail "Unable to package OBS; see above logs for more info."
    fi
    popd &>/dev/null
  fi
}

add_virtualcam_plugin() {
  log_info "Adding MacOS Virtual Camera plugin."
  if test -f "$OBS_INSTALL_DIR/obs.dmg"
  then
    rm "$OBS_INSTALL_DIR/obs.dmg"
  fi
  if ! (
    hdiutil convert -format UDRW -o "$OBS_INSTALL_DIR/obs.dmg" \
      "$OBS_INSTALL_DIR/cmake/$OBS_DMG_PATH" &&
    hdiutil attach "$OBS_INSTALL_DIR/obs.dmg"
  )
  then
    fail "Unable to create or attach to writeable OBS image; see logs for more."
  fi
  device=$(hdiutil attach "$OBS_INSTALL_DIR/obs.dmg" | \
    tail -1 | \
    awk '{print $1}')
  mountpath=$(hdiutil attach "$OBS_INSTALL_DIR/obs.dmg" | \
    tail -1 | \
    awk '{print $3}')
  cp -r "$OBS_INSTALL_DIR/cmake/rundir/RelWithDebInfo/data/obs-mac-virtualcam.plugin" \
    "$mountpath/OBS.app/Contents/Resources/data"
  hdiutil detach "$device"
}

repackage_obs_or_fail() {
  log_info "Re-packaging OBS with Virtual Camera added."
  hdiutil convert -format UDRO -o "$FINAL_OBS_DMG_PATH" "$OBS_INSTALL_DIR/obs.dmg"
}

remove_data_directories() {
  if test "$REMOVE_INSTALLATION_DIRS" == "true"
  then
    log_info "Cleaning up"
    rm -rf "$OBS_INSTALL_DIR" &&
      rm -rf "$OBS_DEPS_DIR" &&
      rm -rf "$SPEEX_DIR"
  else
    log_info "Clean up skipped. You can find OBS sources at $OBS_INSTALL_DIR,
OBS dependencies sources at $OBS_DEPS_DIR, and Speex sources at
$SPEEX_DIR."
  fi
}

if this_is_not_an_m1_mac
then
  fail "This installer only works on Apple M1 Macs. \
For OBS 26.x, use Homebrew: 'brew install obs'. \
For OBS 27.x, build OBS from source using the mainstream instructions"
fi

if ! homebrew_installed
then
  fail "Homebrew isn't installed. Please install it."
fi

install_dependencies_or_fail
download_obs_or_fail
download_obs_deps_or_fail
copy_modified_files_into_cloned_repo
copy_templates_into_cloned_repo
fetch_speexdsp_source
build_obs_or_fail
package_obs_or_fail
add_virtualcam_plugin
repackage_obs_or_fail
remove_data_directories

log_info "Installation succeeded! Move OBS into your Applications folder in the \
Finder window that pops up."
open "$FINAL_OBS_DMG_PATH"
