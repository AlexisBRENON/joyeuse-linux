#!/usr/bin/env bash

set -eux

# Brides de scripts pour faire une versionneuse pour Windows.

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
  backup_path="${XDG_STATE_HOME:-${HOME}/.local/state}/Joyeuse/backups/$(date -Iseconds)_$(basename "${MOUNT_POINT}/Secrets/JOY_"*)_$(basename "${MOUNT_POINT}/Secrets/VERSION_V"*)"
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
    "${MOUNT_POINT}" "${backup_path}"
}

drive_restore() {
  MOUNT_POINT="$1"
  backup_path="$2"
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "${backup_path}" "${MOUNT_POINT}"
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
  # TODO
  # Using a udev rule would make discovery easier
  echo "/dev/joyeuse/compteuse0" # DUMMY
}

dfu_update() {
  # TODO
  # maybe use dfu-util http://dfu-util.sourceforge.net/
  serial_device="$1"
  ls -l "${serial_device}"
  true
}

main() {
  echo "Search for a Joyeuse drive..."
  mount_point="$(drive_search)"
  echo "Drive found: \"${mount_point}\""
  df -h "${mount_point}"

  backup_path="$(get_backup_path "${mount_point}")"
  echo "Start backup from ${mount_point} to ${backup_path}"
  drive_save "${mount_point}" "${backup_path}"
  echo "Backup was successfully done"
  #  drive_format "${mount_point}"
  #  go_boot_mode "${mount_point}"
  #  serial_device="$(dfu_search)"
  #  dfu_update "${serial_device}"
  #  mount_point="$(drive_wait_connection)"
  #  drive_restore "${mount_point}" "${backup_path}"
}

main
