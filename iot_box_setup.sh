#!/bin/bash

# Script arguments
ip=${1}
manu=${2}

# Repositories paths
ODOO_ADDONS_DIR='/home/odoo/src/odoo/addons'
ENTERPRISE_DIR='/home/odoo/src/enterprise'

NOT_ENDED=1

# Calls echo with cenered output surrounded by "="
function center_print() {
    cyan=$(tput setaf 6)
    magenta=$(tput setaf 5)
    red=$(tput setaf 1)
    normal=$(tput sgr0)
    termwidth="$(tput cols)"
    padding="$(printf '%0.1s' ={1..500})"
    printf '\n%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "${cyan}$1${normal} ${magenta}$2${normal}" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

# Display loading spinster and green checkmard when finished
function loading() {
    pid=$! # Process Id of the previous running command

    spin='-\|/'
    yellow=$(tput setaf 5)
    normal=$(tput sgr0)
    green=$(tput setaf 2)
    width_checkmark=10
    width_text=30

    checkmark="\xE2\x9C\x94"
    green_checkmark="\t[${green}$checkmark${normal}]\n"

    i=0
    printf "%-${width_text}b" "  - $1"
    local pid=$!
    local delay=0.075
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "  [${yellow}%c${normal}]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "  \b\b\b\b%${width_checkmark}b" "$green_checkmark"
}

# ------
center_print "Setting up the IoT Box"
ssh-keygen -f "/home/odoo/.ssh/known_hosts" -R ${ip}
ssh-keyscan -H ${ip} >>~/.ssh/known_hosts

sshpass -p "raspberry" ssh pi@${ip} 'sudo killall python3'
sshpass -p "raspberry" ssh pi@${ip} 'sudo mount -o remount,rw /'
# ------
center_print "Sending files to" "${1}"
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_posbox_homepage/controllers/main.py pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/controllers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_posbox_homepage/views/* pi@${ip}:/home/pi/odoo/addons/hw_posbox_homepage/views/ 2>/dev/null &
loading "addons/hw_posbox_homepage/"
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/controllers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/controllers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/tools/helpers.py pi@${ip}:/home/pi/odoo/addons/hw_drivers/tools/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/drivers/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/drivers/
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/hw_drivers/iot_handlers/interfaces/* pi@${ip}:/home/pi/odoo/addons/hw_drivers/iot_handlers/interfaces/ 2>/dev/null &
loading "addons/hw_drivers"
sshpass -p "raspberry" scp ${ODOO_ADDONS_DIR}/point_of_sale/tools/posbox/configuration/* pi@${ip}:/home/pi/odoo/addons/point_of_sale/tools/posbox/configuration/ 2>/dev/null &
loading "posbox/configuration/"

# Manual second argument stuff
if [ -z "${manu}" ] ; then
echo "Restart Odoo server"
sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo restart'
elif [ "${manu}" = "scp" ] ; then
echo "Don't start Odoo server"
elif [ "${manu}" = "reboot" ] ; then
sshpass -p "raspberry" ssh pi@${ip} 'sudo reboot'
elif [ "${manu}" = "manual" ] ; then
echo "Manual starting of Odoo"
sshpass -p "raspberry" ssh pi@${ip} 'sudo service odoo stop'
sshpass -p "raspberry" ssh pi@${ip} 'odoo/./odoo-bin --load=web,hw_proxy,hw_posbox_homepage,hw_escpos,hw_drivers --limit-time-cpu=600 --limit-time-real=1200 --max-cron-threads=0' 
fi
