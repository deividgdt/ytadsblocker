#!/bin/bash

# Script desarrollado para bloquear publicidad de Youtube en Pi-hole

YTADSBLOCKER_VERSION="1.1"
YTADSBLOCKER_LOG="/var/log/ytadsblocker.log"
YTADSBLOCKER_URL="https://raw.githubusercontent.com/deividgdt/ytadsblocker/master/ytadsblocker.sh"
DIR_LOG="/var/log"
PI_LOG="/var/log/pihole.log"
BLACKLST="/etc/pihole/blacklist.txt"
BLACKLST_BKP="/etc/pihole/blacklist.txt.BKP"
SLEEPTIME="240"
SERVICE_PATH="/usr/lib/systemd/system"
SERVICE_NAME="ytadsblocker.service"
SCRIPT_NAME=$(basename $0)
PRINTWD=$(pwd)
COLOR_R="\e[31m"
COLOR_Y="\e[33m"
COLOR_G="\e[32m"
COLOR_CL="\e[0m"

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
		echo "Youtube Ads Blocker: INSTALANDO..."; sleep 1
		echo "Si mueve el script de directorio, ejecutelo con la opcion install de nuevo."; sleep .3
		echo "Los logs se almacenaran en la ruta: $YTADSBLOCKER_LOG"; sleep .3
		echo "Los dominios se añadiran a: $BLACKLST"; sleep .3
		echo "Cada ${SLEEPTIME}s se leera $PI_LOG"; sleep 5
		echo ""
		echo -ne "Creando servicio..."; sleep 1
		Makeservice
		echo "OK. Servicio creado."; sleep 2

		echo -n "Cambiando el servicio para que arranque automaticamente..."
		systemctl enable ytadsblocker 1> /dev/null 2>&1
		echo "OK"

		echo "Leyendo logs de pihole para buscar subdominios de Googlevideo..."; sleep 2    
		
		cp $DIR_LOG/pihole.log.* /tmp
		gunzip /tmp/pihole.log.*.gz
		
		echo -n "Creando copia de ${BLACKLST}..."; sleep 1
		cp $BLACKLST $BLACKLST_BKP
		echo "OK. Copia creada."
		
		echo -n "Agregando dominios..."; sleep 1
		cat /tmp/pihole.log* | egrep "r([0-9]{1,2}).*\.googlevideo\.com" | awk '{print $8}' | sort | uniq >> $BLACKLST
		N_DOM=$(cat /tmp/pihole.log* | egrep "r([0-9]{1,2}).*\.googlevideo\.com" | awk '{print $8}' | sort | uniq | wc -l)
		echo " OK. $N_DOM subdominios agregados"
		
		echo -n "Borrando temporales..."; sleep 1
		rm -f /tmp/pihole.log*
		echo "OK. Temporales borrados."; sleep 1
		echo "Youtube Ads Blocker: INSTALADO..."; sleep 1
		echo ""
		echo "Para arrancar el script ejecute: systemctl start ytadsblocker"; sleep 1

	else
		echo "Youtube Ads Blocker ya instalado..."; sleep 1
		echo -n "Regenerando servicio..."; sleep 2
		Makeservice
		systemctl daemon-reload
		echo "OK. Regenerado."
	fi

}

function Start() {
	
	echo "Youtube Ads Blocker Iniciado"
	echo "Puede revisar $YTADSBLOCKER_LOG para mas informacion"

	echo "[$(date "+%F %T")] Youtube Ads Blocker Iniciado" >> $YTADSBLOCKER_LOG

	while true; do
		echo "[$(date "+%F %T")] Comprobando..." >> $YTADSBLOCKER_LOG
		YT_DOMAINS=$(egrep "r([0-9]{1,2}).*\.googlevideo\.com" $PI_LOG | awk '{print $8}' | sort | uniq)
		CURRENT_DOMAINS=$(cat $BLACKLST)

		for YTD in $YT_DOMAINS; do
			if [[ ! $( grep "$YTD" $BLACKLST ) ]]; then
				echo $YTD >> $BLACKLST;
				echo "[$(date "+%F %T")] Nuevo dominio añadido: $YTD" >> $YTADSBLOCKER_LOG
			fi
		done
		COUNT=$(($COUNT + 1))
		sleep $SLEEPTIME;
		if [[ $COUNT -eq 360 ]]; then
			VersionChecker
			COUNT=0
		else
			continue;
		fi
	done

}

function Stop() {

	echo "Youtube Ads Blocker parado"
	echo "[$(date "+%F %T")] Youtube Ads Blocker Parado" >> $YTADSBLOCKER_LOG
	kill -9 `pgrep ytadsblocker`

}

function Uninstall() {

	systemctl disable ytadsblocker
	rm -f ${SERVICE_PATH}/${SERVICE_NAME}
	rm -f $YTADSBLOCKER_LOG
	kill -9 `pgrep ytadsblocker`

}

function VersionChecker() {

	NEW_VERSION=$(curl -0s $YTADSBLOCKER_URL | grep "YTADSBLOCKER_VERSION=" | cut -f2 -d"=" | sed 's,",,g')

	echo "[$(date "+%F %T")] Comprobando si existe una nueva version." >> $YTADSBLOCKER_LOG

	if [[ "${YTADSBLOCKER_VERSION}" != "${NEW_VERSION}" ]]; then
		echo "[$(date "+%F %T")] Existe una nueva version: ${NEW_VERSION}. Versión actual: ${YTADSBLOCKER_VERSION}" >> $YTADSBLOCKER_LOG
		echo "[$(date "+%F %T")] Se procederá a descargar la nueva versión." >> $YTADSBLOCKER_LOG
		curl -0s $YTADSBLOCKER_URL > /tmp/${SCRIPT_NAME}.${NEW_VERSION}
		echo "[$(date "+%F %T")] Nueva versión descargada. Actualizando." >> $YTADSBLOCKER_LOG
		cat /tmp/${SCRIPT_NAME}.${NEW_VERSION} ./$SCRIPT_NAME
		echo "[$(date "+%F %T")] Actualizando." >> $YTADSBLOCKER_LOG
	else
		echo "[$(date "+%F %T")] Nada por actualizar." >> $YTADSBLOCKER_LOG
	fi
}

case "$1" in
	"install")
		Install;;
	"start")
		Start;;
	"stop")
		Stop;;
	"uninstall")
		Uninstall;;
	*)
		echo "Opcion no reconocida. Usa ./$SCRIPT_NAME [ install | start | stop | uninstall ]";;
esac
