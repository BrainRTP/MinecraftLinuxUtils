#!/bin/bash
versions=([1]=1.8 [2]=1.12.2 [3]=1.13.2)
# "clean_up" Удаляет ненужные файлы, которые указаны в массиве. Пустой массив = false
clean_up=(usercache.json version_history.json whitelist.json help.yml commands.yml banned-ips.json banned-players.json permissions.yml wepif.yml) 
# Пример для 1.8 версии:
# multi_version/jars/1.8.jar
# multi_version/worlds/world_1.8
STARTRAM=-Xms1G           # Стартовый RAM сервера (1024M = 1G)
MAXRAM=-Xmx3G             # Максимальный RAM для сервера
# Может быть сделаю, но потом...
#PARAMS=""                 # Можно удалить значения и тогда не будет параметров. P.s также и с RAM. P.s.s например, "-XX:+UseG1GC"

Reset='\033[0m'           # Text Reset
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'		  # Yellow
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

function prepare {
	main_dir=multi_version/
	mkdir -p $main_dir $main_dir/plugins $main_dir/worlds $main_dir/jars
	for ver in "${version[@]}";
	do
		mkdir -p $main_dir/plugins/$ver $main_dir/worlds/world_$ver $main_dir/jars/$ver
	done
}

function start_server { # $1 - STARTRAM, $2 - MAXRAM, $3 - PARAMS, $4 - version
	cp multi_version/jars/$3.jar $3.jar
	cp -r multi_version/plugins/$3/. plugins
	cp -r multi_version/worlds/world_$3 world
	java $1 $2 -jar $3.jar
}

function save_plugins { # $1 - verions
	cp -r plugins/. multi_version/plugins/$1
	echo -e "${Green}Плагины сохранены ${Reset}"
}

function save_world {
	cp -r world multi_version/worlds/world_$1
	echo -e "${Green}Мир сохранен ${Reset}"
}

function clean_files {
	if [ ${clean_up:+1} ] # Проверка есть ли в clean2 что-то
	then
		for file in "${clean_up[@]}";
		do
			rm -rf $file
		done
	fi
	rm -rf $1.jar
	rm -rf plugins/*
	rm -rf world
	echo -e "${Green}Файлы и папки почищены ${Reset}"
}

echo -e "${Red}Выберите версию:"

i=1
for ver in "${versions[@]}";
do
	echo -e "${Reset}$i) ${Green}$ver${Reset}"
	((i++))
done

read -s ver_selected
ver_selected=${versions[ver_selected]}

prepare
echo -e "${Green}Запуская сервер версии $ver_selected ${Reset}"
start_server $STARTRAM $MAXRAM $ver_selected
save_plugins $ver_selected
save_world $ver_selected
clean_files $ver_selected
