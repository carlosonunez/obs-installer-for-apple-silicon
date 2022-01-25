#!/usr/bin/env bash
#
# Interested in contributing? Thank you!
# The easiest way to read this is to start from the bottom and work upwards!
#
REMOVE_INSTALLATION_DIRS="${REMOVE_INSTALLATION_DIRS:-true}"
USE_EXPERIMENTAL_UNIVERSAL_BUILD="${USE_EXPERIMENTAL_UNIVERSAL_BUILD:-false}"
REPACKAGE="${REPACKAGE:-false}"
LOG_LEVEL="${LOG_LEVEL:-info}"
OBS_INSTALL_DIR="/tmp/obs"
OBS_DEPS_DIR="/tmp/obsdeps"
OBS_DEPS_URL=https://github.com/obsproject/obs-deps/releases/download/2022-01-01/macos-deps-2022-01-01-arm64.tar.xz
OBS_GH_ACTIONS_RUNS_URI="repos/obsproject/obs-studio/actions/runs?branch=universal-build&actor=PatTheMav'"
OBS_GIT_URI=https://github.com/obsproject/obs-studio.git
OBS_VERSION="${OBS_VERSION:-27.1.3}"
VLC_VERSION=3.0.8
VLC_URL="https://downloads.videolan.org/vlc/${VLC_VERSION}/vlc-${VLC_VERSION}.tar.xz"
VLC_DIR=/tmp/vlc-obs
CEF_URL="https://cef-builds.spotifycdn.com/cef_binary_94.4.5%2Bg0fd0d6f%2Bchromium-94.0.4606.71_macosarm64.tar.bz2"
CEF_DIR=/tmp/cef-obs
CEF_FOLDER_NAME=cef_binary_94.4.5+g0fd0d6f+chromium-94.0.4606.71_macosarm64
SPEEX_DIR=/tmp/speexdsp
SPEEX_URI=https://github.com/xiph/speexdsp.git
DYLIBBUNDLER_URI=https://github.com/obsproject/obs-studio/raw/master/CI/scripts/macos/app/dylibbundler
DYLIBBUNDLER_PATH="/tmp/dylibbundler"
FINAL_APP_PATH="$HOME/Downloads/OBS.app"
BUNDLE_PLUGINS=(
  coreaudio-encoder.so
  decklink-ouput-ui.so
  decklink-captions.so
  frontend-tools.so
  image-source.so
  mac-avcapture.so
  mac-capture.so
  mac-decklink.so
  mac-syphon.so
  mac-vth264.so
  mac-virtualcam.so
  obs-ffmpeg.so
  obs-filters.so
  obs-transitions.so
  obs-vst.so
  rtmp-services.so
  obs-x264.so
  text-freetype2.so
  obs-outputs.so
)

usage() {
  cat <<-USAGE
[ENV_VARS] $(basename "$0") [OPTIONS]
Conveniently builds an M1-compatible OBS from scratch.

ENVIRONMENT VARIABLES

  LOG_LEVEL                             Set the level of logging you see on the console.
                                        Options are: info, warning, error,
                                        debug, verbose.
                                        Verbose logging also turns on shell traces.
                                        (Default: info)
  REPACKAGE                             Re-downloads OBS and its dependencies.
                                        (Default: false)
  REMOVE_INSTALLATION_DIRS              Removes temporary OBS source code dirs.
                                        (Default: true)
  OBS_VERSION                           The version of OBS to build. See NOTES
                                        for more information. (Default: $OBS_VERSION)
  USE_EXPERIMENTAL_UNIVERSAL_BUILD      Use the experimental multi-branch build
                                        of OBS; see notes for more.
                                        (Default: false)
  GH_CLIENT_ID                          The client ID for your GitHub app; see
                                        NOTES for more information.
                                        Required if USE_EXPERIMENTAL_UNIVERSAL_BUILD
                                        is true.
  GH_CLIENT_SECRET                      The client secret for your GitHub app; see
                                        NOTES for more information.
                                        Required if USE_EXPERIMENTAL_UNIVERSAL_BUILD
                                        is true.

OPTIONS

  -h, --help                  Shows this documentation.

NOTES

  - THIS WILL DELETE YOUR EXISTING INSTALLATION OF OBS!

  - You can build OBS from specific version tags, commits, OR branches.
    To do that, define the OBS_VERSION variable before running ./install.sh, like
    this:

    # Download the bleeding edge build
    OBS_VERSION=master ./install.sh

    This feature comes with a few rules:

    - If OBS_VERSION differs from the version that you built last time,
      then OBS and its dependencies will be re-downloaded.
    - This script does not support any OBS version earlier than 27.0.1.

  - USE_EXPERIMENTAL_UNIVERSAL_BUILD will use an experimental version of the
    OBS project's build scripts that has multiplatform builds enabled. This
    script is supported by GitHub user "PatTheMav"; the branch containing
    this patch is located here:
    https://github.com/PatTheMav/obs-studio/tree/universal-build.

    This feature flag will be removed once multiplatform builds are officially
    provided by OBS.

    ***IMPORTANT***: THIS IS AN EXPERIMENTAL OPTION AND IS PROVIDED AS-IS. NO SUPPORT
    WILL BE PROVIDED SHOULD YOU USE THIS OPTION. PLEASE CONTACT THE ORIGINAL DEVELOPER
    OF THIS FORK SHOULD YOU RUN INTO ISSUES.

    In order to use this feature, you'll need to register a new GitHub application
    and retrieve its client ID and secret. Visit this page to learn how to do
    this: https://docs.github.com/en/rest/guides/basics-of-authentication. Once done,
    provide your application's client ID and secret with the GH_CLIENT_SECRET
    and GH_CLIENT_ID environment variables.

EXAMPLES

    > ./install.sh

    Builds the latest version of OBS.

    > USE_EXPERIMENTAL_UNIVERSAL_BUILD=true GH_CLIENT_ID=foo GH_CLIENT_SECRET=bar install.sh

    Fetches the latest version of OBS from GitHub Action built using a patched version of
    its official CI build script.
USAGE
}

_log() {
  >&2 echo "[$(date)] $(echo "$1" | tr '[:lower:]' '[:upper:]'): $2"
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
    { test "$(uname -p)" != "arm64" && test "$(uname -p)" != "arm"; }
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

delete_obs_and_deps_before_building() {
  log_info "Deleting OBS, StreamFX, and Virtual Camera. Type your password in when prompted..."
  for dir in "/Applications/OBS.app" \
    "/Library/CoreMediaIO/Plug-Ins/DAL/" \
    "/Library/Application Support/obs-studio/plugins"
  do
    log_info "---> Deleting $dir"
    sudo rm -rf "$dir"
  done
}

verify_obs_version_or_fail() {
  _obs_version_is_branch_or_commit_sha() {
    test "$1" == "master" ||
      test "$1" == "main" ||
      ! test -z "$(echo "$1" | grep -E '^[0-9]{2}\.[0-9]{1,2}\.[0-9]{1,2}')"
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
    fail "You're trying to install OBS version $OBS_VERSION, but only versions \
$MIN_SUPPORTED_OBS_MAJOR_VERSION or greater are supported by this script."
  fi
}

install_dependencies_or_fail() {
  log_info "Installing build dependencies"
  if ! HOMEBREW_NO_AUTO_UPDATE=1 brew install -q akeru-inc/tap/xcnotary cmake \
    cmocka ffmpeg jack mbedtls@2 qt@5 swig "openssl@1.1"
  then
    fail "Unable to install one or more OBS dependencies. See log above for more details."
  fi
  log_info "Installing dylibbundler from OBS repo"
  if ! test -f "$DYLIBBUNDLER_PATH"
  then
    if ! curl -Lo "$DYLIBBUNDLER_PATH" "$DYLIBBUNDLER_URI"
    then
      fail "Unable to install dylibbundler; see above log for details"
    fi
    chmod +x "$DYLIBBUNDLER_PATH"
  fi
}

download_chromium_embedded_framework_or_fail() {
  if ! test -d "$CEF_DIR"
  then
    log_info "Fetching [Chromium Embedded Framework] from [$CEF_URL]"
    if ! {
      mkdir -p "$CEF_DIR" &&
        curl -Lo /tmp/vlc-obs.tar.gz "$CEF_URL" &&
        tar -xzf /tmp/vlc-obs.tar.gz -C "$CEF_DIR";
      }
    then
      fail "Couldn't install Chromium Embedded Framework; see logs above"
    fi
  fi
}

download_vlc_or_fail() {
  if ! test -d "$VLC_DIR"
  then
    log_info "Fetching [VLC] from [$VLC_URL]"
    if ! {
      mkdir -p "$VLC_DIR" &&
        curl -Lo /tmp/vlc-obs.tar.gz "$VLC_URL" &&
        tar -xzf /tmp/vlc-obs.tar.gz -C "$VLC_DIR";
      }
    then
      fail "Couldn't install VLC; see logs above"
    fi
  fi
}

download_obs_or_fail() {
  _fetch "OBS" "$OBS_INSTALL_DIR" "$OBS_GIT_URI" "obs" "$OBS_VERSION"
}

download_obs_deps_or_fail() {
  if ! test -d "$OBS_DEPS_DIR"
  then
    log_info "Fetching [OBS Dependencies] from [$OBS_DEPS_URL] and extracting into [$OBS_DEPS_DIR]"
    if ! {
      mkdir -p "$OBS_DEPS_DIR" &&
        curl -Lo /tmp/obs-deps.tar.gz "$OBS_DEPS_URL" &&
        tar -xzf /tmp/obs-deps.tar.gz -C "$OBS_DEPS_DIR";
      }
    then
      fail "Couldn't install OBS Dependencies; see logs above"
    fi
  fi
}

fetch_speexdsp_source() {
  _fetch "SpeexDSP" "$SPEEX_DIR" "$SPEEX_URI" "speex_dsp" "master"
}


copy_modified_files_into_cloned_repo() {
  while read -r file
  do
    # shellcheck disable=SC2001
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
    # shellcheck disable=SC2001
    dest="$OBS_INSTALL_DIR/$(echo "$template" | sed 's#template/##')"
    _create_folder_for_file_if_not_exist "$dest"
    log_info "Copying template [$template] into [$dest]"
    cp "$template" "$dest"
  done < <(find template -type f | grep -Ev '(Instructions|DS_Store)')
}

build_obs_or_fail() {
  export LDFLAGS="-L/opt/homebrew/opt/openssl@1.1/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/openssl@1.1/include"
  pushd "$OBS_INSTALL_DIR/cmake" || return
  if ! (
    cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 -DDISABLE_PYTHON=ON \
      -DCMAKE_PREFIX_PATH="/opt/homebrew/opt/qt@5;/opt/homebrew/opt/mbedtls@2" \
      -DSPEEXDSP_INCLUDE_DIR="$SPEEX_DIR/include" \
      -DSWIGDIR="$OBS_DEPS_DIR" \
      -DENABLE_VLC=ON \
      -DWITH_RTMPS=ON \
      -DVLC_INCLUDE_DIR="$VLC_DIR/vlc-${VLC_VERSION}/include/vlc" \
      -DVLCPath="$VLC_DIR/vlc-${VLC_VERSION}" \
      -DBUILD_BROWSER=ON \
      -DLEGACY_BROWSER=OFF \
      -DCEF_ROOT_DIR="${CEF_DIR}/${CEF_FOLDER_NAME}" \
      -DDepsPath="$OBS_DEPS_DIR" .. &&
    make -j8 &&
    stat rundir/RelWithDebInfo/bin/obs 1>/dev/null
  )
  then
    popd &>/dev/null || return
    fail "Unable to build OBS; see above logs for more info. \
Try running this instead: REPACKAGE=true ./install.sh"
  fi
  popd &>/dev/null || return
}

dmg_obs_or_fail() {
  if test -z "$(intermediate_app_path)"
  then
    log_info "Packaging OBS into an image"
    pushd "$OBS_INSTALL_DIR/cmake" || return
    if ! cpack || test -z "$(intermediate_app_path)"
    then
      popd &>/dev/null || return
      fail "Unable to package OBS into a DMG; see above logs for more info."
    fi
    popd &>/dev/null || return
  fi
}

intermediate_app_path() {
  if ! find "$OBS_INSTALL_DIR" -name OBS.app | head -1
  then
    fail "Couldn't find generated OBS MacOS app"
  fi
}

add_opengl_into_package() {
  log_info "Adding OpenGL to OBS package"
  cp -r '/tmp/obs/libobs-opengl' "$(intermediate_app_path)/Contents/Frameworks"
}

add_cef_into_package() {
  log_info "Adding Chromium Embedded Framework into package"
  cp -r "${CEF_DIR}/${CEF_FOLDER_NAME}/Release/Chromium Embedded Framework.framework" \
    "$(intermediate_app_path)/Contents/Frameworks"
}

# NOTE: This function seems to fail the first time around but succeed
# thereafter. This might be a bug; not sure at the moment.
add_bundled_plugins_or_fail() {
  attempted="${1:-false}"
  log_info "Adding bundled OBS plugins"
  # This was copied straight from the OBS CI pipeline
  log_debug "Bundling with these options: ${BUNDLE_PLUGINS[*]/#/-x }"
  # shellcheck disable=SC2116
  # shellcheck disable=SC2046
  if ! {
    "$DYLIBBUNDLER_PATH" -cd -of -a "$(intermediate_app_path)" -q -f \
      -s "$(intermediate_app_path)/Contents/Resources/bin" \
      -s "$(intermediate_app_path)/Contents/MacOS" \
      -s "$OBS_INSTALL_DIR/cmake/rundir/RelWithDebInfo/obs-plugins" \
      -s "${OBS_DEPS_DIR}/lib" \
      -x "$OBS_INSTALL_DIR/cmake/rundir/RelWithDebInfo/bin/obs-ffmpeg-mux" \
      $(echo "${BUNDLE_PLUGINS[@]/#/-x ${OBS_INSTALL_DIR}/cmake/rundir/RelWithDebInfo/obs-plugins/}");
  }
  then
    if test "$attempted" == "true"
    then
      fail "Couldn't install OBS plugins; see logs above"
    else
      log_warning "Couldn't install plugins on the first shot; trying again"
      add_bundled_plugins_or_fail "true"
    fi
  fi
}

copy_obs_app_into_downloads() {
  log_info "Copying final OBS DMG into your Downloads directory"
  test -f "$FINAL_APP_PATH" && rm -f "$FINAL_APP_PATH"
  cp -r "$(intermediate_app_path)" "$FINAL_APP_PATH"
  cp -Rv "${OBS_DEPS_DIR}/lib/." "$FINAL_APP_PATH/Contents/Resources/bin/"
}

add_virtualcam_plugin() {
  log_info "Adding MacOS Virtual Camera plugin."
  cp -r "$OBS_INSTALL_DIR/cmake/rundir/RelWithDebInfo/data/obs-plugins/mac-virtualcam/obs-mac-virtualcam.plugin" \
    "$(intermediate_app_path)/Contents/Resources/data"
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
      rm -rf "$SPEEX_DIR" &&
      rm -rf "$VLC_DIR" &&
      rm -rf "$CEF_DIR" &&
      rm -rf "$DYLIBBUNDLER_PATH"
  else
    log_info "Clean up skipped. You can find OBS sources at $OBS_INSTALL_DIR,
OBS dependencies sources at $OBS_DEPS_DIR, and Speex sources at
$SPEEX_DIR."
  fi
}

use_experimental_universal_build() {
  grep -Eiq '^true$' <<< "$USE_EXPERIMENTAL_UNIVERSAL_BUILD"
}


download_experimental_universal_build_of_obs_or_fail() {
  _get_gh_actions_target_artifact_url() {
    token="$1"
    # This needs to be done in a loop since some builds might not have any
    # artifacts and the top-level object does not expose the number of artifacts
    # that were produced.
    workflow_runs=$(curl -H "Authorization: token $token" \
        -Ls "https://api.github.com/$OBS_GH_ACTIONS_RUNS_URI" |
      jq -r '.workflow_runs')
    test -z "$workflow_runs" && fail "Unable to get OBS CI builds"
    number_of_runs=$(jq -r '. | length' <<< "$workflow_runs")
    for idx in $(seq 0 "$number_of_runs")
    do
      artifact_url="$(jq -r ".[$idx].artifacts_url" <<< "$workflow_runs")"
      id="$(jq -r ".[$idx].id" <<< "$workflow_runs")"
      log_info "Checking OBS build job $id for artifacts..."
      test -z "$artifact_url" && fail "Couldn't get run $idx from CI builds"
      artifacts=$(curl -H "Authorization: token $token" -Ls "$artifact_url" | jq -r .)
      test -z "$artifact_url" && fail "Couldn't get artifacts from OBS build $id"
      num_artifacts=$(jq -r '.total_count' <<< "$artifacts")
      if test "$num_artifacts" != "0"
      then
        jq -r '.artifacts[] | select(.name == "obs-macos-arm64") | .archive_download_url' <<< "$artifacts"
        return
      fi
      log_warning "OBS build [$id] doesnt' have any artifacts. Checking next job."
    done
  }

  # TODO: Break this function down; it's doing too much.
  token="$1"
  if ! (
    target_artifact_url=$(_get_gh_actions_target_artifact_url "$token")
    destination="$OBS_INSTALL_DIR/obs.zip"
    test -z "$target_artifact_url" && fail "Unable to get the download link to the \
latest pre-compiled build of OBS."
    log_info "Downloading latest OBS cross-platform build from $target_artifact_url"
    test -d "$OBS_INSTALL_DIR" || mkdir -p "$OBS_INSTALL_DIR"
    curl -H "Authorization: token $token" -Lo "$destination" "$target_artifact_url"
    test -f "$destination" || fail "Unable to download OBS"
    file "$destination" | grep -Ei 'zip' || fail "OBS download is corrupted. Expected \
a ZIP file, but got a $(file "$destination")."
    log_info "Unzipping $destination to $FINAL_APP_PATH"
    unzip "$destination" -d "$(basename "$FINAL_APP_PATH")"
    log_info "OBS downloaded; move OBS into your Applications folder when prompted."
    open "$(find "$(basename "$FINAL_APP_PATH")" -name "obs-studio*macOS*dmg" | head -1)"
  )
  then
    fail "Unable to fetch the latest universal OBS artifact"
  fi
}

build_experimental_universal_build_of_obs_or_fail() {
  pushd "$OBS_INSTALL_DIR" || return
  if ! ./CI/build-macos.sh -b
  then
    popd &>/dev/null || return
    fail "Unable to build OBS; see above logs for more info. \
Set USE_EXPERIMENTAL_UNIVERSAL_BUILD=false or try running this \
instead: REPACKAGE=true ./install.sh"
  fi
  popd &>/dev/null || return
}

verify_gh_actions_env_vars_or_fail() {
  for var in GH_CLIENT_ID GH_CLIENT_SECRET
  do
    test -z "${!var}" && fail "Please define $var"
  done
}

verify_jq_installed_or_fail() {
  &>/dev/null which jq || fail "You'll need to install jq. Install it from \
Homebrew: brew install jq"
}

retrieve_access_token_or_fail() {
  _tell_user_to_authorize_their_app() {
    auth_url="https://github.com/login/oauth/authorize?scope=actions&client_id=$GH_CLIENT_ID"
    log_info "In order to fetch OBS from GitHub Actions, you'll need to authorize the application \
that you created. Click this URL or copy/paste it into your browser to do that: \
$auth_url."
  }

  _wait_for_code() {
    wait_for_code_timeout_secs=180
    callback_port=4567
    response=$(sh -c "echo 'HTTP/1.1 200 OK\n\nThanks. Go back to your terminal to finish \
installing OBS.' && exit" | nc -w $wait_for_code_timeout_secs -l $callback_port)
    test -z "$response" && fail "Timed out while waiting to authorize GitHub app \
$GH_CLIENT_ID or something went wrong."
    echo "$response" | grep -E '^GET' | sed 's/.*code=\(.*\) HTTP.*$/\1/'
  }

  _exchange_code_and_secret_for_access_token() {
    code="$1"
    url="https://github.com/login/oauth/access_token?client_id=$GH_CLIENT_ID&\
client_secret=$GH_CLIENT_SECRET&code=$code"
    response=$(curl -H "Accept: application/json" -X POST "$url")
    test -z "$response" && fail "GitHub didn't respond upon attempting to get an access token."
    error=$(jq -r '.error' <<< "$response")
    error_desc=$(jq -r '.error_description' <<< "$response")
    test "$error" == "null" || fail "Failed to get a GitHub access token: $error => $error_desc"
    jq -r '.access_token' <<< "$response"
  }

  _tell_user_to_authorize_their_app
  code=$(_wait_for_code)
  _exchange_code_and_secret_for_access_token "$code"
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

if use_experimental_universal_build
then
  verify_gh_actions_env_vars_or_fail
  verify_jq_installed_or_fail
fi

delete_obs_and_deps_before_building
if use_experimental_universal_build
then
  token=$(retrieve_access_token_or_fail)
  test -z "$token" && fail "Couldn't get a valid GitHub access token; check logs above for more
info."
  download_experimental_universal_build_of_obs_or_fail "$token"
else
  verify_obs_version_or_fail
  remove_data_directories_if_repackaging
  install_dependencies_or_fail
  download_vlc_or_fail
  download_chromium_embedded_framework_or_fail
  download_obs_or_fail
  download_obs_deps_or_fail
  copy_modified_files_into_cloned_repo
  copy_templates_into_cloned_repo
  fetch_speexdsp_source
  build_obs_or_fail
  dmg_obs_or_fail
  add_opengl_into_package
  add_cef_into_package
  add_virtualcam_plugin
fi
copy_obs_app_into_downloads
remove_data_directories

disable_tracing

log_info "Installation succeeded! Move OBS from your Downloads folder into \
your Applications folder when the window pops up."
open "$(dirname "$FINAL_APP_PATH")"
