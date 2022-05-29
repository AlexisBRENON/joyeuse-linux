#!/usr/bin/env bash

set -eu
if [ -n "${JOY_UPD_DEBUG:-""}" ]; then set -x; fi

JOY_VERSION="V05.09"
JOY_FW_DL_URL="https://club.joyeuse.io/files/uploads/storyteller_updater/0001/01/joyeuse_updater_mac_std_1.0.9_fr.dmg"

state_folder="${XDG_STATE_HOME:-${HOME}/.local/state}/Joyeuse/"
tmp_folder="/tmp/joyeuse${JOY_VERSION}"
mkdir -p "${state_folder}" "${tmp_folder}"

trap updater_trap INT

updater_trap() {
  for pid in ${waiting_pid:-""}; do
    kill -9 "$pid"
  done
}

localize() {
  # Get user locale
  user_locale="$(echo "${LC_MESSAGES:-${LANG:-"en_US"}}" | cut -d'.' -f1)"
  user_lang="$(echo "${user_locale}" | cut -d'_' -f1)"
  l11n_file="l11n/en.sh" # Locale fallback
  # Find best suiting localization file
  if [ -e "l11n/${user_locale}.sh" ]; then
    l11n_file="l11n/${user_locale}.sh"
  elif [ -e "l11n/${user_lang}.sh" ]; then
    l11n_file="l11n/${user_lang}.sh"
  else
    echo "No localization file found for ${user_locale}"
  fi
  echo "Loading localization from ${l11n_file}"
  # shellcheck source=l11n/en.sh
  . "${l11n_file}"
}

log() {
  template="$1"
  shift
  eval echo "${template}"
}

download_updater() {
  # Download Mac updater from joyeuse website
  if [ ! -e "${tmp_folder}/updater.dmg" ]; then
    curl -L "${JOY_FW_DL_URL}" > ${tmp_folder}/updater.dmg
  fi
}

extract_file_from_updater() {
  file_glob="$1"
  zipped_file_path="$(7z l ${tmp_folder}/updater.dmg | grep -e "${file_glob}" | rev | cut -d' ' -f1 | rev)"
  if [ -n "${zipped_file_path}" ]; then
    resulting_file="$(basename "${zipped_file_path}")"
    if [ ! -e "${tmp_folder}/${resulting_file}" ]; then
      7z e -o"${tmp_folder}" "${tmp_folder}/updater.dmg" "${zipped_file_path}" >/dev/null
    fi
    if [ -e "${tmp_folder}/${resulting_file}" ]; then
      echo "${tmp_folder}/${resulting_file}"
      return 0
    fi
  fi
  return 1
}

get_fw() {
  download_updater
  # Find the firmware file in the archive
  hex_file=$(extract_file_from_updater '.hex$')
  bin_file="${hex_file/.hex/.bin}"
  # Convert hex file to bin (for dfu-util usage) filling gap with FF bytes
  objcopy --input-target=ihex --output-target=binary --gap-fill=0xFF \
        "${hex_file}" "${bin_file}"
  echo "${bin_file}"
}

drive_search() {
  # Search in vfat mounted filesystems
  for device in $(findmnt --types vfat --output SOURCE --noheadings); do
    # Filter on udev vendor and model ID
    dev_ids="$(udevadm info "${device}" | grep -e ID_VENDOR_ID -e ID_MODEL_ID | cut -d'=' -f2 | paste -sd':')"
    if [ "${dev_ids}" = "0483:572a" ]; then
      # Output the mount point of the device
      findmnt --source "${device}" --output TARGET --noheadings
      return 0
    fi
  done
  log "${JOY_UPD_SEARCH_FAIL}" >&2
  return 1
}

get_backup_path() {
  MOUNT_POINT="$1"
  current_date="$(date -Iseconds)"
  serial="$(basename "${MOUNT_POINT}/Secrets/JOY_"*)"
  version="$(basename "${MOUNT_POINT}/Secrets/VERSION_V"*)"
  backup_path="${state_folder}/backups/${current_date}_${serial}_${version}/"
  mkdir -p "${backup_path}"
  echo "${backup_path}"
}

drive_save() {
  MOUNT_POINT="$1"
  backup_path="$2"
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "${MOUNT_POINT}/" "${backup_path}" \
    >/dev/null
}

drive_restore() {
  MOUNT_POINT="$1"
  backup_path="$2"
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "${backup_path}" "${MOUNT_POINT}/" \
    >/dev/null
  rm -fr "${backup_path}"
}

drive_format() {
  mount_point="$1"
  device="$(mount -l | grep "${mount_point}" | cut -d' ' -f1)"
  label_name="${2:-JOYEUSE-507}"
  udisksctl unmount -b "${device}" >> "${state_folder}/format.log"
  mkfs.vfat -F 16 -n "$label_name" -v "$device" >> "${state_folder}/format.log"
  mounting_log="$(udisksctl mount -b "${device}")"
  echo "${mounting_log}" >> "${state_folder}/format.log"
  # shellcheck disable=SC2001
  echo "${mounting_log}" | sed -e 's/^.*at //'
}

drive_wait_connection() {
  i=0
  while [ "$i" -lt 120 ]; do
    mount_point=$(drive_search 2>/dev/null)
    if [ -n "${mount_point}" ]; then
      echo "${mount_point}"
      return 0
    fi
    echo -n "." >&2
    i=$((i + 1))
    sleep 1
  done
  return 1
}

go_boot_mode() {
  mount_point="$1"
  touch "${mount_point}/upgrade.txt"
}

dfu_search() {
  rm -f "${tmp_folder}/dfu_search"
  date >> "${state_folder}/dfu_search.log"
  # Wait for the expected device to show up
  dfu-util -w -d 0483:df11 -a 0 -s 0x08000000:4 -U "${tmp_folder}/dfu_search" >> "${state_folder}/dfu_search.log" &
  last_pid="$!"
  waiting_pid="${waiting_pid:-""} ${last_pid}"
  start_time=$(date +%s)
  # Wait at most 120 seconds for connection
  while [[ $(($(date +%s) - start_time)) -lt 120 ]]; do
    sleep 2
    if ps ${last_pid} >/dev/null ; then
      echo -n "."
    else
      # dfu-util detected device
      echo ""
      rm -f "${tmp_folder}/dfu_search"
      return 0
    fi
  done
  log "${JOY_UPD_BOOT_FAIL}"  >&2
  return 1
}

dfu_update() {
  firmware_file="${1}"
  file_size="$(stat --printf="%s" "${firmware_file}")"
  # Abort if file size it too big for board
  if [ "${file_size}" -gt 524288 ]; then
    log "${JOY_UPD_UPDATE_FAIL_FILE_SIZE}" >&2
    return 1
  fi
  set -x
  dfu-util -v -d "0483:df11" -a 0 --reset -s "0x08000000:${file_size}" -D "${firmware_file}"
  set +x
}

update_secrets() {
  mount_point="$1"
  download_updater
  for F in 'Secrets/SETTINGS.txt' 'Secrets/V5.txt'; do
    file=$(extract_file_from_updater "$F")
    cp --force --backup=simple --suffix=".bak" "${file}" "${mount_point}/${F}"
  done
  echo "" > "${mount_point}/VERSION_V5.07"

  serial_number="$(basename "$(ls -1 "${mount_point}/Secrets/JOY_"*)")"
  cat > "${tmp_folder}/info.js" <<EOJSON
var info = {
 VERSION: '${JOY_VERSION}',
 SERIAL_NUMBER: '${serial_number}',
 BABY_MODE: 'N',
 LEGACY_HW: 'N',
 BILINGUAL_MODE: 'N',
 FR: 'Y',
 EN: 'N',
 DE: 'N',
 IT: 'N',
 INTERNATIONAL_MODE: 'N'
};
EOJSON
  cp --force --backup=simple --suffix=".bak" "${tmp_folder}/info.js" "${mount_point}/Secrets/info.js"
}

main() {
  localize
  steps="${1:-YYYYYYYYY}"

  if [ "${steps:0:1}" = 'Y'  ]; then
    log "${JOY_UPD_FW_START}"
    firmware_file=$(get_fw)
    log "${JOY_UPD_FW_DONE}" "${firmware_file}"
  else
    firmware_file="$(ls "${tmp_folder}/"*.bin)"
  fi

  if [ "${steps:1:1}" = 'Y'  ]; then
    log "${JOY_UPD_SEARCH_START}"
    mount_point="$(drive_search)"
    log "${JOY_UPD_SEARCH_DONE}" "${mount_point}"
    df -h "${mount_point}"
  fi

  if [ "${steps:2:1}" = 'Y'  ]; then
    backup_path="$(get_backup_path "${mount_point}")"
    log "${JOY_UPD_BAK_START}" "${mount_point}" "${backup_path}"
    drive_save "${mount_point}" "${backup_path}"
    log "${JOY_UPD_BAK_DONE}"
  else
    backup_path="$(ls -d --time=birth "${state_folder}"/backups/* | head -n1)/"
  fi

  if [ "${steps:3:1}" = 'Y'  ]; then
    mount_point="$(drive_format "${mount_point}")"
    log "${JOY_UPD_FORMAT_DONE}"
  fi

  if [ "${steps:4:1}" = 'Y'  ]; then
    go_boot_mode "${mount_point}"
    log "${JOY_UPD_BOOT_UPGRADE}"

    log "${JOY_UPD_BOOT_REPLUG}"
  fi

  if [ "${steps:5:1}" = 'Y'  ]; then
    log "${JOY_UPD_BOOT_DETECT}"
    dfu_search
    log "${JOY_UPD_BOOT_FOUND}"
  fi

  if [ "${steps:6:1}" = 'Y'  ]; then
    dfu_update "${firmware_file}"
    log "${JOY_UPD_UPDATE_DONE}"
  fi

  if [ "${steps:7:1}" = 'Y'  ]; then
    log "${JOY_UPD_UPDATE_REPLUG}"
    mount_point="$(drive_wait_connection)"
  fi

  if [ "${steps:8:1}" = 'Y'  ]; then
    log "${JOY_UPD_RESTORE_START}" "${backup_path}" "${mount_point}"
    drive_restore "${mount_point}" "${backup_path}"
    log "${JOY_UPD_RESTORE_DONE}"
  fi

  if [ "${steps:9:1}" = 'Y'  ]; then
    log "${JOY_UPD_VERSION_START}"
    update_secrets "${mount_point}"
    log "${JOY_UPD_VERSION_DONE}"
  fi
}

main "$@"
