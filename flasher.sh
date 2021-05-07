#!/usr/bin/env python

set -euo pipefail
shopt -s inherit_errexit

READY_TO_FLASH_GPIO="27"
FLASH_OK_GPIO="17"

UPLOAD_PORT=/dev/ttyS0
UPLOAD_SPEED=115200
FIRMWARE_FILE=firmware/firmware.elf

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FIRMWARE_PATH=$SCRIPT_DIR/$FIRMWARE_FILE

# export pins and set their directions and initial states

echo "$READY_TO_FLASH_GPIO" > /sys/class/gpio/export
echo "$FLASH_OK_GPIO" > /sys/class/gpio/export

echo "in" > /sys/class/gpio/gpio${READY_TO_FLASH}/direction
echo "out" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/direction

echo "0" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/value

while true; do
    sleep 2

    if [ $(cat /sys/class/gpio/gpio${READY_TO_FLASH_GPIO}/value) -eq "1" ] ; then
        pyupdi \
            -i \
            -d attiny1614 \
            -c $UPLOAD_PORT \
            -b $UPLOAD_SPEED \
            -f $FIRMWARE_PATH \
         || continue

        echo "1" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/value
        sleep 1
        echo "0" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/value
    fi
done