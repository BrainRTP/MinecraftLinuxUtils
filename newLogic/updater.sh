#!/bin/bash
if [ -z $1 ] ; then
    echo "Укажите версию ядра"
    exit
fi
mc_version=$1

Reset='\033[0m'
Green='\033[0;32m'
Red='\033[0;31m'
Yellow='\033[0;33m'

current_build=$(cat check.txt 2>/dev/null)
last_build="$(curl -s https://papermc.io/api/v1/paper/${mc_version}/latest | jq  -r '.build')"
let "missed_updates = last_build - current_build"

# last_build=$(curl -s "https://papermc.io/api/v1/paper/${mc_version}/latest" | awk -F'[:}]' '{print $(NF-1)}')

if [ -f "check.txt" ]; then
	if [ $last_build != $current_build ]
	then
		echo -e "${Red}Найдено обновления ядра ${Reset}PaperSpigot ${mc_version}${Yellow}#${last_build} ${Red} (пропущено ${missed_updates} обновлений) ${Reset}"
		mv paper.jar paper_${last_build}.jar
		wget -q --show-progress --progress=bar -O paper.jar https://papermc.io/api/v1/paper/${mc_version}/latest/download
		echo -e "${Green}Ядро обновлено. ${Reset}"
		echo $last_build > check.txt
		else
			echo -e "${Green}Обновлений ядра нет. ${Reset}"
	fi
else
	echo -e "${Red}Ядро не найдено. Скачиваю последний билд. ${Reset}PaperSpigot ${mc_version}${Yellow}#${last_build} ${Reset}" 
	wget -q --show-progress --progress=bar -O paper.jar https://papermc.io/api/v1/paper/${mc_version}/latest/download
	echo -e "${Green}Ядро обновлено. ${Reset}"
	echo $last_build > check.txt
fi
