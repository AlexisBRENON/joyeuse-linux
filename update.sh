#!/usr/bin/env bash

# Brides de scripts pour faire une versionneuse pour Windows.

drive_search() {
  for MOUNT_POINT in $(mount -l -t vfat | cut -d' ' -f3); do
    if [ -d "${MOUNT_POINT}/Secrets" ]; then
      for SECRET_FILE in "${MOUNT_POINT}/Secrets/"*; do
        case "$(basename "${SECRET_FILE}")" in
          JOY-*)
            echo "${MOUNT_POINT}"
            exit 0
            ;;
          *)
            ;;
        esac
      done
    fi
  done
}

drive_save() {
  MOUNT_POINT="$1"
  backup_id=$(basename "${MOUNT_POINT}/Secrets/JOY-"*)_$(basename "${MOUNT_POINT}/Secrets/VERSION_V"*)_$(date -Iseconds)
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "${MOUNT_POINT}" "/var/joyeuse/backup/${backup_id}"
  echo "${backup_id}"
}

drive_restore() {
  MOUNT_POINT="$1"
  backup_id="$2"
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "/var/joyeuse/backup/${backup_id}" "${MOUNT_POINT}"
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
    i=$(( i + 1 ))
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
  mount_point="$(drive_search)"
  backup_id="$(drive_save "${mount_point}")"
  drive_format "${mount_point}"
  go_boot_mode "${mount_point}"
  serial_device="$(dfu_search)"
  dfu_update "${serial_device}"
  mount_point="$(drive_wait_connection)"
  drive_restore "${mount_point}" "${backup_id}"
}
