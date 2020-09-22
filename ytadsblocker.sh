#!/bin/bash

# This script was made in order to block all the Youtube's advertisement in Pi-Hole

YTADSBLOCKER_VERSION="3.4"
YTADSBLOCKER_LOG="/var/log/ytadsblocker.log"
YTADSBLOCKER_GIT="https://raw.githubusercontent.com/deividgdt/ytadsblocker/master/ytadsblocker.sh"
VERSIONCHECKER_TIME="260"
SLEEPTIME="240"
DIR_LOG="/var/log"
PI_LOG="/var/log/pihole.log"
GRAVITYDB="/etc/pihole/gravity.db"
SERVICE_PATH="/lib/systemd/system"
SERVICE_NAME="ytadsblocker.service"
SCRIPT_NAME=$(basename $0)
PRINTWD=$(pwd)
SQLITE3BIN=$(whereis -b sqlite3 | cut -f 2 -d" ")
TEMPDIR="/tmp/ytadsblocker"
DOCKER_PIHOLE="/etc/docker-pi-hole-version"

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

function Banner () {
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
	echo -e "${TAGINFO} You can check the logs in: $YTADSBLOCKER_LOG";
	echo -e "${TAGINFO} All the subdomains will be added to the database: $GRAVITYDB";
	echo -e "${TAGINFO} Every ${SLEEPTIME}s it reads: $PI_LOG"; sleep 3
	echo ""
}

function CheckUser() {
	if [[ "$(id -u $(whoami))" != "0" ]]; then
		echo -e "${TAGERR} $(whoami) is not a valid user. The installation must be executed by the user: root."
		exit 1;
	else
		echo -e "${TAGOK} $(whoami) is a valid user."
	fi
}

function CheckDocker() {
	if [ -f "${DOCKER_PIHOLE}" ]; then
		echo -e "${TAGINFO} Running on a Docker Container."
		DOCKER="y"
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

function Database() {
	local OPT=$1
	local DOMAIN="$2"
	
	case $OPT in
		"create")
			LASTGROUPID=$(sqlite3 "${GRAVITYDB}" "SELECT MAX(id) FROM 'group';" 2>>  $YTADSBLOCKER_LOG )
			GROUPID=$((${LASTGROUPID} + 1))
			sqlite3 "${GRAVITYDB}" "INSERT INTO 'group' (id, name, description) VALUES (${GROUPID}, 'YTADSBLOCKER', 'Youtube ADS Blocker');" 2>> $YTADSBLOCKER_LOG 
		;;
		"insertDomain")
			if [[ $DOMAIN == *.googlevideo.com ]]; then 
				echo -e "${TAGINFO} Inserting subdomain: $DOMAIN";
				sqlite3 "${GRAVITYDB}"  """INSERT OR IGNORE INTO domainlist (type, domain, comment) VALUES (1, '${DOMAIN}', 'Blacklisted by ytadsblocker');""" 2>>  $YTADSBLOCKER_LOG 
			else
				echo "[$(date "+%F %T")] The subdomain: $DOMAIN has not been inserted, does not looks like a subdomain!!!" >> $YTADSBLOCKER_LOG
			fi
		;;
		"update")
			sqlite3 "${GRAVITYDB}"  "UPDATE domainlist_by_group SET group_id=${GROUPID} WHERE domainlist_id IN (SELECT id FROM domainlist WHERE comment = 'Blacklisted by ytadsblocker');" 2>>  $YTADSBLOCKER_LOG 
		;;
		"getGroupId")
			GROUPID=$(sqlite3 "${GRAVITYDB}"  "SELECT id FROM 'group' WHERE name = 'YTADSBLOCKER';" 2>>  $YTADSBLOCKER_LOG )
		;;
		"checkDomain")
			CHECK_NEW_DOMAIN=$(sqlite3 "${GRAVITYDB}"  """SELECT domain FROM domainlist WHERE comment = 'Blacklisted by ytadsblocker' AND domain = '${DOMAIN}';""" 2>>  $YTADSBLOCKER_LOG)
		;;
		"delete")
			sqlite3 "${GRAVITYDB}"  "DELETE FROM domainlist WHERE comment = 'Blacklisted by ytadsblocker';" 2>>  $YTADSBLOCKER_LOG 
			sqlite3 "${GRAVITYDB}"  "DELETE FROM 'group' WHERE name = 'YTADSBLOCKER';" 2>>  $YTADSBLOCKER_LOG 
		;;
	esac
}



function Install() {
	CheckUser #We check if the root user is executing the script
	CheckDocker #We check if the script is being executed on a Docker Container
	
	
	function ConfigureEnv() {
		echo -e "${TAGINFO} Configuring the database: $GRAVITYDB ..."; sleep 1
		Database "create"
		echo -e "${TAGINFO} Searching googlevideo.com subdomains inside the Pi-Hole's logs..."; sleep 1    
		mkdir -p ${TEMPDIR}
		cp $DIR_LOG/pihole.log* ${TEMPDIR}
		for GZIPFILE in $(ls ${TEMPDIR}/pihole.log*gz > /dev/null 2>&1); do 
			gunzip $GZIPFILE; 
		done

		echo "[$(date "+%F %T")] Searching Googlevideo's subdomains in the logs..." >> $YTADSBLOCKER_LOG 
		ALL_DOMAINS=$(cat ${TEMPDIR}/pihole.log* | egrep --only-matching "r([0-9]{1,2})[^-].*\.googlevideo\.com" | sort | uniq)
		
		if [ ! -z "${ALL_DOMAINS}" ]; then
			N_DOM=$(cat ${TEMPDIR}/pihole.log* | egrep --only-matching "r([0-9]{1,2})[^-].*\.googlevideo\.com" | sort | uniq | wc --lines)
			echo "[$(date "+%F %T")] We have found $N_DOM subdomain/s..." >> $YTADSBLOCKER_LOG 
			for YTD in $ALL_DOMAINS; do
				echo "[$(date "+%F %T")] Adding the subdomain: ${YTD}" >> $YTADSBLOCKER_LOG 
				Database "checkDomain" "${YTD}"
				if [[ -z ${CHECK_NEW_DOMAIN} ]]; then Database "insertDomain" "${YTD}"; fi
			done
			Database "update"
			pihole updateGravity
			echo -e "${TAGOK} OK. $N_DOM subdomains added"
		else
			echo -e "${TAGWARN} No subdomains to add at the moment."
		fi
		
		echo -ne "${TAGINFO} Deleting temp..."; sleep 1
		rm --force ${TEMPDIR}/pihole.log*
		echo "OK. Temp deleted."; sleep 1
		
	}
	
	if [[ "${DOCKER}" == "y" ]]; then
		echo -e "${TAGWARN} Since some system capabilities are not enabled, we can't create a system service on this Docker Container"
		ConfigureEnv
		echo -e "${TAGWARN} To start the script just execute it as follows: bash $PRINTWD/$SCRIPT_NAME start &"
		echo -e "${TAGWARN} To stop the script just execute it as follows: bash $PRINTWD/$SCRIPT_NAME stop"
	else
		if [ ! -f $SERVICE_PATH/$SERVICE_NAME ]; then		
			echo -e "${TAGINFO} If you move the script to a different place, please run it again with the option 'install'";
			echo -ne "${TAGINFO} Installing the service..."; sleep 1
			Makeservice
			echo "OK. Service installed.";
			
			ConfigureEnv
			
			echo -e "${TAGOK} Youtube Ads Blocker: INSTALLED..."; sleep 1
			echo ""
			echo -e "${TAGINFO} To start the service execute as follows: systemctl start ytadsblocker"; sleep 1
			echo -ne "${TAGINFO} Enabling the service to start it automatically with the OS."; sleep 1
			systemctl enable ytadsblocker 1> /dev/null 2>&1
			echo "OK."
			echo "[$(date "+%F %T")] Youtube Ads Blocker has been installed. Welcome!" >> $YTADSBLOCKER_LOG 
		else
			echo -e "${TAGWARN} Youtube Ads Blocker already installed..."; sleep 1
			echo -ne "${TAGINFO} Reinstalling the service..."; 
			Makeservice
			systemctl daemon-reload
			echo "OK. Reinstalled."
		fi
	fi

}

function Start() {
	
	CheckUser #We check if the root user is executing the script
	
	echo "Youtube Ads Blocker Started"
	echo "Check the $YTADSBLOCKER_LOG file to get further information."

	echo "[$(date "+%F %T")] Youtube Ads Blocker Started" >> $YTADSBLOCKER_LOG
	
	Database "getGroupId"
		
	if [ -z ${GROUPID} ]; then
		echo -e "${TAGERR} The YTADSBLOCKER group ID does not exists in the database."
		exit 1;
	fi
	
	while true; do
		echo "[$(date "+%F %T")] Checking ${PI_LOG}..." >> $YTADSBLOCKER_LOG
		
		YT_DOMAINS=$(cat ${PI_LOG} | egrep --only-matching "r([0-9]{1,2})[^-].*\.googlevideo\.com" | sort | uniq)
		NEW_DOMAINS=
		CHECK_NEW_DOMAIN=		   
		
		for YTD in $YT_DOMAINS; do
			
			Database "checkDomain" "${YTD}"

			if [[ -z ${CHECK_NEW_DOMAIN} ]]; then
				NEW_DOMAINS="$NEW_DOMAINS $YTD"
				echo "[$(date "+%F %T")] New subdomain to add: $YTD" >> $YTADSBLOCKER_LOG
				Database "insertDomain" "${YTD}"
			fi
		done
		
		if [ -z "$NEW_DOMAINS" ]; then
			echo "[$(date "+%F %T")] No new subdomains to added." >> $YTADSBLOCKER_LOG
		else
			echo "[$(date "+%F %T")] Updating database..." >> $YTADSBLOCKER_LOG
			Database "update"
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
	CheckDocker #We check if the script is being executed on a Docker Container
	CheckUser #We check if the root user is executing the script

	echo -e "${TAGINFO} Uninstalling YouTube Ads Blocker. Wait..."
	
	echo -e "${TAGINFO} Deleting the Googlevideo's subdomains from ${GRAVITYDB}"
	Database "delete"
	
	echo -e "${TAGINFO} Updating the Gravity in the Pi-hole..."
	pihole updateGravity
	
	if [[ ! ${DOCKER} ]]; then
		echo -e "${TAGINFO} Disabling the service..."
		systemctl disable ytadsblocker 1> /dev/null 2>&1
		systemctl daemon-reload

		if [ -f ${SERVICE_PATH}/${SERVICE_NAME} ]; then 
			echo -e "${TAGINFO} Deleting the service file..."
			rm --force ${SERVICE_PATH}/${SERVICE_NAME};
		fi
		
		if [ -f ${YTADSBLOCKER_LOG} ]; then
			echo -e "${TAGINFO} Deleting the log file..."
			rm --force ${YTADSBLOCKER_LOG}; 
		fi
	fi
	
	echo -e "${TAGOK} YouTube Ads Blocker Uninstalled. Bye"
	kill -9 `pgrep ytadsblocker`

}

function VersionChecker() {

	NEW_VERSION=$(curl --http1.0 --silent $YTADSBLOCKER_GIT | egrep --line-regexp "YTADSBLOCKER_VERSION=\"[1-9]{1,2}\.[0-9]{1,2}\"" | cut --fields=2 --delimiter="=" | sed 's,",,g')

	if [[ "${YTADSBLOCKER_VERSION}" != "${NEW_VERSION}" ]]; then
		echo "[$(date "+%F %T")] There is a new version: ${NEW_VERSION}. Current version: ${YTADSBLOCKER_VERSION}" >> $YTADSBLOCKER_LOG
	fi
}

case "$1" in
	"install"   ) Banner; Install 	;;
	"start"     ) Start 			;;
	"stop"      ) Stop 				;;
	"uninstall" ) Uninstall			;;
	*           ) echo "That option does not exists. Usage: ./$SCRIPT_NAME [ install | start | stop | uninstall ]";;
esac
