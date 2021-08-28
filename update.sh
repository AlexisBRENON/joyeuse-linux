#!/usr/bin/env bash

set -eux

# Brides de scripts pour faire une versionneuse pour Linux.
state_folder="${XDG_STATE_HOME:-${HOME}/.local/state}/Joyeuse/"
data_folder="${XDG_DATA_HOME:-${HOME}/.local/share}/Joyeuse/"
tmp_folder="/tmp/joyeuse"
mkdir -p "${state_folder}" "${data_folder}" "${tmp_folder}"


drive_search() {
  for MOUNT_POINT in $(mount -l -t vfat | cut -d' ' -f3); do
    if [ -d "${MOUNT_POINT}/Secrets" ]; then
      for SECRET_FILE in "${MOUNT_POINT}/Secrets/"*; do
        case "$(basename "${SECRET_FILE}")" in
        JOY_*)
          echo "${MOUNT_POINT}"
          exit 0
          ;;
        *) ;;

        esac
      done
    fi
  done
  exit 1
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
    "${MOUNT_POINT}/" "${backup_path}"
}

drive_restore() {
  MOUNT_POINT="$1"
  backup_path="$2"
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "${backup_path}" "${MOUNT_POINT}/"
}

drive_format() {
  mount_point="$1"
  device="$(mount -l | grep "${mount_point}" | cut -d' ' -f1)"
  label_name="${2:-JOYEUSE-507}"
  mkfs.vfat -F 16 -n "$label_name" -v "$device"
}

drive_wait_connection() {
  i=0
  while [ "$i" -lt 60 ]; do
    mount_point=$(drive_search)
    if [ -n "${mount_point}" ]; then
      echo "${mount_point}"
      exit 0
    fi
    i=$((i + 1))
    sleep 1
  done
}

go_boot_mode() {
  mount_point="$1"
  touch "${mount_point}/upgrade.txt"
}

dfu_search() {
  dfu-util -w -d 0483:df11 -a 0 -s 0x08000000:4 -U /dev/null >/dev/null &
  waiting_pid=$!
  echo "Waiting bootloader to be detected..." >&2
  start_time=$(date +%s)
  while [[ $(( $(date +%s) - start_time )) -lt 120 ]]; do
    sleep 2
    if ps ${waiting_pid}; then
      exit 0 # dfu-util detected device
    else
      echo "."
    fi
  done
  echo "Unable to detect bootloader... Aborting" >&2
  exit 1
}

dfu_update() {
  # Convert hex file to bin (for dfu-util usage) filling gap with FF bytes
  objcopy --input-target=ihex --output-target=binary --gap-fill=0xFF \
    "${data_folder}/fw/cube_fw_v5.07.hex" "${tmp_folder}/cube_fw_v5.07.bin"
  dfu-util -v -d 0483:df11 -a 0 --reset -s 0x08000000:141646 -D "${tmp_folder}/cube_fw_v5.07.bin"
}

main() {
  echo "$$" > "${state_folder}/pid"

  echo "Search for a Joyeuse drive..."
  mount_point="$(drive_search)"
  echo "Drive found: \"${mount_point}\""
  df -h "${mount_point}"

  backup_path="$(get_backup_path "${mount_point}")"
  echo "Start backup from ${mount_point} to ${backup_path}"
  drive_save "${mount_point}" "${backup_path}"
  echo "Backup was successfully done"

  drive_format "${mount_point}"
  echo "Drive format finished successfully"

  go_boot_mode "${mount_point}"
  echo "upgrade.txt file created successfully"

  echo "Unplug (wait for sound (tu-di-tu-duu) and re-plug the device..."
  dfu_search
  dfu_update
  #  mount_point="$(drive_wait_connection)"
  #  drive_restore "${mount_point}" "${backup_path}"
}

main
