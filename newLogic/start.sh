#!/bin/bash
Reset='\033[0m'
Green='\033[0;32m'
Red='\033[0;31m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
Purple='\033[0;35m'
Aqua='\033[0;36m'
Gray='\033[0;37m'

# Метод для отправки сообщения чтобы не писать постоянно ресет в конце
function log {
    echo -e "$* ${Reset}"
}

if [ -z $1 ] ; then
    log "${Red}Укажите версию сервера"
    exit
fi

if [ -z $2 ] ; then
    log "${Red}Укажите имя сервера"
    exit
fi

if [ -z $3 ] ; then
    lof "${Red}Укажите кол-во памяти сервера (xG или xM)"
    exit
fi

if [ -z $4 ] ; then
    log "${Red}Укажите последним аргументом ${Green}\$PWD"
    exit
fi

ver=$1
name=$2
ram="-Xmx"$3
dir=$4


while true
do {
    bash updater.sh ${ver}
    bash alert.sh PROVERKA_${ver} ${name}
    java -jar ${ram} ${dir} paper.jar
    log "${Red}Для остановки сервера используйте ${Yellow} Ctrl + C${Red}!"
    log "${Red}Перезагрузка:"
    for i in {5..1}
    do
      log "${Red}$i..."
      sleep 1
    done
    log "${Green}Запуск..."
}
done
