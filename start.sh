#!/bin/bash
STARTRAM=1G           #Стартовый RAM сервера (1024M = 1G)
MAXRAM=3G             #Максимальный RAM для сервера
JARNAME=auth.jar      #Название .jar'ника
IS64=true             #Если Java 64x
#Параметры
PARMS="
-server
-XX:+AlwaysPreTouch
-XX:+DisableExplicitGC
-XX:+UseG1GC
-XX:+UnlockExperimentalVMOptions
-XX:+AggressiveOpts
-XX:+UseGCOverheadLimit
-XX:+OptimizeStringConcat
-XX:+UseFastAccessorMethods
-XX:-UseParallelGC
-XX:-UseParallelOldGC
-XX:+AlwaysActAsServerClassMachine"
GONE="
-XX:MaxGCPauseMillis=75
-XX:TargetSurvivorRatio=90
-XX:G1NewSizePercent=50
-XX:G1MaxNewSizePercent=80
-XX:InitiatingHeapOccupancyPercent=10
-XX:G1MixedGCLiveThresholdPercent=50
-XX:G1HeapWastePercent=8"

if ( "$IS64" = true ) then
PARMS="-d64 $PARMS"
fi

while true
do
java -Xms$STARTRAM -Xmx$MAXRAM $PARMS $GONE -jar $JARNAME
echo "Запуск сервера через:"
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
echo "Запуск!"
done
