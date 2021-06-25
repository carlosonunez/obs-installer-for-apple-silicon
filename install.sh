#!/usr/bin/env bash
#
# Interested in contributing? Thank you!
# The easiest way to read this is to start from the bottom and work upwards!
#
REMOVE_INSTALLATION_DIRS="${REMOVE_INSTALLATION_DIRS:-true}"
REPACKAGE="${REPACKAGE:-false}"
LOG_LEVEL="${LOG_LEVEL:-info}"
OBS_INSTALL_DIR="/tmp/obs"
OBS_DEPS_DIR="/tmp/obsdeps"
OBS_GIT_URI=https://github.com/obsproject/obs-studio.git
OBS_DEPS_GIT_URI=https://github.com/obsproject/obs-deps.git
OBS_VERSION="${OBS_VERSION:-27.0.1}"
INTERMEDIATE_OBS_DMG_PATH="$OBS_INSTALL_DIR/obs-intermediate.dmg"
FINAL_OBS_DMG_PATH="$HOME/Downloads/obs-$OBS_VERSION-for-m1.dmg"
SPEEX_DIR=/tmp/speexdsp
SPEEX_URI=https://github.com/xiph/speexdsp.git

usage() {
  cat <<-USAGE
[ENV_VARS] $(basename $0) [OPTIONS]
Conveniently builds an M1-compatible OBS from scratch.

ENVIRONMENT VARIABLES

  LOG_LEVEL                   Set the level of logging you see on the console.
                              Options are: info, warning, error, debug, verbose.
                              Verbose logging also turns on shell traces. (Default: info)
  REPACKAGE                   Re-downloads OBS and its dependencies. (Default: false)
  REMOVE_INSTALLATION_DIRS    Removes temporary OBS source code dirs. (Default: true)
  OBS_VERSION                 The version of OBS to build. See NOTES for more
                              information. (Default: 27.0.1)

OPTIONS

  -h, --help                  Shows this documentation.

NOTES

  - You can build OBS from specific version tags, commits, OR branches.
    To do that, define the OBS_VERSION variable before running ./install.sh, like
    this:

    # Download the bleeding edge build
    OBS_VERSION=master ./install.sh

    This feature comes with a few rules:

    - If OBS_VERSION differs from the version that you built last time,
      then OBS and its dependencies will be re-downloaded.
    - This script does not support any OBS version earlier than 27.0.1.
USAGE
}

_log() {
  echo "[$(date)] $(echo "$1" | tr '[:lower:]' '[:upper:]'): $2"
}

_fetch() {
  _write_version_file_if_not_present() {
    file="$1"
    verno="$2"
    if ! test -f "$file"
    then
      log_debug "writing version $verno to $file"
      printf "%s" "$verno" > "$file"
    fi
  }

  _clone_git_repo() {
    dest="$1"
    git_uri="$2"
    name="$3"
    version_file="$4"
    version_number="$5"
    last_version_built=$(cat "$version_file")
    if ! test -d "$dest" || test "$version_number" != "$last_version_built"
    then
      if test "$version_number" != "$last_version_built"
      then
        log_warning "You want version [$version_number] of '$name', but we last built \
version [$last_version_built]. The previous sources will be deleted."
        REMOVE_INSTALLATION_DIRS=true remove_data_directories
      fi
      log_info "Downloading [$name] at version [$version_number] from [$git_uri] to $dest. This might take a while; please be patient."
      if ! git clone --branch "$version_number" --recursive "$git_uri" "$dest"
      then
        fail "Unable to download [$name]."
      fi
    else
      log_debug "[$name] repo already downloaded; skipping."
    fi
  }
  name="$1"
  dest="$2"
  git_uri="$3"
  version_name="$4"
  version_number="$5"
  version_file="/tmp/version_${version_name}"

  _write_version_file_if_not_present "$version_file" "$version_number"
  _clone_git_repo "$dest" "$git_uri" "$name" "$version_file" "$version_number"
}

enable_tracing() {
  if echo "$LOG_LEVEL" | grep -Eiq '^verbose$'
  then
    log_verbose "Enabling shell tracing. I hope you have a huge buffer!"
    set -x
  fi
}

disable_tracing() {
  set +x
  log_verbose "Shell tracing ended."
}

this_is_not_an_m1_mac() {
  log_debug "Linux variant: $(uname); CPU arch: $(uname -p)"
  test "$(uname)" != "Darwin" ||
    ( test "$(uname -p)" != "arm64" && test "$(uname -p)" != "arm" )
}

log_verbose() {
  if echo "$LOG_LEVEL" | grep -Eiq '^verbose$'
  then
    _log "verbose" "$1"
  fi
}

log_debug() {
  if echo "$LOG_LEVEL" | grep -Eiq '^(debug|verbose)$'
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

verify_obs_version_or_fail() {
  _obs_version_is_branch_or_commit_sha() {
    test "$1" == "master" ||
      test "$1" == "main" ||
      ! test -z $(echo "$1" | grep -E '^[0-9]{2}\.[0-9]{1,2}\.[0-9]{1,2}')
  }

  _obs_major_version_greater_than_min_supported_major() {
    MIN_SUPPORTED_OBS_MAJOR_VERSION=27
    obs_major_version="$(echo "$1" | cut -f1 -d '.')"
    test "$obs_major_version" -lt "$MIN_SUPPORTED_OBS_MAJOR_VERSION"
  }

  if _obs_version_is_branch_or_commit_sha "$OBS_VERSION"
  then
    log_debug "OBS version is a branch name or commit SHA: $OBS_VERSION"
    return 0
  fi
  if ! _obs_major_version_greater_than_min_supported_major "$OBS_VERSION"
  then
    fail "You're trying to install OBS version "$1", but only versions \
$MIN_SUPPORTED_OBS_MAJOR_VERSION or greater are supported by this script."
  fi
}

install_dependencies_or_fail() {
  log_info "Installing build dependencies"
  if ! HOMEBREW_NO_AUTO_UPDATE=1 brew install akeru-inc/tap/xcnotary cmake \
    cmocka ffmpeg jack mbedtls qt@5 swig vlc
  then
    fail "Unable to install one or more OBS dependencies. See log above for more details."
  fi
}

download_obs_or_fail() {
  _fetch "OBS" "$OBS_INSTALL_DIR" "$OBS_GIT_URI" "obs" "$OBS_VERSION"
}

download_obs_deps_or_fail() {
  _fetch "OBS Dependencies" "$OBS_DEPS_DIR" "$OBS_DEPS_GIT_URI" "obs_deps" "master"
}

fetch_speexdsp_source() {
  _fetch "SpeexDSP" "$SPEEX_DIR" "$SPEEX_URI" "speex_dsp" "master"
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
    fail "Unable to build OBS; see above logs for more info. \
Try running this instead: REPACKAGE=true ./install.sh"
  fi
  popd &>/dev/null
}

get_obs_studio_dmg_path() {
  2>/dev/null find "$OBS_INSTALL_DIR/cmake" -type f -name *.dmg | \
    grep -E 'obs-studio.*-modified.dmg' | \
    head -1
}

package_obs_or_fail() {
  if test -z "$(get_obs_studio_dmg_path)"
  then
    log_info "Packaging OBS"
    pushd "$OBS_INSTALL_DIR/cmake"
    if ! cpack || test -z "$(get_obs_studio_dmg_path)"
    then
      popd &>/dev/null
      fail "Unable to package OBS; see above logs for more info."
    fi
    popd &>/dev/null
  fi
}

add_virtualcam_plugin() {
  log_info "Adding MacOS Virtual Camera plugin."
  log_debug "OBS dmg path: $(get_obs_studio_dmg_path)"
  if test -f "$INTERMEDIATE_OBS_DMG_PATH"
  then
    rm "$INTERMEDIATE_OBS_DMG_PATH"
  fi
  if ! (
    hdiutil convert -format UDRW -o "$INTERMEDIATE_OBS_DMG_PATH" "$(get_obs_studio_dmg_path)" &&
    hdiutil attach "$INTERMEDIATE_OBS_DMG_PATH"
  )
  then
    fail "Unable to create or attach to writeable OBS image; see logs for more."
  fi
  device=$(hdiutil attach "$INTERMEDIATE_OBS_DMG_PATH" | \
    tail -1 | \
    awk '{print $1}')
  mountpath=$(hdiutil attach "$INTERMEDIATE_OBS_DMG_PATH" | \
    tail -1 | \
    awk '{print $3}')
  cp -r "$OBS_INSTALL_DIR/cmake/rundir/RelWithDebInfo/data/obs-mac-virtualcam.plugin" \
    "$mountpath/OBS.app/Contents/Resources/data"
  hdiutil detach "$device"
}

repackage_obs_or_fail() {
  log_info "Re-packaging OBS with Virtual Camera added."
  hdiutil convert -format UDRO -o "$FINAL_OBS_DMG_PATH" "$INTERMEDIATE_OBS_DMG_PATH"
}

remove_data_directories_if_repackaging() {
  if test "$(echo "$REPACKAGE" | tr '[:upper:]' '[:lower:]')" == "true"
  then
    REMOVE_INSTALLATION_DIRS=true remove_data_directories
  fi
}

remove_data_directories() {
  if test "$REMOVE_INSTALLATION_DIRS" == "true"
  then
    log_info "Removing OBS sources"
    rm -rf "$OBS_INSTALL_DIR" &&
      rm -rf "$OBS_DEPS_DIR" &&
      rm -rf "$SPEEX_DIR"
  else
    log_info "Clean up skipped. You can find OBS sources at $OBS_INSTALL_DIR,
OBS dependencies sources at $OBS_DEPS_DIR, and Speex sources at
$SPEEX_DIR."
  fi
}

if test "$1" == "-h" || test "$1" == "--help"
then
  usage
  exit 0
fi

enable_tracing

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

verify_obs_version_or_fail
remove_data_directories_if_repackaging
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

disable_tracing

log_info "Installation succeeded! Move OBS into your Applications folder in the \
Finder window that pops up."
open "$FINAL_OBS_DMG_PATH"
