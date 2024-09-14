# This Makefile needs to be placed in the parent directory of
# your 'odoo' and 'enterprise' directories (by default, 'src')
# It will look for the Odoo bin at './odoo/odoo-bin'

# ------------------------------------- CMDS ----------------------------------

# Kill localhost process:
# sudo lsof -iTCP:8069 -sTCP:LISTEN
# kill [pid]
# kill -9 [pid] if 1st command doesn't work

# GIT:
# git branch -m [old_name] [new_name]
# git branch --delete [branch_name]


# -------------------------
# sudo ssh pi@[ip]
# sudo mount -o remount,rw /
# sudo scp file.txt pi@[ip]:/remote/directory/1
# ex: /home/pi/odoo/addons/hw_posbox_homepage/views

# log file: \
cat /var/log/odoo/odoo-server.log

# reset log file \
echo "" > /var/log/odoo/odoo-server.log

# find file: find . -name 'PrinterDriver.py'

# launch Odoo on IoT Box \
./odoo-bin --load=web,hw_posbox_homepage,hw_drivers --data-dir=/var/run/odoo --max-cron-threads=0

# critical only \
./odoo-bin --load=web,hw_posbox_homepage,hw_drivers --data-dir=/var/run/odoo --max-cron-threads=0 --log-level critical


# Check space: \
du -h \
du -h --max-depth=1


# Log in as support: [client website]/_odoo/support

# -------------------------------------VARS ----------------------------------

# ----- PATHS -----
EXECUTABLE 		=	./odoo/odoo-bin

C_ADDONS_ONLY	=	--addons-path=./odoo/addons

ADDONS 			= 	--addons-path=./enterprise/,./odoo/addons


# ----- DATABASES -----
DB 				= 	-d master

DB15			= 	-d 15

DB16			=	-d 16

DB17			=	-d 17

DB18			=	-d 18

DB_NO_DEMO 		= 	-d no_demo --without-demo



# ----- MODULES -----

MODULES 		= 	pos_iot,l10n_be


# ----- OPTIONS -----

NO_LOG			=	--log-level error

INSTALL_MODULES = 	-i $(MODULES)

UPDATE_MODULES 	= 	-u $(MODULES)

DEV				=	--dev all


# ----- RUN COMMANDS -----

RUN				=	$(EXECUTABLE) $(ADDONS) $(INSTALL_MODULES) $(DEV) # $(UPDATE_MODULES) $(NO_LOG)

RUN_COMMUNITY	=	$(EXECUTABLE) $(C_ADDONS_ONLY) $(INSTALL_MODULES)


# ----- IP UTILS -----

# extract local ip address
MY_IP			=	$(shell ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($$2,a," ");print a[1]}')

LOCAL			=	"$(MY_IP):8069"



# ------------------------------------- RULES ---------------------------------
# Execute rules are running the following command behind the scenes:
# ./odoo/odoo-bin --addons-path=./enterprise/,./odoo/addons -i pos_iot,10n_be -d master

all: master

master:
	$(RUN) $(DB)

15:
	$(RUN) $(DB15)

16:
	$(RUN) $(DB16)

17:
	$(RUN) $(DB17)

18:
	$(RUN) $(DB18)

community:
	$(RUN_COMMUNITY) $(DB_COMMUNITY)

no_demo:
	$(RUN) $(DB_NO_DEMO)


# --- IP Utils Rules ---

# Show my ip address
ip:
	@echo $(MY_IP);

# Open new Chrome tab with our ip address
tab:
	@google-chrome $(LOCAL) >/dev/null 2>&1

# -------

.PHONY: all master 15 16 17 18 community no_demo ip tab
