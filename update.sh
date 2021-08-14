#!/usr/bin/env bash

# Brides de scripts pour faire une versionneuse pour Windows.

find_joyeuse_mount_point() {
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

backup() {
  MOUNT_POINT="$1"
  backup_id=$(basename "${MOUNT_POINT}/Secrets/JOY-"*)_$(basename "${MOUNT_POINT}/Secrets/VERSION_V"*)_$(date -Iseconds)
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "${MOUNT_POINT}" "/var/joyeuse/backup/${backup_id}"
  echo "${backup_id}"
}

restore() {
  MOUNT_POINT="$1"
  backup_id="$2"
  rsync \
    --verbose --progress --human-readable \
    --compress --archive \
    --hard-links --one-file-system \
    "/var/joyeuse/backup/${backup_id}" "${MOUNT_POINT}"
}

format() {
  mount_point="$1"
  device="$(mount -l | grep "${mount_point}" | cut -d' ' -f1)"
  label_name="${2:-JOYEUSE-507}"
  mkfs.vfat -F 16 -n "$label_name" -v "$device"
}

