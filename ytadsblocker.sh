#!/bin/bash

# This script was made in order to block all the Youtube's advertisement in Pi-Hole

YTADSBLOCKER_VERSION="2.0"
YTADSBLOCKER_LOG="/var/log/ytadsblocker.log"
YTADSBLOCKER_URL="https://raw.githubusercontent.com/deividgdt/ytadsblocker/master/ytadsblocker.sh"
VERSIONCHECKER_TIME="260"
SLEEPTIME="240"
DIR_LOG="/var/log"
PI_LOG="/var/log/pihole.log"
BLACKLST="/etc/pihole/blacklist.txt"
BLACKLST_BKP="/etc/pihole/blacklist.txt.BKP"
SERVICE_PATH="/usr/lib/systemd/system"
SERVICE_NAME="ytadsblocker.service"
SCRIPT_NAME=$(basename $0)
PRINTWD=$(pwd)

COLOR_R="\e[31m"
COLOR_Y="\e[33m"
COLOR_G="\e[32m"
COLOR_CL="\e[0m"

#If any command shows out an error code, the script ends
set -e

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
		echo "[+] Youtube Ads Blocker: INSTALLING..."; sleep 1
		echo "[i] If you move the file to some diferent place, please run it again with the 'install' option ";
		echo "[i] You can check the logs at: $YTADSBLOCKER_LOG";
		echo "[i] All the subdomains will be added to: $BLACKLST";
		echo "[i] Every ${SLEEPTIME}s it reads: $PI_LOG"; sleep 3
		echo ""
		echo -ne "[+] Installing the service..."; sleep 1
		Makeservice
		echo "OK. Service installed.";

		echo -n "[+] Enabling the service to start it automatically with the OS."; sleep 1
		systemctl enable ytadsblocker 1> /dev/null 2>&1
		echo "OK."

		echo "[+] Searching googlevideo.com subdomains inside the Pi-Hole's logs..."; sleep 1    
		
		cp $DIR_LOG/pihole.log.* /tmp
		gunzip /tmp/pihole.log.*.gz
		
		echo -n "[+] Backing up the ${BLACKLST} file..."; sleep 1
		cp $BLACKLST $BLACKLST_BKP
		echo "OK. Backup done."
		
		echo -n "[+] Adding googlevideo.com subdomains..."; sleep 1
		ALL_DOMAINS=$(cat /tmp/pihole.log* | egrep -o "r([0-9]{1,2})[^-].*\.googlevideo\.com" /var/log/pihole.log | sort | uniq)
		
		for YTD in $ALL_DOMAINS; do
			echo "[$(date "+%F %T")] New subdomain to add: $YTD" >> $YTADSBLOCKER_LOG 
		done

		pihole -b $ALL_DOMAINS
		
		N_DOM=$(cat /tmp/pihole.log* | egrep -o "r([0-9]{1,2})[^-].*\.googlevideo\.com" /var/log/pihole.log | sort | uniq | wc -l)
		sudo pihole -g
		echo "[i] OK. $N_DOM subdomains added"
		
		echo -n "[+] Deleting temp..."; sleep 1
		rm -f /tmp/pihole.log*
		echo "OK. Temp deleted."; sleep 1
		echo "[i] Youtube Ads Blocker: INSTALLED..."; sleep 1
		echo ""
		echo "[i] To start the service execute as follows: systemctl start ytadsblocker"; sleep 1

	else
		echo "[w] Youtube Ads Blocker already installed..."; sleep 1
		echo -n "[+] Reinstalling the service..."; 
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
		
		echo "[$(date "+%F %T")] Checking..." >> $YTADSBLOCKER_LOG
		
		YT_DOMAINS=$(egrep -o "r([0-9]{1,2})[^-].*\.googlevideo\.com" /var/log/pihole.log | sort | uniq)
		CURRENT_DOMAINS=$(cat $BLACKLST)
		NEW_DOMAINS=
		
		for YTD in $YT_DOMAINS; do
			if [[ ! $( grep "$YTD" $BLACKLST ) ]]; then
				NEW_DOMAINS="$NEW_DOMAINS $YTD"
				echo "[$(date "+%F %T")] New subdomain to add: $YTD" >> $YTADSBLOCKER_LOG
			fi
		done
		
		if [ -z $NEW_DOMAINS ]; then
			echo "[$(date "+%F %T")] No new subdomains to added." >> $YTADSBLOCKER_LOG
		else
			pihole -b $NEW_DOMAINS
			echo "[$(date "+%F %T")] All the new subdomains added." >> $YTADSBLOCKER_LOG
		fi
		
		COUNT=$(($COUNT + 1))
		sleep $SLEEPTIME;

		if [[ $COUNT -eq ${VERSIONCHECKER_TIME} ]]; then
			VersionChecker
			COUNT=0
		else
			continue;
		fi
	done

}

function Stop() {

	echo "Youtube Ads Blocker Stopped"
	echo "[$(date "+%F %T")] Youtube Ads Blocker Stopped" >> $YTADSBLOCKER_LOG
	kill -9 `pgrep ytadsblocker`

}

function Uninstall() {

	echo "Uninstalling..."
	systemctl disable ytadsblocker
	rm -f ${SERVICE_PATH}/${SERVICE_NAME}
	rm -f $YTADSBLOCKER_LOG
	egrep -v "r([0-9]{1,2})[^-].*\.googlevideo\.com" ${BLACKLST} > ${BLACKLST}.new
	mv -f ${BLACKLST}.new ${BLACKLST}
	pihole -g
	echo "YouTube Ads Blocker Uninstalled"
	kill -9 `pgrep ytadsblocker`
	

}

function VersionChecker() {

	NEW_VERSION=$(curl -0s $YTADSBLOCKER_URL | egrep -x "YTADSBLOCKER_VERSION=\"[1-9]{1,2}\.[0-9]{1,2}\"" | cut -f2 -d"=" | sed 's,",,g')

	echo "[$(date "+%F %T")] Checking if there is any new version." >> $YTADSBLOCKER_LOG

	if [[ "${YTADSBLOCKER_VERSION}" != "${NEW_VERSION}" ]]; then
		echo "[$(date "+%F %T")] There is a new version: ${NEW_VERSION}. Current version: ${YTADSBLOCKER_VERSION}" >> $YTADSBLOCKER_LOG
		echo "[$(date "+%F %T")] It will proceed to download it." >> $YTADSBLOCKER_LOG
		curl -0s $YTADSBLOCKER_URL > /tmp/${SCRIPT_NAME}.${NEW_VERSION}
		echo "[$(date "+%F %T")] New version downloaded. You can find the new script at /tmp." >> $YTADSBLOCKER_LOG
	else
		echo "[$(date "+%F %T")] Nothing to do." >> $YTADSBLOCKER_LOG
	fi
}

case "$1" in
	"install"   ) Install 	;;
	"start"     ) Start 	;;
	"stop"      ) Stop 		;;
	"uninstall" ) Uninstall ;;
	*           ) echo "That option does not exists. Usage. /$SCRIPT_NAME [ install | start | stop | uninstall ]";;
esac
