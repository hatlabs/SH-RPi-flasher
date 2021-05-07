#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

READY_TO_FLASH_GPIO="17"
FLASH_OK_GPIO="27"
ATT_VCC_GPIO="18"

UPLOAD_PORT=/dev/ttyAMA0
UPLOAD_SPEED=115200
FIRMWARE_FILE=firmware/firmware.hex

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FIRMWARE_PATH=$SCRIPT_DIR/$FIRMWARE_FILE

# export pins and set their directions and initial states

if [ ! -d /sys/class/gpio/gpio${READY_TO_FLASH_GPIO} ]; then
    echo "$READY_TO_FLASH_GPIO" > /sys/class/gpio/export
fi
if [ ! -d /sys/class/gpio/gpio${FLASH_OK_GPIO} ]; then
    echo "$FLASH_OK_GPIO" > /sys/class/gpio/export
fi
if [ ! -d /sys/class/gpio/gpio${ATT_VCC_GPIO} ]; then
    echo "$ATT_VCC_GPIO" > /sys/class/gpio/export
fi

sleep 1

echo "in" > /sys/class/gpio/gpio${READY_TO_FLASH_GPIO}/direction
echo "out" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/direction
echo "in" > /sys/class/gpio/gpio${ATT_VCC_GPIO}/direction

# FLASH_OK is raised when flasher is ready for action
echo "1" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/value

while true; do
    # ensure that ATT_VCC is off
    echo "in" > /sys/class/gpio/gpio${ATT_VCC_GPIO}/direction

    echo "Waiting for DUT"
    sleep 2

    if [ $(cat /sys/class/gpio/gpio${READY_TO_FLASH_GPIO}/value) -eq "1" ] ; then
        echo "DUT present; flashing."
        # FLASH_OK is lowered to indicate flashing
        echo "0" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/value
        # ATT_VCC pin provides power to ATtiny
        echo "out" > /sys/class/gpio/gpio${ATT_VCC_GPIO}/direction
        echo "1" > /sys/class/gpio/gpio${ATT_VCC_GPIO}/value

        pyupdi \
            -i \
            -d attiny1614 \
            -c $UPLOAD_PORT \
            -b $UPLOAD_SPEED \
            -f $FIRMWARE_PATH \
         || continue

        echo "Flashing successful."

        # switch ATT_VCC pin to high impedance state
        echo "0" > /sys/class/gpio/gpio${ATT_VCC_GPIO}/value
        echo "in" > /sys/class/gpio/gpio${ATT_VCC_GPIO}/direction

        # FLASH_OK is pulled high again to indicate successful flashing
        echo "1" > /sys/class/gpio/gpio${FLASH_OK_GPIO}/value
    fi
done
