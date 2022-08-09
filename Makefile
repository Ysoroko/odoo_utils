# ------------------------------------- CMDS ----------------------------------

# PSQL:
# -----
# psql [db_name]
# \l
# DROP DATABASE [db_name];

# Kill localhost process:
# sudo lsof -iTCP:8069 -sTCP:LISTEN
# kill [pid]
# kill -9 [pid] if 1st command doesn't work


# GIT:
# git branch --delete [branch_name]
# git amend
# git rebase [base]

# git fetch --all --prune
# git rebase --autostash  odoo/15.0

# Working with the IoT Box:

# -------------------------
# sudo ssh pi@[ip]
# sudo mount -o remount,rw /
# sudo scp file.txt pi@[ip]:/remote/directory/

# launch Odoo on IoT Box
# ./odoo-bin --load=web,hw_posbox_homepage,hw_drivers --data-dir=/var/run/odoo --max-cron-threads=0

# -------------------------------------VARS ----------------------------------

EXECUTABLE 		=	./odoo/odoo-bin

C_ADDONS_ONLY	=	--addons-path=./odoo/addons

ADDONS 			= 	--addons-path=./enterprise/,./odoo/addons

MODULES 		= 	point_of_sale,iot,l10n_be,pos_restaurant

DB 				= 	-d demo

DB_COMMUNITY	=	-d demo_community

DB_MASTER		=	-d db_master

DB_NO_DEMO 		= 	-d no_demo --without-demo $(MODULES)

DB_NO_DEMO_C	=	-d no_demo_community --without-demo $(MODULES)

INSTALL_MODULES = 	-i $(MODULES)

UPDATE_MODULES 	= 	-u $(MODULES)

RUN				=	$(EXECUTABLE) $(ADDONS) $(DB) $(INSTALL_MODULES) $(UPDATE_MODULES)

RUN_COMMUNITY	=	$(EXECUTABLE) $(C_ADDONS_ONLY) $(DB) $(INSTALL_MODULES) $(UPDATE_MODULES)

# ------------------------------------- RULES ---------------------------------

all: normal

normal:
	$(RUN) $(DB)

community:
	$(RUN_COMMUNITY) $(DB)

c_no_demo:
	$(RUN_COMMUNITY) $(DB_NO_DEMO_C)

master:
	$(RUN) $(DB_MASTER)

no_demo:
	$(RUN) $(DB_NO_DEMO)


.PHONY: all normal community c_no_demo master no_demo
