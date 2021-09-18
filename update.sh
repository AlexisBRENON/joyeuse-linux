#!/usr/bin/env bash

set -eu
if [ -n "${JOY_UPD_DEBUG:-""}" ]; then set -x; fi

state_folder="${XDG_STATE_HOME:-${HOME}/.local/state}/Joyeuse/"
data_folder="${XDG_DATA_HOME:-${HOME}/.local/share}/Joyeuse/"
tmp_folder="/tmp/joyeuse"
mkdir -p "${state_folder}" "${data_folder}" "${tmp_folder}"

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

get_fw() {
  # Download Mac updater from joyeuse website
  if [ ! -e "${tmp_folder}/updater.dmg" ]; then
    curl -L https://club.joyeuse.io/files/uploads/storyteller_updater/0001/01/joyeuse_updater_mac_std_1.0.8_fr.dmg > ${tmp_folder}/updater.dmg
  fi
  # Find the firmware file in the archive
  firmware_file="$(7z l ${tmp_folder}/updater.dmg | grep -e '.hex$' | rev | cut -d' ' -f1 | rev)"
  if [ -n "${firmware_file}" ]; then
    hex_file="$(basename "$firmware_file")"
    # Extract the firmware file from the archive
    if [ ! -e "${tmp_folder}/${hex_file}" ]; then
      7z e -o"${tmp_folder}" "${tmp_folder}/updater.dmg" "${firmware_file}" >/dev/null
    fi
    bin_file="${hex_file/.hex/.bin}"
    # Convert hex file to bin (for dfu-util usage) filling gap with FF bytes
    objcopy --input-target=ihex --output-target=binary --gap-fill=0xFF \
        "${tmp_folder}/${hex_file}" "${tmp_folder}/${bin_file}"
    echo "${tmp_folder}/${bin_file}"
  else
    log "${JOY_UPD_FW_FAIL}" >&2
    return 1
  fi
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
    mount_point=$(drive_search)
    if [ -n "${mount_point}" ]; then
      echo "${mount_point}"
      return 0
    fi
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
  # Wait for the expected device to show up
  dfu-util -w -d 0483:df11 -a 0 -s 0x08000000:4 -U "${tmp_folder}/dfu_search" >> "${state_folder}/dfu_search.log" &
  waiting_pid=$!
  start_time=$(date +%s)
  # Wait at most 120 seconds for connection
  while [[ $(($(date +%s) - start_time)) -lt 120 ]]; do
    sleep 2
    if ps ${waiting_pid} >/dev/null ; then
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
    return 1
  fi
  set -x
  dfu-util -v -d "0483:df11" -a 0 --reset -s "0x08000000:${file_size}" -D "${firmware_file}"
  set +x
}

main() {
  localize

  log "${JOY_UPD_FW_START}"
  firmware_file=$(get_fw)
  log "${JOY_UPD_FW_DONE}" "${firmware_file}"

  log "${JOY_UPD_SEARCH_START}"
  mount_point="$(drive_search)"
  log "${JOY_UPD_SEARCH_DONE}" "${mount_point}"
  df -h "${mount_point}"

  backup_path="$(get_backup_path "${mount_point}")"
  log "${JOY_UPD_BAK_START}" "${mount_point}" "${backup_path}"
  drive_save "${mount_point}" "${backup_path}"
  log "${JOY_UPD_BAK_DONE}"

  mount_point="$(drive_format "${mount_point}")"
  log "${JOY_UPD_FORMAT_DONE}"

  go_boot_mode "${mount_point}"
  log "${JOY_UPD_BOOT_UPGRADE}"

  log "${JOY_UPD_BOOT_REPLUG}"

  log "${JOY_UPD_BOOT_DETECT}"
  dfu_search
  log "${JOY_UPD_BOOT_FOUND}"

  dfu_update "${firmware_file}"
  log "${JOY_UPD_UPDATE_DONE}"
  log "${JOY_UPD_UPDATE_REPLUG}"

  mount_point="$(drive_wait_connection)"
  log "${JOY_UPD_RESTORE_START}" "${backup_path}" "${mount_point}"
  drive_restore "${mount_point}" "${backup_path}"
  log "${JOY_UPD_RESTORE_DONE}"
}

main
