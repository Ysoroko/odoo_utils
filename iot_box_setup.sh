#!/bin/bash

# Script arguments
# "ip": IoT Box ip address
# "manu": action to do after the setup and files copy to the IoT box
ip=${1}
manu=${2}

# Possible arguments for second argument "manu":
#   - not provided  --> copy files and restart Odoo on the IoT box
#   - 'scp'         --> only copy files without restarting Odoo on the IoT box
#   - 'reboot'      --> copy files and then reboot the IoT box
#   - 'manual'      --> copy files and start Odoo manually in the terminal on the IoT box

# ============================== VARIABLES ==============================

# Repositories paths
ODOO_ADDONS_DIR='/home/odoo/src/odoo/addons'
ENTERPRISE_DIR='/home/odoo/src/enterprise'


# --- Text Utils ---
# Colors
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
cyan=$(tput setaf 6)
magenta=$(tput setaf 5)

# Size utils
termwidth=50
width_text=30
width_checkmark=10

# Special Symbols
checkmark="\xE2\x9C\x94"
crossmark="\xe2\x9c\x95"
green_checkmark="\t[${green}$checkmark${normal}]\n"
red_crossmark="\t[${red}$crossmark${normal}]\n"
# ------

# ============================== FUNCTIONS ==============================

# Print out argument with cenered output surrounded by "="
function center_print() {
    padding="$(printf '%0.1s' ={1..500})"
    printf '\n%*.*s %s %*.*s\n\n' 0 "$(((termwidth-2-${#1}-${#2})/2))" "$padding" "${cyan}$1${normal} ${magenta}$2${normal}" 0 "$(((termwidth-1-${#1}-${#2})/2))" "$padding"
}

# Display loading spinster and green checkmard when finished
function loading() {
    spin='-\|/'
    colour=${magenta}

    local delay=0.075 # Animation refresh frequency
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

# Checks the exit status of the last ran command
# If it succeded, displays a green checkmark
# If it failed, displays a red crossmark
function check_status() {
    let last_command_status=$?

    if [ $last_command_status -eq 0 ]; then
        if [ $# -eq 1 ]; then
            printf "%-${width_text}b" "  - $1"
        else
            kill $2 >/dev/null 2>&1
            printf "\b\b\b\b\b  \b\b\b\b"
        fi
        printf "%-${width_checkmark}b" "$green_checkmark"
    else
        if [ $# -eq 1 ]; then
            printf "%-${width_text}b" "  - $1"
        else
            kill $2 >/dev/null 2>&1
            printf "\b\b\b\b\b  \b\b\b\b"
        fi
        printf "%-${width_checkmark}b" "$red_crossmark"
    fi
}

# ============================== SCRIPT ==============================

# ------ PING IOT BOX ------
center_print "Connecting to IoT Box"
ping ${1} -c 1 &> /dev/null
check_status "IoT box reachable"

# ------ IOT BOX SETUP ------
center_print "Setting up the IoT Box"
ssh-keyscan -H ${ip} >> ~/.ssh/known_hosts >/dev/null 2>&1
check_status "IoT added to known hosts"
ssh-keygen -f "/home/odoo/.ssh/known_hosts" -R ${ip} >/dev/null 2>&1
check_status "IoT ssh key generated"

sshpass -p "raspberry" ssh pi@${ip} 'sudo killall python3' >/dev/null 2>&1
check_status "Python on IoT box stopped"
sshpass -p "raspberry" ssh pi@${ip} 'sudo mount -o remount,rw /' >/dev/null 2>&1
check_status "IoT box set to write mode"

# ------ TRANSFER FILES TO IOT BOX ------
center_print "Sending files to" "${1}"

# addons/hw_posbox_homepage files
loading "addons/hw_posbox_homepage" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_posbox_homepage/controllers/main.py pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/controllers/ >/dev/null 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_posbox_homepage/views/* pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/views/ >/dev/null 2>&1
check_status "" $loading_pid

# addons/hw_drivers files
loading "addons/hw_drivers" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/controllers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/controllers/ >/dev/null 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/ >/dev/null 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/tools/helpers.py pi@${ip}:/home/pi/odoo/addons/hw_drivers/tools/ >/dev/null 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/ >/dev/null 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/interfaces/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/interfaces/ >/dev/null 2>&1
check_status "" $loading_pid

# addons/point_of_sale/tools/posbox/configuration/ files
loading "posbox/configuration" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/point_of_sale/tools/posbox/configuration/* pi@${ip}:/home/pi/odoo/addons/point_of_sale/tools/posbox/configuration/ >/dev/null 2>&1
check_status "" $loading_pid
# --------------------------------

# ------ MANUAL SECOND ARGUMENT STUFF ------
center_print "Restart / Reboot / Manual / Copy"
# If no argument is provided, restart odoo on the IoT box
if [ -z "${manu}" ] ; then
    sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo restart' >/dev/null 2>&1
    check_status "Restart Odoo server"

# If argument is 'scp' only copy files without restarting
elif [ "${manu}" = "scp" ] ; then
    check_status "Only copy files"

# If argument is 'reboot', reboot the box after copying
elif [ "${manu}" = "reboot" ] ; then
    sshpass -p "raspberry" ssh pi@${ip} 'sudo reboot' >/dev/null 2>&1
    check_status "Reboot IoT Box"

# If argument is 'manual', start Odoo manually on the IoT box
elif [ "${manu}" = "manual" ] ; then
    sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo stop' >/dev/null 2>&1
    sshpass -p "raspberry" ssh pi@${ip} 'odoo/./odoo-bin --load=web,hw_proxy,hw_posbox_homepage,hw_escpos,hw_drivers --limit-time-cpu=600 --limit-time-real=1200 --max-cron-threads=0'
    check_status "Start Odoo Manually"
fi

printf "\n===================================================\n\n"
