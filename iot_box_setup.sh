#!/bin/bash

# Script arguments
ip=${1}
manu=${2}

# Repositories paths
ODOO_ADDONS_DIR='/home/odoo/src/odoo/addons'
ENTERPRISE_DIR='/home/odoo/src/enterprise'


# --- Text Utils ---
# Colors
normal=$(tput sgr0)
green=$(tput setaf 2)
cyan=$(tput setaf 6)
magenta=$(tput setaf 5)

# Size utils
termwidth=50
width_text=30
width_checkmark=10

# Special Symbols
checkmark="\xE2\x9C\x94"
green_checkmark="\t[${green}$checkmark${normal}]\n"
# ------

# Print out argument with cenered output surrounded by "="
function center_print() {
    padding="$(printf '%0.1s' ={1..500})"
    printf '\n%*.*s %s %*.*s\n\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "${cyan}$1${normal} ${magenta}$2${normal}" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

# Display loading spinster and green checkmard when finished
function loading() {
    spin='-\|/'
    colour=${magenta}

    i=0
    local delay=0.075
    local spinstr='|/-\'
    printf "%-${width_text}b" "  - $1"
    while [ 1 ]; do
        local temp=${spinstr#?}
        printf "  [${colour}%c${normal}]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
}

function ready() {
    printf "%-${width_text}b" "  - $1"
    printf "%-${width_checkmark}b" "$green_checkmark"
}

# ------ IOT BOX SETUP ------

center_print "Setting up the IoT Box"
ssh-keyscan -H ${ip} >> ~/.ssh/known_hosts >/dev/null 2>&1
ssh-keygen -f "/home/odoo/.ssh/known_hosts" -R ${ip} >/dev/null 2>&1
ready "IoT added to known hosts"

sshpass -p "raspberry" ssh pi@${ip} 'sudo killall python3' >/dev/null 2>&1
sshpass -p "raspberry" ssh pi@${ip} 'sudo mount -o remount,rw /' >/dev/null 2>&1
ready "IoT box set to write mode"


# ------ TRANSFER FILES TO IOT BOX ------
center_print "Sending files to" "${1}"

# addons/hw_posbox_homepage files
loading "addons/hw_posbox_homepage" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_posbox_homepage/controllers/main.py pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/controllers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_posbox_homepage/views/* pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/views/
kill $loading_pid >/dev/null 2>&1
printf "\b\b\b\b\b  \b\b\b\b%${width_checkmark}b" "$green_checkmark"

# addons/hw_drivers files
loading "addons/hw_drivers" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/controllers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/controllers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/tools/helpers.py pi@${ip}:/home/pi/odoo/addons/hw_drivers/tools/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/interfaces/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/interfaces/
kill $loading_pid >/dev/null 2>&1
printf "\b\b\b\b\b  \b\b\b\b%${width_checkmark}b" "$green_checkmark"

# addons/point_of_sale/tools/posbox/configuration/
loading "posbox/configuration" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/point_of_sale/tools/posbox/configuration/* pi@${ip}:/home/pi/odoo/addons/point_of_sale/tools/posbox/configuration/
kill $loading_pid >/dev/null 2>&1
printf "\b\b\b\b\b  \b\b\b\b%${width_checkmark}b" "$green_checkmark"
# --------------------------------


# ------ MANUAL SECOND ARGUMENT STUFF ------
center_print "Restart / Reboot / Manual / Copy"
# If no argument is provided, restart odoo on the IoT box
if [ -z "${manu}" ] ; then
    loading "Restart Odoo server" &
    loading_pid=$!
    sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo restart'
    kill $loading_pid >/dev/null 2>&1
    printf "\b\b\b\b\b  \b\b\b\b%${width_checkmark}b" "$green_checkmark"

# If argument is 'scp' only copy files without restarting
elif [ "${manu}" = "scp" ] ; then
    loading "Don't start Odoo server" &
    loading_pid=$!
    kill $loading_pid >/dev/null 2>&1
    printf "\b\b\b\b\b  \b\b\b\b%${width_checkmark}b" "$green_checkmark"

# If argument is 'reboot', reboot the box after copying
elif [ "${manu}" = "reboot" ] ; then
    loading "Reboot IoT Box" &
    loading_pid=$!
    sshpass -p "raspberry" ssh pi@${ip} 'sudo reboot'
    kill $loading_pid >/dev/null 2>&1
    printf "\b\b\b\b\b  \b\b\b\b%${width_checkmark}b" "$green_checkmark"

# If argument is 'manual', start Odoo manually on the IoT box
elif [ "${manu}" = "manual" ] ; then
    echo "Start Odoo manually"
    sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo stop'
    sshpass -p "raspberry" ssh pi@${ip} 'odoo/./odoo-bin --load=web,hw_proxy,hw_posbox_homepage,hw_escpos,hw_drivers --limit-time-cpu=600 --limit-time-real=1200 --max-cron-threads=0'
fi

printf "\n=========================================\n\n"
