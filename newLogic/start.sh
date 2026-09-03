#!/bin/bash
# Общий скрипт запуска для нескольких серверов на одной машине.
# Лежит в одном экземпляре, у каждого сервера свой тонкий start.sh, который его вызывает.
#
# Вызов:
#   bash /home/mc/scripts/start.sh <тип> <имя> <папка> <ожидание> <интервал> [флаги java...]
#
# Пример тонкой обертки в папке сервера:
#   #!/bin/bash
#   bash "$HOME/scripts/start.sh" main MainServer "$HOME/mainServer" 180 20 -Xms4G -Xmx4G
#
# Уведомления в Telegram включаются, если рядом лежит notify.conf (см. ssh-notify.conf.example).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER_TYPE="${1:-}"
SERVER_NAME="${2:-}"
SERVER_DIR="${3:-}"
MAX_WAIT="${4:-120}"
CHECK_INTERVAL="${5:-10}"
# Все аргументы начиная с шестого - флаги java. Именно срез, а не последний аргумент.
JAVA_FLAGS=("${@:6}")

usage() {
    echo "Использование: $0 <paper|velocity> <имя> <папка сервера> <ожидание сек> <интервал сек> [флаги java...]" >&2
    exit 1
}

[ -n "$SERVER_TYPE" ] || usage
[ -n "$SERVER_NAME" ] || usage
[ -n "$SERVER_DIR" ]  || usage
[ ${#JAVA_FLAGS[@]} -gt 0 ] || { echo "Укажите хотя бы -Xmx" >&2; usage; }
[ -d "$SERVER_DIR" ] || { echo "ОШИБКА: папка $SERVER_DIR не найдена" >&2; exit 1; }

# Версия ядра берется из файла version в папке сервера. Так у каждого сервера своя,
# а обновление все равно идет через общий каталог jar-ников.
VERSION_FILE="$SERVER_DIR/version"
[ -f "$VERSION_FILE" ] || { echo "ОШИБКА: создайте $VERSION_FILE со строкой вида 26.2" >&2; exit 1; }
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

LOG_FILE="$SERVER_DIR/logs/latest.log"
JAR="$SERVER_NAME-$SERVER_TYPE.jar"

# ---- Telegram, если настроен ----
NOTIFY_CONF="$SCRIPT_DIR/notify.conf"
notify() {
    [ -f "$NOTIFY_CONF" ] || return 0
    # shellcheck disable=SC1090
    . "$NOTIFY_CONF"
    [ -n "${TG_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ] || return 0
    curl -s -m 10 -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="$TG_CHAT_ID" -d parse_mode=Markdown -d text="$1" >/dev/null || true
}

# Ждет строку об успешном старте и сообщает результат.
watch_startup() {
    local waited=0
    sleep 10
    while [ "$waited" -lt "$MAX_WAIT" ]; do
        if [ -f "$LOG_FILE" ] && grep -q 'Done (' "$LOG_FILE"; then
            local line time errors
            line="$(grep 'Done (' "$LOG_FILE" | tail -1)"
            time="$(sed -nE 's/.*Done \(([0-9.]+)s\).*/\1/p' <<<"$line")"
            errors="$(grep -c 'ERROR' "$LOG_FILE" || true)"
            notify "Сервер *${SERVER_NAME}* поднялся за ${time:-?} сек. Ошибок в логе: ${errors}"
            return 0
        fi
        sleep "$CHECK_INTERVAL"
        waited=$((waited + CHECK_INTERVAL))
    done
    notify "Сервер *${SERVER_NAME}* не поднялся за ${MAX_WAIT} сек"
}

cd "$SERVER_DIR" || exit 1

# Обновляем ядро в общем каталоге и переставляем симлинк.
if [ -x "$SCRIPT_DIR/../mc-jar.sh" ]; then
    bash "$SCRIPT_DIR/../mc-jar.sh" "$SERVER_TYPE" "$VERSION" "$SERVER_DIR" || \
        echo "ВНИМАНИЕ: обновить ядро не удалось, запускаюсь на том, что есть"
fi

[ -e "$JAR" ] || { echo "ОШИБКА: $SERVER_DIR/$JAR не найден" >&2; exit 1; }

while true; do
    notify "Сервер *${SERVER_NAME}* запускается"
    watch_startup &
    WATCH_PID=$!

    java "${JAVA_FLAGS[@]}" --sun-misc-unsafe-memory-access=allow -jar "$JAR" nogui
    RC=$?

    kill "$WATCH_PID" 2>/dev/null
    wait "$WATCH_PID" 2>/dev/null

    notify "Сервер *${SERVER_NAME}* остановлен, код ${RC}"

    if [ "$RC" -eq 0 ]; then
        echo "Штатная остановка. Выхожу."
        exit 0
    fi

    STOP=false
    trap 'STOP=true' INT
    for i in 5 4 3 2 1; do
        printf "\rПерезапуск через %d сек (Ctrl+C - выход)... " "$i"
        sleep 1
        $STOP && break
    done
    trap - INT
    printf "\n"
    $STOP && exit 0
done
