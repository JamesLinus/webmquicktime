#!/bin/bash
##
##  Copyright (c) 2012 The WebM project authors. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license
##  that can be found in the LICENSE file in the root of the source
##  tree. An additional intellectual property rights grant can be found
##  in the file PATENTS.  All contributing project authors may
##  be found in the AUTHORS file in the root of the source tree.

##
## usage: scripts/build/build_dmg.sh [DMGs]
## example:
##   scripts/build/build_dmg.sh all
##
## Builds DMG(s) based on $1 value, when:
## - $1 is empty, or $1 == all, builds the full DMG and both update DMGs.
## - $1 is regex match for webm: builds webm update DMG.
## - $1 is a regex match for xiph: builds the xiph update DMG.
##
## Note: as implied by the examples, this script must be run from
##       webmquicktime/installer.

set -e

if [[ $(basename $(pwd)) != "installer" ]] || \
    [[ $(basename $(dirname $(pwd))) != "webmquicktime" ]]; then
  echo "$(basename $0) must be run from webmquicktime/installer"
  exit 1
fi

source scripts/build/read_bundle_plist.sh
source scripts/build/util.sh
readonly BACKGROUND_IMAGE="Background.png"
readonly INSTALLER_DIR="$(pwd)"

file_exists "${BACKGROUND_IMAGE}" || die "${BACKGROUND_IMAGE} does not exist."

## build_dmg <DMG file name> <Volume name> <Package file>
##     [Include Xiph Licenses]
## For example, the following command:
##   build_dmg widget.dmg "Awesome Widgets" awesome_widgets.pkg
## The above builds a DMG file named widget.dmg that is mounted as a volume
## named "Awesome Widgets", and contains:
##   - awesome_widgets.pkg
##   - uninstaller.app
##   - uninstall_helper.sh
## When a fourth argument is present, |build_dmg| includes the XiphQT
## COPYING.*.txt files in the disk image.
build_dmg() {
  local readonly DMG_FILE="$1"
  local readonly VOL_NAME="$2"
  local readonly PKG_FILE="$3"
  local readonly COPY_XIPH_LICENSES="$4"

  [[ -n "${DMG_FILE}" ]] || die "DMG file name empty in ${FUNCNAME}."
  [[ -n "${VOL_NAME}" ]] || die "Volume name empty in ${FUNCNAME}."
  file_exists "${PKG_FILE}" || die "${PKG_FILE} does not exist in ${FUNCNAME}."

  copy_uninstaller

  # Copy the update install script.
  cp -p "scripts/keystone_install.sh" "${TEMP_DIR}/.keystone_install"

  if [[ -n "${COPY_XIPH_LICENSES}" ]]; then
    # Copy the XiphQT COPYING.*.txt files.
    copy_xiphqt_licenses
  fi

  copy_bundle "${PKG_FILE}" "${TEMP_DIR}"

  # Create the disk image.
  create_dmg --window-size 720 380 --icon-size 48 \
    --background "${INSTALLER_DIR}/${BACKGROUND_IMAGE}" \
    --volname "${VOL_NAME}" "/tmp/${DMG_FILE}" "${TEMP_DIR}"

  cleanup
  mv "/tmp/${DMG_FILE}" "${INSTALLER_DIR}"
}

cleanup() {
  local readonly RM="rm -r -f"
  ${RM} "${TEMP_DIR}"*
}

copy_uninstaller() {
  local readonly UNINSTALL_APP="uninstall.app"
  local readonly UNINSTALL_SCRIPT="scripts/uninstall_helper.sh"
  copy_bundle "${UNINSTALL_APP}" "${TEMP_DIR}"
  cp -p "${UNINSTALL_SCRIPT}" "${TEMP_DIR}"
}

copy_xiphqt_licenses() {
  local readonly XIPHQT_LICENSE_PATH="../third_party/xiphqt/"
  cp -p "${XIPHQT_LICENSE_PATH}"/*.txt "${TEMP_DIR}"
}

create_dmg() {
  local readonly CREATE_DMG_PATH="../third_party/yoursway-create-dmg/"
  local readonly CREATE_DMG="./create-dmg"

  # Note: must cd into |CREATE_DMG_PATH| for create-dmg to work.
  local readonly OLD_DIR="$(pwd)"
  cd "${CREATE_DMG_PATH}"
  ${CREATE_DMG} "$@"
  cd "${OLD_DIR}"
}

# Create temporary directory.
readonly TEMP_DIR="$(mktemp -d /tmp/webmqt_dmg.XXXXXX)/"

if [[ -z "${TEMP_DIR}" ]] || [[ "{TEMP_DIR}" == "/" ]]; then
  # |TEMP_DIR| will be passed to "rm -r -f" in |cleanup|. Avoid any possible
  # mktemp shenanigans.
  die "TEMP_DIR path empty or unsafe (TEMP_DIR=${TEMP_DIR})."
fi

if [[ ! -e "${UNINSTALL_APP}" ]]; then
  scripts/build/build_uninstaller.sh
fi

# Read the component version strings.
readonly WEBM_PLIST="../Info.plist"
readonly WEBM_VERSION="$(read_bundle_version ${WEBM_PLIST})"
readonly XIPHQT_COMPONENT="../third_party/xiphqt/XiphQT.component"
readonly XIPHQT_VERSION="$(read_bundle_version ${XIPHQT_COMPONENT})"

# Confirm the version strings are non-zero length.
[[ -n "${WEBM_VERSION}" ]] || die "empty WebM version string."
[[ -n "${XIPHQT_VERSION}" ]] || die "empty XiphQT version string."

readonly WEBM_DMG_FILE="webm_quicktime_installer_${WEBM_VERSION}.dmg"
readonly WEBM_NAME="WebM QuickTime Installer"
readonly WEBM_MPKG="${WEBM_NAME}.mpkg"

# Build the DMG file.
build_dmg "${WEBM_DMG_FILE}" "${WEBM_NAME}" "${WEBM_MPKG}" xiph
debuglog "Done."
