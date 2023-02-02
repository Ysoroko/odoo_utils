# This Makefile needs to be placed in the parent directory of
# your 'odoo' and 'enterprise' directories (by default, 'src')
# It will look for the Odoo bin at './odoo/odoo-bin'

# ------------------------------------- CMDS ----------------------------------

# Kill localhost process:
# sudo lsof -iTCP:8069 -sTCP:LISTEN
# kill [pid]
# kill -9 [pid] if 1st command doesn't work

# GIT:
# git branch --delete [branch_name]

# Six Ips:
# 10.30.66.50
# 192.168.0.122
# 192.168.1.11
# 192.168.1.9 <--
#


# Working with the IoT Box:
# My IoT MAC address: e4:5f:01:9e:8f:a0

# -------------------------
# sudo ssh pi@[ip]
# sudo mount -o remount,rw /
# sudo scp file.txt pi@[ip]:/remote/directory/1
# ex: /home/pi/odoo/addons/hw_posbox_homepage/views
# ex2: /home/pi/odoo/addons/hw_drivers/iot_handlers/drivers
# ex3: /home/pi/odoo/addons/hw_drivers/iot_handlers/lib
# command to get ip address on the terminal of pi: "ip addr"
#
# Copy a directory: scp -r

# log file: \
cat /var/log/odoo/odoo-server.log

# reset log file \
echo "" > /var/log/odoo/odoo-server.log

# find file: find . -name 'PrinterDriver.py'

# launch Odoo on IoT Box \
./odoo-bin --load=web,hw_posbox_homepage,hw_drivers --data-dir=/var/run/odoo --max-cron-threads=0 --log-level critical

# launch Odoo on Windows IoT Box in python folder
# Beforehand, we need to modify "logfile" in odoo.conf (rename it to 'logfileee' for example) \
./python.exe ../server/odoo-bin -c ../server/odoo.conf

# HTTP->HTTPS:
# https://[iot_box ip]     !without :8069
# On database: replace 'web' by 'ui'

# Log in as support: [client website]/_odoo/support

# -------------------------------------VARS ----------------------------------


EXECUTABLE 		=	./odoo/odoo-bin

C_ADDONS_ONLY	=	--addons-path=./odoo/addons

ADDONS 			= 	--addons-path=./enterprise/,./odoo/addons

MODULES 		= 	pos_iot,l10n_be


# ----- DATABASES
DB 				= 	-d master

DB14			= 	-d 14

DB15			= 	-d 15

DB16			=	-d 16

DB_COMMUNITY	=	-d community

DB_NO_DEMO 		= 	-d no_demo --without-demo $(MODULES)

DB_NO_DEMO_C	=	-d c_no_demo --without-demo $(MODULES)

# -----

# you can add "$(NO_LOG)" at the end of any execution rule to only show error output
NO_LOG			=	--log-level error

INSTALL_MODULES = 	-i $(MODULES)

UPDATE_MODULES 	= 	-u $(MODULES)

RUN				=	$(EXECUTABLE) $(ADDONS) $(INSTALL_MODULES) # $(UPDATE_MODULES) $(NO_LOG)

RUN_COMMUNITY	=	$(EXECUTABLE) $(C_ADDONS_ONLY) $(INSTALL_MODULES)

# --- IP Utils ---

# extract local ip address
MY_IP			=	$(shell ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($$2,a," ");print a[1]}')

LOCAL			=	"$(MY_IP):8069"

# ------------------------------------- RULES ---------------------------------
# Execute rules are running the following command behind the scenes:
# ./odoo/odoo-bin --addons-path=./enterprise/,./odoo/addons -i pos_iot,10n_be -d master

all: master

master:
	$(RUN) $(DB)

14:
	$(RUN) $(DB14)

15:
	$(RUN) $(DB15)

16:
	$(RUN) $(DB16)

community:
	$(RUN_COMMUNITY) $(DB_COMMUNITY)

c_no_demo:
	$(RUN_COMMUNITY) $(DB_NO_DEMO_C)

no_demo:
	$(RUN) $(DB_NO_DEMO)


# --- IP Utils ---

# Show my ip address
ip:
	@echo $(MY_IP);

# Open new Chrome tab with our ip address
tab:
	@google-chrome $(LOCAL)

# -------

.PHONY: all normal 14 15 16 community c_no_demo no_demo ip tab
