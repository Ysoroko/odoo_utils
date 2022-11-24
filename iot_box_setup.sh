#!/bin/bash

# ============================== ARGUMENTS ==============================
# "ip": IoT Box ip address (required)
# "manu": action to do after the setup and files copy to the IoT box (optional)
# "verbose": if the third argument is equal to "verbose", display info/error/debug messages (optional)

ip=${1}
manu=${2}
verbose=${3}

# Possible arguments for second argument "manu":
#   - not provided/anything --> copy files and restart Odoo on the IoT box
#   - 'scp'                 --> only copy files without restarting Odoo on the IoT box
#   - 'reboot'              --> copy files and then reboot the IoT box
#   - 'manual'              --> copy files and start Odoo manually in the terminal on the IoT box

# ============================== VARIABLES ==============================

# Repositories paths
# Change these to your corresponding paths if needed
ODOO_ADDONS_PATH='/home/odoo/src/odoo/addons'
KNOWN_HOSTS_DIR='/root/.ssh/known_hosts'


# --- Text Utils ---
# Colors
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
cyan=$(tput setaf 6)
magenta=$(tput setaf 5)
bold=$(tput bold)

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

# Print out argument with centered output surrounded by "="
function center_print() {
    padding="$(printf '%0.1s' ={1..500})"
    printf '\n%*.*s %s %*.*s\n\n' 0 "$(((termwidth-2-${#1}-${#2})/2))" "$padding" "${cyan}$1${normal} ${magenta}$2${normal}" 0 "$(((termwidth-1-${#1}-${#2})/2))" "$padding"
}

function line_print() {
    printf "\n===================================================\n\n"
}

# Display loading spinster until the process is "killed" from outside
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
# If it succeded (exit code = 0), displays a green checkmark
# If it failed (exit code != 0), displays a red crossmark
#
# Accepts two arguments:
#   1) The description to display (ex: "IoT box reachable")
#   2) The process id of the "loading" function call to kill (optional)
function check_status() {
    let last_command_status=$?

    if [[ $last_command_status -eq 0 ]] || [[($last_command_status -eq 255 && $1="Reboot IoT Box") ]]; then
        symbol=$green_checkmark
    else
        symbol=$red_crossmark
    fi

    if [ $# -eq 1 ]; then
        printf "%-${width_text}b" "  - $1"
    else
        kill $2 >/dev/null 2>&1
        printf "\b\b\b\b\b  \b\b\b\b"
    fi
    printf "%-${width_checkmark}b" "$symbol"
}

# Display error message and stops the script
function error_and_exit() {
    printf "\n${bold}${red}Error:${normal}\t $1\n"
    line_print
    exit 1
}

# ============================== SCRIPT ==============================

line_print

# ------ ARGUMENTS SETUP ------
# If no arguments is provided, ask the user to give the Iot Box ip address
if [ $# -eq 0 ]; then
    error_and_exit "No IoT box ip address given as argument"
fi

if [ "$EUID" -ne 0 ]; then
    error_and_exit "Please run this script with 'sudo'"
fi

# Show commands messages only if the third argument is "verbose"
if [ "${verbose}" = 'verbose' ]; then
    redirection="/dev/stderr"
else
    redirection="/dev/null"
fi

# ------ PING IOT BOX ------
center_print "Connecting to IoT Box"
ping ${1} -c 1 -w 3 >$redirection 2>&1
check_status "IoT box reachable"
if [ $last_command_status -ne 0 ]; then
    error_and_exit "IoT box is unreachable at this moment"
fi

# ------ IOT BOX SETUP ------
center_print "Setting up the IoT Box"

ssh-keyscan -H ${ip} >> ~/.ssh/known_hosts >$redirection 2>&1
check_status "IoT added to known hosts"
ssh-keygen -f ${KNOWN_HOSTS_DIR} -R ${ip} >$redirection 2>&1
check_status "IoT ssh key generated"

sshpass -p "raspberry" ssh -o StrictHostKeyChecking=no pi@${ip} 'sudo killall python3' >$redirection 2>&1
check_status "Python on IoT box stopped"
sshpass -p "raspberry" ssh pi@${ip} 'sudo mount -o remount,rw /' >$redirection 2>&1
check_status "IoT box set to write mode"

# ------ TRANSFER FILES TO IOT BOX ------
center_print "Sending files to" "${1}"

# addons/hw_posbox_homepage files
loading "addons/hw_posbox_homepage" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_posbox_homepage/controllers/main.py pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/controllers/ >$redirection 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_posbox_homepage/views/* pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/views/ >$redirection 2>&1
check_status "" $loading_pid

# addons/hw_drivers files
loading "addons/hw_drivers" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/controllers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/controllers/ >$redirection 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/tools/helpers.py pi@${ip}:/home/pi/odoo/addons/hw_drivers/tools/ >$redirection 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
check_status "" $loading_pid

# addons/point_of_sale/tools/posbox/configuration/ files
loading "posbox/configuration" &
loading_pid=$!
sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/point_of_sale/tools/posbox/configuration/* pi@${ip}:/home/pi/odoo/addons/point_of_sale/tools/posbox/configuration/ >$redirection 2>&1
check_status "" $loading_pid
# --------------------------------

# ------ MANUAL SECOND ARGUMENT STUFF ------
center_print "Restart / Reboot / Manual / Copy"

# If argument is 'scp' only copy files without restarting
if [ "${manu}" = "scp" ] ; then
    check_status "Only copy files"

# If argument is 'reboot', reboot the box after copying
elif [ "${manu}" = "reboot" ] ; then
    sshpass -p "raspberry" ssh pi@${ip} 'sudo reboot' >$redirection 2>&1
    check_status "Reboot IoT Box"

# If argument is 'manual', start Odoo manually on the IoT box
elif [ "${manu}" = "manual" ] ; then
    sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo stop' >$redirection 2>&1
    sshpass -p "raspberry" ssh pi@${ip} 'odoo/./odoo-bin --load=web,hw_proxy,hw_posbox_homepage,hw_escpos,hw_drivers --limit-time-cpu=600 --limit-time-real=1200 --max-cron-threads=0'
    check_status "Start Odoo Manually"
# If no argument or any other argument is provided, restart odoo on the IoT box
else
    sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo restart' >$redirection 2>&1
    check_status "Restart Odoo server"
fi

line_print
