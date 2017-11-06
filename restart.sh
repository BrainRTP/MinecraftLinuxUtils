#!/bin/bash
reload_time=10;
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "===== $dt =====" >> restart_log.txt
declare -a array
array=([1]=auth [2]=hub-1 [3]=survival)
complite=()
bad=()

for ((i=$reload_time;i>=1;i--));
do
    if [ ${i} = "1" ]; then
        screen -S bungee -X eval 'stuff "alert Перезапуск сервера через '${i}' секунду"\015'
        echo "Перезапуск сервера через ${i} секунду"
        sleep 1s
    else
        screen -S bungee -X eval 'stuff "alert Перезапуск сервера через '${i}' секунд"\015'
        echo "Перезапуск сервера через ${i} секунд"
        sleep 1s
    fi
done
screen -S bungee -X eval 'stuff "alert Перезапуск!"\015'
echo "Перезапуск!"
sleep 1s
screen -S bungee -X eval 'stuff "end"\015'

for ((i=1;i<=${#array[@]};i++));
do
    if screen -list | grep -q ${array[i]}; then
        screen -S ${array[i]} -X eval 'stuff "stop"\015'
        complite+=(${array[i]})
        echo "Сервер ${array[i]} перезагружен" >> restart_log.txt
        echo -e "\033[32mСервер \033[36m${array[i]} \033[32mперезагружен\033[0m"
    else
        bad+=(${array[i]})
        echo "(!) Сервер ${array[i]} не найден " >> restart_log.txt
        echo -e "\033[32mСервер \033[36m${array[i]} \033[31mне найден!\033[0m"
    fi
done

echo "======== Сводка: ========"
echo -e "\033[32m Сервера успешно перезагружены: \033[36m${complite[@]}\033[0m"
echo "-------- Сводка: --------" >> restart_log.txt
echo "Сервера успешно перезагружены: ${complite[@]}" >> restart_log.txt

if  [ ${#bad[@]} != "0" ]; then
    echo -e "\033[31m Сервера не найдены: \033[36m${bad[@]}\033[0m"
    echo "Сервера не найдены: ${bad[@]}" >> restart_log.txt
fi

echo " " >> restart_log.txt
