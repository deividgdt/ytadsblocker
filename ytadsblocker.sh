#!/bin/bash

# Script desarrollado para bloquear publicidad de Youtube en Pi-hole
# version 1.0 BETA

YTADSBLOCKER_LOG="/var/log/ytadsblocker.log"
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

function makeservice () {

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

function install() {

if [ ! -f $SERVICE_PATH/$SERVICE_NAME ]; then
		echo -e "${COLOR_R}__  ______  __  __________  ______  ______   ___    ____  _____"
		echo -e "\ \/ / __ \/ / / /_  __/ / / / __ )/ ____/  /   |  / __ \/ ___/"
		echo -e " \  / / / / / / / / / / / / / __  / __/    / /| | / / / /\__ \ "
		echo -e " / / /_/ / /_/ / / / / /_/ / /_/ / /___   / ___ |/ /_/ /___/ / "
		echo -e "/_/\____/\____/ ____ \______________________  |_/_____//____/"  
		echo -e "	   / __ )/ /   / __ \/ ____/ //_// ____/ __ \ "                 
		echo -e "	  / __  / /   / / / / /   / ,<  / __/ / /_/ / "                 
		echo -e "	 / /_/ / /___/ /_/ / /___/ /| |/ /___/ _, _/ "                  
		echo -e "	/_____/_____/\____/\____/_/ |_/_____/_/ |_| v1.0 BETA${COLOR_CL} by @deividgdt"   
		echo ""
		echo "Youtube Ads Blocker: INSTALANDO..."; sleep 1
		echo "Si mueve el script de directorio, ejecutelo con la opcion install de nuevo."; sleep .3
		echo "Los logs se almacenaran en la ruta: $YTADSBLOCKER_LOG"; sleep .3
		echo "Los dominios se añadiran a: $BLACKLST"; sleep .3
		echo "Cada ${SLEEPTIME}s se leera $PI_LOG"; sleep 5
		echo ""
		echo -ne "Creando servicio..."; sleep 1
		makeservice
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
		makeservice
		systemctl daemon-reload
		echo "OK. Regenerado."
	fi

}

function start() {
	
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
		sleep $SLEEPTIME;
	done

}

function stop() {

	echo "Youtube Ads Blocker parado"
	echo "[$(date "+%F %T")] Youtube Ads Blocker Parado" >> $YTADSBLOCKER_LOG
	kill -9 `pgrep ytadsblocker`

}

function uninstall() {

	systemctl disable ytadsblocker
	rm -f ${SERVICE_PATH}/${SERVICE_NAME}
	rm -f $YTADSBLOCKER_LOG
	kill -9 `pgrep ytadsblocker`

}

case "$1" in
	"install")
		install;;
	"start")
		start;;
	"stop")
		stop;;
	"uninstall")
		uninstall;;
	*)
		echo "Opcion no reconocida. Usa ./$SCRIPT_NAME [ install | start | stop | uninstall ]";;
esac
