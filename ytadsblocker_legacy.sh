#!/bin/bash

# This script was made in order to block all the Youtube's advertisement in Pi-Hole

YTADSBLOCKER_VERSION="legacy"
YTADSBLOCKER_LOG="/var/log/ytadsblocker.log"
YTADSBLOCKER_GIT="https://raw.githubusercontent.com/deividgdt/ytadsblocker/master/ytadsblocker.sh"
SLEEPTIME="240"
DIR_LOG="/var/log"
PI_LOG="/var/log/pihole.log"
BLACKLST="/etc/pihole/blacklist.txt"
BLACKLST_TMP="/etc/pihole/blacklist.txt.TMP"
BLACKLST_BKP="/etc/pihole/blacklist.txt.BKP"
SERVICE_PATH="/lib/systemd/system"
SERVICE_NAME="ytadsblocker.service"
SCRIPT_NAME=$(basename $0)
PRINTWD=$(pwd)

# The followings vars are used in order to give some color to
# the different outputs of the script.
COLOR_R="\e[31m"
COLOR_Y="\e[33m"
COLOR_G="\e[32m"
COLOR_CL="\e[0m"

# The followings vars are used to point out the different 
# results of the process executed by the script
TAGINFO=$(echo -e "[i]") # [i] Information
TAGWARN=$(echo -e "[${COLOR_Y}w${COLOR_CL}]") # [w] Warning
TAGERR=$(echo -e "[${COLOR_R}✗${COLOR_CL}]") # [✗] Error
TAGOK=$(echo -e "[${COLOR_G}✓${COLOR_CL}]") # [✓] Ok

#If any command shows out an error code, the script ends
set -e

function CheckUser() {
	if [[ "$(id -u $(whoami))" != "0" ]]; then
		echo -e "${TAGERR} $(whoami) is not a valid user. The installation must be executed by the user: root."
		exit 1;
	else
		echo -e "${TAGOK} $(whoami) is a valid user."
	fi
}

function Makeservice () {

	cd $SERVICE_PATH && touch $SERVICE_NAME
	cat > $SERVICE_NAME <<-EOF
[Unit]
Description=Youtube ads blocker service for Pi-hole
After=network.target
[Service]
ExecStart=$PRINTWD/$SCRIPT_NAME start
ExecStop=$PRINTWD/$SCRIPT_NAME stop
[Install]
WantedBy=multi-user.target
	EOF

}

function Install() {
	
	CheckUser #We check if the root user is executing the script

	if [ ! -f $SERVICE_PATH/$SERVICE_NAME ]; then
		echo -e "${COLOR_R}__  ______  __  __________  ______  ______   ___    ____  _____"
		echo -e "\ \/ / __ \/ / / /_  __/ / / / __ )/ ____/  /   |  / __ \/ ___/"
		echo -e " \  / / / / / / / / / / / / / __  / __/    / /| | / / / /\__ \ "
		echo -e " / / /_/ / /_/ / / / / /_/ / /_/ / /___   / ___ |/ /_/ /___/ / "
		echo -e "/_/\____/\____/ ____ \______________________  |_/_____//____/"  
		echo -e "	   / __ )/ /   / __ \/ ____/ //_// ____/ __ \ "                 
		echo -e "	  / __  / /   / / / / /   / ,<  / __/ / /_/ / "                 
		echo -e "	 / /_/ / /___/ /_/ / /___/ /| |/ /___/ _, _/ "                  
		echo -e "	/_____/_____/\____/\____/_/ |_/_____/_/ |_| v${YTADSBLOCKER_VERSION}${COLOR_CL} by @deividgdt"   
		echo ""
		echo -e "${TAGINFO} Youtube Ads Blocker: INSTALLING..."; sleep 1
		echo -e "${TAGINFO} If you move the script to a different place, please run it again with the option 'install'";
		echo -e "${TAGINFO} You can check the logs in: $YTADSBLOCKER_LOG";
		echo -e "${TAGINFO} All the subdomains will be added to: $BLACKLST";
		echo -e "${TAGINFO} Every ${SLEEPTIME}s it reads: $PI_LOG"; sleep 3
		echo ""
		
		echo -ne "${TAGINFO} Installing the service..."; sleep 1
		Makeservice
		echo "OK. Service installed.";

		echo -ne "${TAGINFO} Enabling the service to start it automatically with the OS."; sleep 1
		systemctl enable ytadsblocker 1> /dev/null 2>&1
		echo "OK."

		echo "[$(date "+%F %T")] Youtube Ads Blocker has been installed. Welcome!" >> $YTADSBLOCKER_LOG 

		echo -e "${TAGINFO} Searching googlevideo.com subdomains inside the Pi-Hole's logs..."; sleep 1    
		
		cp $DIR_LOG/pihole.log* /tmp
		for GZIPFILE in $(ls /tmp/pihole.log*gz > /dev/null 2>&1); do 
			gunzip $GZIPFILE; 
		done
		
		if [ -f "${BLACKLST}" ]; then
			echo -ne "${TAGINFO} Backing up the ${BLACKLST} file..."; sleep 1
			cp $BLACKLST $BLACKLST_BKP
			echo "OK. Backup done."
		else
			echo -ne "${TAGINFO} Creating the ${BLACKLST} file..."; sleep 1
			touch $BLACKLST
			echo "OK. File created."
		fi
		
		echo -e "${TAGINFO} Adding googlevideo.com subdomains..."; sleep 1
		echo "[$(date "+%F %T")] Searching Googlevideo's subdomains in the logs..." >> $YTADSBLOCKER_LOG 
		ALL_DOMAINS=$(cat /tmp/pihole.log* | egrep --only-matching "r([0-9]{1,2})[^-].*\.googlevideo\.com" | sort | uniq)
		N_DOM=$(cat /tmp/pihole.log* | egrep --only-matching "r([0-9]{1,2})[^-].*\.googlevideo\.com" | sort | uniq | wc --lines)
		echo "[$(date "+%F %T")] We have found $N_DOM subdomain/s..." >> $YTADSBLOCKER_LOG 

		if [ ! -z "${ALL_DOMAINS}" ]; then
			for YTD in $ALL_DOMAINS; do
				echo "[$(date "+%F %T")] Adding the subdomain: $YTD" >> $YTADSBLOCKER_LOG 
			done

			pihole blacklist $ALL_DOMAINS

			sudo pihole updateGravity
			echo -e "${TAGOK} OK. $N_DOM subdomains added"
		else
			echo -e "${TAGWARN} No subdomains to add at the moment."
		fi
		
		echo -ne "${TAGINFO} Deleting temp..."; sleep 1
		rm --force /tmp/pihole.log*
		echo "OK. Temp deleted."; sleep 1
		echo -e "${TAGOK} Youtube Ads Blocker: INSTALLED..."; sleep 1
		echo ""
		echo -e "${TAGINFO} To start the service execute as follows: systemctl start ytadsblocker"; sleep 1

	else
		echo -e "${TAGWARN} Youtube Ads Blocker already installed..."; sleep 1
		echo -ne "${TAGINFO} Reinstalling the service..."; 
		Makeservice
		systemctl daemon-reload
		echo "OK. Reinstalled."
	fi

}

function Start() {
	
	echo "Youtube Ads Blocker Started"
	echo "Check the $YTADSBLOCKER_LOG file in order to get further information."

	echo "[$(date "+%F %T")] Youtube Ads Blocker Started" >> $YTADSBLOCKER_LOG

	while true; do
		
		echo "[$(date "+%F %T")] Checking ${PI_LOG}..." >> $YTADSBLOCKER_LOG
		
		YT_DOMAINS=$(cat /var/log/pihole.log | egrep --only-matching "r([0-9]{1,2})[^-].*\.googlevideo\.com" | sort | uniq)
		CURRENT_DOMAINS=$(cat $BLACKLST)
		NEW_DOMAINS=
		
		for YTD in $YT_DOMAINS; do
			if [[ ! $( grep "$YTD" "$BLACKLST" ) ]]; then
				NEW_DOMAINS="$NEW_DOMAINS $YTD"
				echo "[$(date "+%F %T")] New subdomain to add: $YTD" >> $YTADSBLOCKER_LOG
			fi
		done
		
		if [ -z $NEW_DOMAINS ]; then
			echo "[$(date "+%F %T")] No new subdomains to added." >> $YTADSBLOCKER_LOG
		else
			pihole blacklist $NEW_DOMAINS
			echo "[$(date "+%F %T")] All the new subdomains added." >> $YTADSBLOCKER_LOG
		fi
		
		COUNT=$(($COUNT + 1))
		sleep $SLEEPTIME;

	done

}

function Stop() {

	echo "Youtube Ads Blocker Stopped"
	echo "[$(date "+%F %T")] Youtube Ads Blocker Stopped" >> $YTADSBLOCKER_LOG
	kill -9 `pgrep ytadsblocker`

}

function Uninstall() {

	CheckUser #We check if the root user is executing the script

	echo -e "${TAGINFO} Uninstalling YouTube Ads Blocker. Wait..."
	
	echo -e "${TAGINFO} Disabling the service..."
	systemctl --now disable ytadsblocker 1> /dev/null 2>&1
	systemctl daemon-reload

	if [ -f ${SERVICE_PATH}/${SERVICE_NAME} ]; then 
		echo -e "${TAGINFO} Deleting the service file..."
		rm --force ${SERVICE_PATH}/${SERVICE_NAME};
	fi
	
	if [ -f ${YTADSBLOCKER_LOG} ]; then
		echo -e "${TAGINFO} Deleting the log file..."
		rm --force ${YTADSBLOCKER_LOG}; 
	fi
	

	if [[ $(egrep --invert-match "r([0-9]{1,2})[^-].*\.googlevideo\.com" ${BLACKLST}) ]]; then
		echo -e "${TAGINFO} Deleting the Googlevideo's subdomains from ${BLACKLST}"
		egrep --invert-match "r([0-9]{1,2})[^-].*\.googlevideo\.com" ${BLACKLST} > ${BLACKLST_TMP}
		mv --force ${BLACKLST_TMP} ${BLACKLST}	
	else
		>${BLACKLST}
	fi
	
	echo -e "${TAGINFO} Updating the Gravity in the Pi-hole..."
	pihole updateGravity
	
	echo -e "${TAGOK} YouTube Ads Blocker Uninstalled. Bye"
	kill -9 `pgrep ytadsblocker`

}

case "$1" in
	"install"   ) Install 	;;
	"start"     ) Start 	;;
	"stop"      ) Stop 	;;
	"uninstall" ) Uninstall ;;
	*           ) echo "That option does not exists. Usage: ./$SCRIPT_NAME [ install | start | stop | uninstall ]";;
esac
