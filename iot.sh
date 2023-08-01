#!/bin/bash

# ============================== DESCRIPTION ==============================
# This script is used to work with Odoo Raspberry Pi IoT Boxes
# With it you can:
#   - Check the IoT Box status
#   - Copy your local code to the IoT Box
#   - Restart Odoo / Reboot the IoT Box / Start Odoo through the command line
#
# Before running it you might need to adapt the "VARIABLES" section below
# to your paths and IoT Box password
#
# Examples:
#   sudo ./iot_box_setup.sh 10.100.66.148 -> copies local files to the IoT Box and restarts Odoo on it
#   sudo ./iot_box_setup.sh 10.100.66.148 status -> checks the status of the IoT Box and Odoo on it
#   sudo ./iot_box_setup.sh 10.100.66.148 copy verbos -> only copies files and produces a verbose output

# ============================== ARGUMENTS ==============================
# "iot_box_ip": IoT Box ip address (required) in format like "10.100.66.148"
# "action": action to do after the setup and files copy to the IoT box (optional)
# "verbose": if the third argument is equal to "verbose", display verbose commands output (optional)

iot_box_ip=${1}
action=${2}
verbose=${3}

# Possible arguments for second argument "action":
#   - not provided/anything --> copy files and restart Odoo on the IoT box
#   - 'copy' or 'scp'       --> only copy files without restarting Odoo on the IoT box
#   - 'reboot'              --> copy files and then reboot the IoT box
#   - 'manual'              --> copy files and start Odoo manually in the terminal on the IoT box
#   - 'log'                 --> output iot box's odoo log file
#   - 'status'              --> only check if Odoo is running on the IoT Box, not copy anything
#   - 'write'               --> set iot to write mode (TO DO)
#   - 'clean_log'           --> only clear the log file

# ============================== VARIABLES ==============================

# Repositories Paths
# /!\ Change these to your corresponding paths if needed

# Local paths on your computer
LOCAL_ODOO_ADDONS_PATH='/home/odoo/src/odoo/addons'
LOCAL_ENTERPRISE_IOT_HANDLERS_PATH='/home/odoo/src/enterprise/iot/iot_handlers'
LOCAL_SIX_IOT_HANDLERS_PATH='/home/odoo/src/enterprise/pos_iot_six/iot_handlers'
LOCAL_KNOWN_HOSTS_DIR='/root/.ssh/known_hosts'

# Remote paths on the IoT Box (normally these shouldn't be changed)
IOT_BOX_LOG_FILE_PATH='/var/log/odoo/odoo-server.log'
IOT_BOX_ADDONS_PATH='/home/pi/odoo/addons'


# DEPENDENCIES TO INSTALL:
# jq
# sshpassq

# ============================== COMMANDS ==============================
# SSH
# Without this option 'ssh' command will be automatically be rejected:
STRICT_HOSTKEY_CHECKING='-o StrictHostKeyChecking=no'

#-q = "Quiet mode"
SSH_FLAGS="-q ${STRICT_HOSTKEY_CHECKING}"

# --- NGROK Utils ---
# NGROK_PORT="14836"
# SSH_FLAGS="-q ${STRICT_HOSTKEY_CHECKING} -p ${NGROK_PORT} -v"
# IOT_BOX_LOG_FILE_PATH='/root_bypass_ramdisks/etc/cups/odoo-server.log'

SSH="ssh $SSH_FLAGS pi@${iot_box_ip}"
# ssh -q -o StrictHostKeyChecking=no'



# --- Text Utils ---
# Colors
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
cyan=$(tput setaf 6)
magenta=$(tput setaf 5)
bold=$(tput bold)

# Size utils
# let termwidth=$(tput cols)-1
# let width_text=$termwidth-15
# let width_checkmark=10
let termwidth=50
let width_text=30
let width_checkmark=10

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
    printf "\n"
    printf "="'%.s' $(eval "echo {1.."$(($termwidth+1))"}");
    printf "\n\n"
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
    error_and_exit "No IoT Box ip address given as argument"
fi

# If the script is ran without root access, stop and require it
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
center_print "Connecting to" "${iot_box_ip}"
ping ${1} -c 1 -w 3 >$redirection 2>&1
check_status "IoT box reachable"
if [ $last_command_status -ne 0 ]; then
    error_and_exit "Failed to reach the IoT Box"
fi

# ------ IOT BOX SETUP ------
center_print "Setting up the IoT Box"

# ssh-keygen -f /root/.ssh/known_hosts -R 192.168.68.61
# ssh-keyscan -H 192.168.68.61 >> /root/.ssh/known_hosts >$redirection 2>&1

ssh-keyscan -H ${iot_box_ip} >> /root/.ssh/known_hosts >$redirection 2>&1
check_status "IoT added to known hosts"
ssh-keygen -f ${LOCAL_KNOWN_HOSTS_DIR} -R ${iot_box_ip} >$redirection 2>&1
check_status "IoT ssh key generated"

#SSH = 

# IoT Box password
# 1. Try to connect using 'raspberry' as password
PASSWORD="raspberry"
sshpass -p ${PASSWORD} ${SSH} exit
# If it works, keep "raspberry" as password
if [[ $? -eq 0 ]]; then
    check_status "IoT Password: ${bold}${PASSWORD}${normal}"
# Otherwise regenerate a new password and change it to "raspberry"
else
    PASSWORD="dummy_password"
    sshpass -p "dummy_password" ${SSH} exit
    if [[ $? -eq 0 ]]; then
        check_status "IoT Password: ${bold}${PASSWORD}${normal}"
    else
        json='{"params": {"action": "view"}}'
        url="http://${iot_box_ip}:8069/hw_posbox_homepage/password"
        PASSWORD=$(curl -sX POST -H "Content-Type: application/json" -d "${json}" "${url}" | jq -r '.result')
        check_status "IoT Password: ${bold}${PASSWORD}${normal}"
    fi
    # Change password to "raspberry"
    ENCRYPTED_PASSWORD=$(openssl passwd raspberry 2>/dev/null)
    sshpass -p ${PASSWORD} ${SSH} "sudo usermod -p ${ENCRYPTED_PASSWORD} pi" >$redirection 2>&1
    check_status "Reset password to ${bold}raspberry${normal}"
    PASSWORD="raspberry"
    sshpass -p ${PASSWORD} ${SSH} 'sudo mount -o remount,rw "/root_bypass_ramdisks/"' >$redirection 2>&1
    sshpass -p ${PASSWORD} ${SSH} 'sudo cp /etc/shadow /root_bypass_ramdisks/etc/shadow' >$redirection 2>&1
fi

# SSHPASS VARIABLES
check_status "PASSWORD:[${PASSWORD}]"
SSHPASS_FLAGS="-p ${PASSWORD}"
SSHPASS="sshpass ${SSHPASS_FLAGS}"
${SSHPASS} ${SSH} 'pgrep python' >$redirection 2>&1
check_status "Odoo running on IoT Box"
if [ "${action}" = "status" ] ; then
    line_print
    exit 0
fi

# ------ ODOO LOG FILE ------
if [ "${action}" = "log" ] ; then
    center_print "Odoo log file from" "${iot_box_ip}"
    ${SSHPASS} ${SSH} cat ${IOT_BOX_LOG_FILE_PATH}
    line_print
    exit 0
fi

${SSHPASS} ${SSH} 'sudo killall python3' >$redirection 2>&1
check_status "Python on IoT box stopped"

${SSHPASS} ${SSH} 'sudo mount -o remount,rw /' >$redirection 2>&1
check_status "IoT box set to write mode"

${SSHPASS} ${SSH} 'sudo rm -rf /tmp_ram/*' >$redirection 2>&1
check_status "Cleaned up memory"

${SSHPASS} ${SSH} "echo '' > ${IOT_BOX_LOG_FILE_PATH}" >$redirection 2>&1
check_status "Reset Odoo logs"


# ------ TRANSFER FILES TO IOT BOX ------
center_print "Sending files to" "${iot_box_ip}"

# addons/hw_posbox_homepage files
# loading "addons/hw_posbox_homepage" &
# loading_pid=$!
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_posbox_homepage/controllers/main.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_posbox_homepage/controllers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_posbox_homepage/views/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_posbox_homepage/views/ >$redirection 2>&1
# check_status "" $loading_pid

# # addons/hw_drivers files
# loading "addons/hw_drivers" &
# loading_pid=$!
# # sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/controllers/* pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/controllers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_drivers/tools/helpers.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/tools/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_drivers/driver.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/hw_drivers/controllers/driver.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/controllers/ >$redirection 2>&1

# check_status "" $loading_pid

# enterprise/iot/iot_handlers/drivers and interfaces files
# loading iot/iot_handlers &
# loading_pid=$!
# sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/controllers/* pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/controllers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/drivers/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/interfaces/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/lib/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/lib/ >$redirection 2>&1
# check_status "" $loading_pid

# # addons/point_of_sale/tools/posbox/configuration/ files
# loading "posbox/configuration" &
# loading_pid=$!
# ${SSHPASS} scp ${LOCAL_ODOO_ADDONS_PATH}/point_of_sale/tools/posbox/configuration/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/point_of_sale/tools/posbox/configuration/ >$redirection 2>&1
# check_status "" $loading_pid

# loading iot/iot_handlers &

# loading_pid=$!
# sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/controllers/* pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/controllers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/drivers/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/interfaces/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/lib/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/lib/ >$redirection 2>&1
# check_status "" $loading_pid

# Worldline CTEP
# Overwrite the CTEP library on the IoT box with our own

# center_print "Worldline CTEP"

# loading "worldline Python (old)" &
# loading_pid=$!
# sshpass -p "raspberry" ssh pi@${iot_box_ip} 'sudo rm -rf /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep' >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/interfaces/CTEPInterface.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/drivers/WorldlineDriver.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/lib/load_worldline_library.sh pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/lib/ >$redirection 2>&1

# check_status "" $loading_pid

# loading "worldline Python" &
# loading_pid=$!
# # sshpass -p "raspberry" ssh pi@${iot_box_ip} 'sudo rm -rf /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep' >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/interfaces/CTEPInterface_L.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/drivers/WorldlineDriver_L.py pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_ENTERPRISE_IOT_HANDLERS_PATH}/lib/load_worldline_library.sh pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/lib/ >$redirection 2>&1

# check_status "" $loading_pid

# # --> v16
# loading "worldline C++" &
# loading_pid=$!
# sshpass -p "raspberry" sudo scp -r /home/odoo/src/worldline-lib/ctep_l pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib >$redirection 2>&1
# sshpass -p "raspberry" ssh pi@${iot_box_ip} "sudo make -sC '/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep_l/'" >$redirection 2>&1
# check_status "" $loading_pid

# sshpass -p "raspberry" ssh pi@${iot_box_ip} "sudo mv /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep_l /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep"
# check_status "Rename ctep_l to ctep"

# sshpass -p "raspberry" ssh pi@${iot_box_ip} 'sudo rm -rf /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep' >$redirection 2>&1
# check_status "Removed old ctep"

# sshpass -p "raspberry" ssh pi@${iot_box_ip} 'sudo rm -rf /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep_l' >$redirection 2>&1
# check_status "Removed old ctep_l"

# master -->
# loading "Worldline ctep sent to IoT" &
# loading_pid=$!
# sshpass -p "raspberry" sudo scp -r /home/odoo/src/worldline-lib/ctep_l pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib >$redirection 2>&1
# check_status "" $loading_pid


# loading "Run Worldline Makefile" &
# loading_pid=$!
# sshpass -p "raspberry" ssh pi@${iot_box_ip} "sudo make -sC '/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep_l/'" >$redirection 2>&1

# # rename 'ctep_l' to 'ctep'
# sshpass -p "raspberry" ssh pi@${iot_box_ip} "sudo mv /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep_l /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep"
# check_status "Rename ctep_l to ctep" $loading_pid
# # copy all the dependencies files
# sshpass -p "raspberry" sudo scp /home/odoo/src/worldline-lib/ctep_l/lib/* pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ctep >$redirection 2>&1
# check_status "Rename ctep_l to ctep" $loading_pid


# Six TIM Api
# Overwrite the Tim Api library on the IoT box with our own
# Copy dynamic library from IoT Box:
# sudo scp pi@10.100.66.151:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/tim/libsix_odoo_l.so .
# sudo scp pi@192.168.1.11:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/tim/libsix_odoo_l.so .

# center_print "Six TIM Api"

# enterprise/pos_six/iot_handlers/drivers and interfaces files
# loading pos_iot_six/iot_handlers &
# loading_pid=$!
# # sshpass -p "raspberry" scp ${ODOO_ADDONS_PATH}/hw_drivers/controllers/* pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/controllers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_SIX_IOT_HANDLERS_PATH}/drivers/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/drivers/ >$redirection 2>&1
# ${SSHPASS} scp ${LOCAL_SIX_IOT_HANDLERS_PATH}/interfaces/* pi@${iot_box_ip}:${IOT_BOX_ADDONS_PATH}/hw_drivers/iot_handlers/interfaces/ >$redirection 2>&1
# check_status "" $loading_pid

# loading "Delete Tim on IoT" &
# loading_pid=$!
# sshpass -p "raspberry" ssh pi@${iot_box_ip} 'sudo rm -rf /home/pi/odoo/addons/hw_drivers/iot_handlers/lib/tim' >$redirection 2>&1
# check_status "" $loading_pid

# sshpass -p "raspberry" ssh pi@${iot_box_ip} "sudo rm -rf /usr/lib/libtimapi.*" >$redirection 2>&1
# check_status "Unlink TIM dependencies"

# ${SSHPASS} ${SSH} 'sudo mount -o remount,rw /' >$redirection 2>&1
# check_status "IoT box set to write mode"

# loading "Send TIM to IoT" &
# loading_pid=$!
# sshpass -p "raspberry" sudo scp -r /home/odoo/src/worldline-lib/tim pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/ >$redirection 2>&1
# check_status "" $loading_pid

# ${SSHPASS} ${SSH} 'sudo mount -o remount,rw /' >$redirection 2>&1
# check_status "IoT box set to write mode"

# loading "Run TIM Makefile" &
# loading_pid=$!
# sshpass -p "raspberry" ssh pi@${iot_box_ip} "sudo make -sC '/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/tim/'" >$redirection 2>&1
# check_status "" $loading_pid

# loading "Copy dependecy lib" &
# loading_pid=$!
# sshpass -p "raspberry" sudo scp /home/odoo/src/worldline-lib/tim/lib_rpi/libtimapi.so.3.31.1-2272 pi@${iot_box_ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/lib/tim >$redirection 2>&1
# check_status "" $loading_pid
#--------------------------------

# ------ RESTART / REBOOT / MANUAL / COPY ------
center_print "Restart / Reboot / Manual / Copy"

# If action is 'copy' only copy files without restarting
if [ "${action}" = "copy" ] || [ "${action}" = "scp" ] ; then
    check_status "Only copy files"

# If action is 'reboot', reboot the box after copying
elif [ "${action}" = "reboot" ] ; then
    ${SSHPASS} ${SSH} 'sudo reboot' >$redirection 2>&1
    check_status "Reboot IoT Box"

# If action is 'manual', start Odoo manually on the IoT box
elif [ "${action}" = "manual" ] ; then
    check_status "Start Odoo manually on IoT"
    ${SSHPASS} ${SSH} 'sudo service odoo stop' >$redirection 2>&1
    center_print "Output from Odoo on the IoT Box"
    sshpass -p "raspberry" ssh -t pi@${iot_box_ip} 'sudo odoo/./odoo-bin --load=web,hw_posbox_homepage,hw_drivers,hw_escpos --data-dir=/var/run/odoo --max-cron-threads=0'

# If no action or any other argument is provided, restart odoo on the IoT box
else
    ${SSHPASS} ${SSH} 'sudo service odoo restart' >$redirection 2>&1
    check_status "Restart Odoo server"
fi

line_print
