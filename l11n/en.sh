#! /bin/sh

export JOY_UPD_FW_START="Downloading firmware file"
export JOY_UPD_FW_FAIL="Unable to find a firmware file"
export JOY_UPD_FW_FAIL_TRUNCATE="Firmware file seems to be truncated on unexpected bytes"
export JOY_UPD_FW_DONE='Firmware file found: \"${1}\"'

export JOY_UPD_SEARCH_START="Search for a Joyeuse drive..."
export JOY_UPD_SEARCH_FAIL="No Joyeuse drive found"
export JOY_UPD_SEARCH_DONE='Drive found: \"${1}\"'

export JOY_UPD_BAK_START='Start backup from \"${1}\" to \"${2}\"'
export JOY_UPD_BAK_DONE="Backup was successfully done"

export JOY_UPD_FORMAT_DONE="Drive format finished successfully"

export JOY_UPD_BOOT_UPGRADE="upgrade.txt file created successfully"
export JOY_UPD_BOOT_REPLUG="Unplug \(wait for sound \(tu-di-tu-duu\)\) and re-plug the device \(tu...tu...tu...tuu\)..."

export JOY_UPD_BOOT_DETECT="Start device detection process"
export JOY_UPD_BOOT_FAIL="Unable to detect bootloader... Aborting"
export JOY_UPD_BOOT_FOUND="STM32 USB bootloader device detected"

export JOY_UPD_UPDATE_FAIL_FILE_SIZE="Firware file size too big for your device"
export JOY_UPD_UPDATE_DONE="Firmware update completed successfully"
export JOY_UPD_UPDATE_REPLUG="Unplug, re-plug \(tu-tu-tu-ti-tu-tuu\) and mount the device..."

export JOY_UPD_RESTORE_START='Start restoring the backup content: \"${1}\" to \"${2}\"'
export JOY_UPD_RESTORE_DONE="Restoring successfully done"

export JOY_UPD_VERSION_START='Start updating version informations'
export JOY_UPD_VERSION_DONE="Version informations updated successfully"
