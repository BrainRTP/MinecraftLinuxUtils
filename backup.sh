#!/bin/bash

# == Цвета ==
Reset='\033[0m'       # Ресет
Red='\033[0;31m'          # Красный
Green='\033[0;32m'        # Зеленый
Yellow='\033[0;33m'       # Желтый
Cyan='\033[0;36m'         # Бирюзовый
White='\033[0;37m'        # Белый

dir_server=mine/ # Директория
dt=$(date '+%d.%m.%y %H:%M:%S'); # Дата
date=$(date '+%d.%m.%y'); # Дата
time=$(date '+%H:%M:%S') # Время
time=${White}[${Cyan}$time${White}]${Reset} # Оформленное время

start=`date +%s` #Точка отсчета

echo "===== $dt =====" >> backup_log.txt # Запись логов в файл

worlds=(world world_nether world_the_end) # Список папок/файлов типа #1 #2 #3... Без запятых и пр.
plugins=(plugin1 plugin2 plugin3) # Список папок/файлов типа #1 #2 #3... Без запятых и пр.

mkdir -p backup/$date  backup/$date/worlds backup/$date/plugins # Создание папок ('-p' если их нет)

days=7 # Дни
find backup/ -type f -mtime +$days -exec rm -f {} \; # Удаление старых бекапов

for file in "${worlds[@]}";
do
	echo -e -ne "$time ${Reset}Делаю копию мира '${Yellow}$file${Reset}' "
	cd $dir_server
	if tar -czf ../backup/$date/worlds/$file-$date.tar.gz $file > /dev/null 2>&1
	then
	    echo -e "${Green}Успешно!${Reset}"
	else
	    echo -e "${Red}Ошибка!${Reset}"
	fi
	cd ..
done

for file in "${plugins[@]}";
do
	echo -e -ne "$time ${Reset}Делаю копию плагина '${Yellow}$file${Reset}' "
	cd $dir_server/plugins
	if tar -czf ../../backup/$date/plugins/$file-$date.tar.gz $file > /dev/null 2>&1
	then
	    echo -e "${Green}Успешно!${Reset}"
	else
	    echo -e "${Red}Ошибка!${Reset}"
	fi
	cd ../..
done
end=`date +%s` # Точка завершения
runtime=$((end-start)) # Время работы программы
echo -e "$time Копия сервера сделана за ${Red}$runtime сек."
