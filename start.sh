#!/bin/bash
# Запуск одного сервера с автоперезапуском после падения.
# Кидать в директорию сервера, запускать внутри tmux: tmux new -s mc, затем ./start.sh
#
# Консоль сервера работает как обычно: java крутится на переднем плане, команды вводятся руками.
# Ctrl+C во время обратного отсчета выходит из цикла перезапуска.

set -uo pipefail

# ============ Настройки ============
JAR="paper.jar"          # имя jar или симлинка, созданного mc-jar.sh
MIN_RAM="4G"             # -Xms
MAX_RAM="4G"             # -Xmx, держим равным -Xms
RESTART_DELAY=5          # секунд перед автоперезапуском
RESTART_ON_CLEAN_STOP=false   # true - перезапускать даже после /stop
EXTRA_FLAGS=""           # свои флаги, если нужны
# ===================================

cd "$(dirname "$0")" || exit 1

[ -e "$JAR" ] || { echo "ОШИБКА: $JAR не найден в $(pwd)"; exit 1; }

command -v java >/dev/null || { echo "ОШИБКА: java не найдена в PATH"; exit 1; }

JAVA_MAJOR="$(java -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1)"
if [ -n "$JAVA_MAJOR" ] && [ "$JAVA_MAJOR" -lt 25 ]; then
    echo "ВНИМАНИЕ: обнаружена Java $JAVA_MAJOR. Версии Minecraft 26.x требуют Java 25 и выше."
fi

# Флаги Aikar. Для кучи от 12 ГБ параметры G1 другие, поэтому выбираем по размеру.
HEAP_GB="$(echo "$MAX_RAM" | grep -oE '^[0-9]+')"
case "$MAX_RAM" in
    *[mM]) HEAP_GB=$(( HEAP_GB / 1024 )) ;;
esac

if [ "${HEAP_GB:-0}" -ge 12 ]; then
    G1_FLAGS="-XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=15 -XX:InitiatingHeapOccupancyPercent=20"
else
    G1_FLAGS="-XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15"
fi

AIKAR_FLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
$G1_FLAGS \
-XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 \
-XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \
-XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

# На Java 25 библиотека JOML сыплет предупреждением про sun.misc.Unsafe. Флаг его убирает.
JAVA25_FLAGS="--sun-misc-unsafe-memory-access=allow"

while true; do
    echo "Запуск сервера ($JAR, куча $MIN_RAM..$MAX_RAM)"
    # shellcheck disable=SC2086
    java -Xms"$MIN_RAM" -Xmx"$MAX_RAM" $JAVA25_FLAGS $AIKAR_FLAGS $EXTRA_FLAGS -jar "$JAR" nogui
    RC=$?

    if [ "$RC" -eq 0 ] && [ "$RESTART_ON_CLEAN_STOP" != "true" ]; then
        echo "Сервер остановлен штатно. Выхожу."
        exit 0
    fi

    echo "Сервер завершился с кодом $RC."

    STOP=false
    trap 'STOP=true' INT
    for i in $(seq "$RESTART_DELAY" -1 1); do
        printf "\rПерезапуск через %2d сек (Ctrl+C - выход)... " "$i"
        sleep 1
        $STOP && break
    done
    trap - INT
    printf "\n"

    if $STOP; then
        echo "Выход по Ctrl+C."
        exit 0
    fi
done
