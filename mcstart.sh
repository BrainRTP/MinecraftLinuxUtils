#!/bin/bash
# Поднимает сервера из servers.conf в отдельных окнах одной сессии tmux.
#
#   ./mcstart.sh          поднять все
#   ./mcstart.sh main     поднять только main
#
# Подключиться к консоли:  tmux attach -t minecraft
# Переключение окон:       Ctrl+B, затем номер окна или n/p
# Отключиться:             Ctrl+B, затем D

set -uo pipefail

SESSION="${MC_SESSION:-minecraft}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/servers.conf"

command -v tmux >/dev/null || { echo "ОШИБКА: нет tmux (apt install tmux)"; exit 1; }
[ -f "$CONF" ] || { echo "ОШИБКА: нет $CONF. Скопируйте servers.conf.example"; exit 1; }

ONLY="${1:-}"
STARTED=0

start_one() {
    local name="$1" dir="$2"

    if [ ! -d "$dir" ]; then
        echo "ПРОПУСК $name: папка $dir не найдена"
        return
    fi
    if [ ! -x "$dir/start.sh" ] && [ ! -f "$dir/start.sh" ]; then
        echo "ПРОПУСК $name: нет $dir/start.sh"
        return
    fi
    if tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$name"; then
        echo "ПРОПУСК $name: уже запущен"
        return
    fi

    if tmux has-session -t "$SESSION" 2>/dev/null; then
        tmux new-window -t "$SESSION" -n "$name" -c "$dir" "bash start.sh"
    else
        tmux new-session -d -s "$SESSION" -n "$name" -c "$dir" "bash start.sh"
    fi
    echo "Запущен $name в окне $SESSION:$name"
    STARTED=$((STARTED + 1))
    # Прокси поднимаем первой, серверам даем фору, чтобы прокси нашла их живыми.
    sleep 2
}

while IFS=: read -r name dir; do
    case "$name" in ''|\#*) continue ;; esac
    [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
    start_one "$name" "$dir"
done < "$CONF"

if [ "$STARTED" -eq 0 ]; then
    echo "Нечего запускать."
    exit 1
fi

echo
echo "Готово. Консоль: tmux attach -t $SESSION"
