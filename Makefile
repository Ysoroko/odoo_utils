# ------------------------------------- CMDS ----------------------------------

# PSQL:
# -----
# dropdb [db_name]

# Kill localhost process:
# sudo lsof -iTCP:8069 -sTCP:LISTEN
# kill [pid]
# kill -9 [pid] if 1st command doesn't work

# GIT:
# git branch --delete [branch_name]

# Working with the IoT Box:

# -------------------------
# sudo ssh pi@[ip]
# sudo mount -o remount,rw /
# sudo scp file.txt pi@[ip]:/remote/directory/
# ex: /home/pi/odoo/addons/hw_posbox_homepage/views
# command to get ip address on the terminal of pi: "ip addr"
# log file: cat /var/log/odoo/odoo-server.log
# find file: find . -name 'PrinterDriver.py'

# launch Odoo on IoT Box
# ./odoo-bin --load=web,hw_posbox_homepage,hw_drivers --data-dir=/var/run/odoo --max-cron-threads=0 --log-level critical

# HTTP->HTTPS: https://[iot_box ip]     !without :8069
# On database: replace 'web' by 'ui'

# -------------------------------------VARS ----------------------------------

EXECUTABLE 		=	./odoo/odoo-bin

C_ADDONS_ONLY	=	--addons-path=./odoo/addons

ADDONS 			= 	--addons-path=./enterprise/,./odoo/addons

MODULES 		= 	pos_iot,iot,l10n_be,point_of_sale,pos_restaurant

# ----- DATABASES
DB 				= 	-d demo

DB_COMMUNITY	=	-d community

DB_NO_DEMO 		= 	-d no_demo --without-demo $(MODULES)

DB_NO_DEMO_C	=	-d c_no_demo --without-demo $(MODULES)
# -----

NO_LOG			=	--log-level error

INSTALL_MODULES = 	-i $(MODULES)

UPDATE_MODULES 	= 	-u $(MODULES)

RUN				=	$(EXECUTABLE) $(ADDONS) $(DB) $(INSTALL_MODULES) $(UPDATE_MODULES)

RUN_COMMUNITY	=	$(EXECUTABLE) $(C_ADDONS_ONLY) $(DB) $(INSTALL_MODULES) $(UPDATE_MODULES)

# ------------------------------------- RULES ---------------------------------

all: normal

normal:
	$(RUN) $(DB)

community:
	$(RUN_COMMUNITY) $(DB_COMMUNITY)

c_no_demo:
	$(RUN_COMMUNITY) $(DB_NO_DEMO_C)

no_demo:
	$(RUN) $(DB_NO_DEMO)


.PHONY: all normal no_demo
