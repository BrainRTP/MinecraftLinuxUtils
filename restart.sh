#!/bin/bash
# Перезапуск всех серверов из servers.conf с предупреждением игроков.
# Сервера останавливаются в обратном порядке, прокси последней, чтобы игроков
# не выкидывало по таймауту.
#
# В cron ежедневно в 03:15:
#   15 3 * * * /home/mc/scripts/restart.sh >> /home/mc/scripts/restart.log 2>&1
#
# У cron урезанный PATH, поэтому в crontab указываем полный путь до скрипта.

set -uo pipefail

SESSION="${MC_SESSION:-minecraft}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/servers.conf"
WARN_AT="60 45 30 15 10 5 4 3 2 1"   # на каких секундах предупреждать
TOTAL=60                              # сколько всего ждать

command -v tmux >/dev/null || { echo "ОШИБКА: нет tmux"; exit 1; }
[ -f "$CONF" ] || { echo "ОШИБКА: нет $CONF"; exit 1; }
tmux has-session -t "$SESSION" 2>/dev/null || { echo "ОШИБКА: сессия $SESSION не запущена"; exit 1; }

mapfile -t NAMES < <(grep -vE '^\s*(#|$)' "$CONF" | cut -d: -f1)
[ ${#NAMES[@]} -gt 0 ] || { echo "ОШИБКА: в $CONF нет серверов"; exit 1; }

echo "===== $(date '+%d.%m.%Y %H:%M:%S') ====="

send() {   # send <окно> <команда>
    tmux send-keys -t "$SESSION:$1" "$2" Enter 2>/dev/null
}

alive() {
    tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$1"
}

plural() {
    case "$1" in
        1|21|31|41|51) echo "секунду" ;;
        2|3|4|22|23|24|32|33|34|42|43|44|52|53|54) echo "секунды" ;;
        *) echo "секунд" ;;
    esac
}

for (( i = TOTAL; i > 0; i-- )); do
    if [[ " $WARN_AT " == *" $i "* ]]; then
        MSG="Перезапуск сервера через $i $(plural "$i")"
        for name in "${NAMES[@]}"; do
            alive "$name" && send "$name" "say $MSG"
        done
        echo "$MSG"
    fi
    sleep 1
done

for name in "${NAMES[@]}"; do
    alive "$name" && send "$name" "say Перезапуск!"
done
sleep 1

# Обратный порядок: сначала сервера, прокси в конце.
DONE=()
MISSING=()
for (( i = ${#NAMES[@]} - 1; i >= 0; i-- )); do
    name="${NAMES[$i]}"
    if alive "$name"; then
        send "$name" "stop"
        DONE+=("$name")
        echo "Останавливаю $name"
        sleep 3
    else
        MISSING+=("$name")
    fi
done

echo "-------- Сводка --------"
echo "Остановлены: ${DONE[*]:-нет}"
[ ${#MISSING[@]} -gt 0 ] && echo "Не найдены:  ${MISSING[*]}"

# Циклы в start.sh поднимут сервера сами, если выход был не штатным.
# При RESTART_ON_CLEAN_STOP=false команда stop завершает цикл, и тогда нужен mcstart.sh:
echo
echo "Если в start.sh стоит RESTART_ON_CLEAN_STOP=false, поднимите сервера через mcstart.sh"
