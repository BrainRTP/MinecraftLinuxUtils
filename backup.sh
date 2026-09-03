#!/bin/bash
# Бэкап серверов Minecraft.
#
# Главное отличие от наивного tar: перед копированием серверу шлется save-off и save-all,
# после - save-on. Без этого сервер продолжает писать в мир во время архивации,
# и архив получается битым. Узнаете Вы об этом в день, когда он понадобится.
#
#   ./backup.sh            снять копию всех серверов из servers.conf
#   ./backup.sh main       только main
#
# Режим задается переменной MODE ниже. Для restic заполните RESTIC_REPO и RESTIC_PASSWORD_FILE.
# В cron:  0 4 * * * /home/mc/scripts/backup.sh >> /home/mc/scripts/backup.log 2>&1

set -uo pipefail

# ============ Настройки ============
MODE="tar"                       # tar или restic
DEST="/var/backups/minecraft"    # куда складывать при MODE=tar
KEEP_DAYS=7                      # сколько дней хранить при MODE=tar
SESSION="${MC_SESSION:-minecraft}"
SAVE_WAIT=10                     # сколько ждать после save-all, секунд

RESTIC_REPO="${RESTIC_REPO:-}"                       # например s3:https://s3.example.com/mc-backup
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-}"     # файл с паролем репозитория, права 600

# Что не тащим в копию по умолчанию. Логи и кеши восстанавливать незачем,
# а весят прилично. Список дополняется, не редактируя скрипт:
#   backup-exclude.conf          рядом со скриптом, действует на все сервера
#   <папка сервера>/.backupignore   только для этого сервера
# Формат обоих файлов: один шаблон в строке, пустые строки и # игнорируются.
DEFAULT_EXCLUDES=(
    logs
    crash-reports
    cache
    '*.log.gz'
    libraries
    versions
    'plugins/dynmap/web/tiles'
)
# ===================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/servers.conf"
ONLY="${1:-}"
STAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
FAILED=0

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "ОШИБКА: $*" >&2; exit 1; }

[ -f "$CONF" ] || die "нет $CONF. Скопируйте servers.conf.example"

if [ "$MODE" = "restic" ]; then
    command -v restic >/dev/null || die "нет restic"
    [ -n "$RESTIC_REPO" ] || die "не задан RESTIC_REPO"
    [ -n "$RESTIC_PASSWORD_FILE" ] || die "не задан RESTIC_PASSWORD_FILE"
    [ -f "$RESTIC_PASSWORD_FILE" ] || die "не найден $RESTIC_PASSWORD_FILE"
    export RESTIC_REPOSITORY="$RESTIC_REPO" RESTIC_PASSWORD_FILE
fi

EXCLUDE_CONF="$SCRIPT_DIR/backup-exclude.conf"

# Собирает список исключений в один временный файл: сначала умолчания,
# потом общий конфиг, потом файл конкретного сервера.
# tar и restic оба умеют читать шаблоны из файла, но по-разному относятся
# к комментариям, поэтому чистим их сами.
build_excludes() {
    local dir="$1" src tmp
    tmp="$(mktemp)"
    printf '%s\n' "${DEFAULT_EXCLUDES[@]}" > "$tmp"
    for src in "$EXCLUDE_CONF" "$dir/.backupignore"; do
        [ -f "$src" ] || continue
        grep -vE '^[[:space:]]*(#|$)' "$src" >> "$tmp"
    done
    echo "$tmp"
}

has_window() {
    tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$1"
}

send_cmd() {
    tmux send-keys -t "$SESSION:$1" "$2" Enter 2>/dev/null
}

# Просим сервер прекратить писать на диск и сбросить все, что накопилось.
save_off() {
    local name="$1"
    has_window "$name" || { log "$name не запущен, копирую как есть"; return 1; }
    log "$name: save-off, save-all"
    send_cmd "$name" "save-off"
    send_cmd "$name" "save-all flush"
    sleep "$SAVE_WAIT"
    return 0
}

save_on() {
    local name="$1"
    log "$name: save-on"
    send_cmd "$name" "save-on"
}

backup_tar() {
    local name="$1" dir="$2" exfile="$3"
    mkdir -p "$DEST"
    local out="$DEST/${name}_${STAMP}.tar.gz"

    # Свободного места нужно примерно как под сами данные.
    local need avail
    need="$(du -sk "$dir" 2>/dev/null | cut -f1)"
    avail="$(df -Pk "$DEST" | awk 'NR==2 {print $4}')"
    if [ -n "$need" ] && [ "$avail" -lt "$need" ]; then
        log "$name: ПРОПУСК, на $DEST свободно ${avail}K, а нужно около ${need}K"
        return 1
    fi

    log "$name: пакую в $(basename "$out")"
    if tar -czf "$out" --exclude-from="$exfile" -C "$(dirname "$dir")" "$(basename "$dir")"; then
        # Проверяем, что архив читается. Битый tar лучше заметить сейчас.
        if tar -tzf "$out" >/dev/null 2>&1; then
            log "$name: готово, $(du -h "$out" | cut -f1)"
            return 0
        fi
        log "$name: архив не читается, удаляю"
        rm -f "$out"
    fi
    return 1
}

backup_restic() {
    local name="$1" dir="$2" exfile="$3"
    log "$name: restic backup"
    if restic backup "$dir" --tag "$name" --exclude-file="$exfile" --quiet; then
        log "$name: готово"
        return 0
    fi
    return 1
}

while IFS=: read -r name dir; do
    case "$name" in ''|\#*) continue ;; esac
    [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
    [ -d "$dir" ] || { log "$name: папка $dir не найдена, пропускаю"; FAILED=1; continue; }

    EXFILE="$(build_excludes "$dir")"
    [ -f "$dir/.backupignore" ] && log "$name: учтен $dir/.backupignore"

    WAS_ON=false
    save_off "$name" && WAS_ON=true

    if [ "$MODE" = "restic" ]; then
        backup_restic "$name" "$dir" "$EXFILE" || FAILED=1
    else
        backup_tar "$name" "$dir" "$EXFILE" || FAILED=1
    fi

    $WAS_ON && save_on "$name"
    rm -f "$EXFILE"
done < "$CONF"

# Ретенция.
if [ "$MODE" = "tar" ]; then
    log "Чищу копии старше $KEEP_DAYS дней"
    find "$DEST" -maxdepth 1 -name '*.tar.gz' -type f -mtime "+$KEEP_DAYS" -print -delete
else
    log "Применяю политику хранения restic"
    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune --quiet || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
    log "ЗАВЕРШЕНО С ОШИБКАМИ"
    exit 1
fi

log "Все копии сняты"
echo
echo "Напоминание: копия на этой же машине спасает от кривого обновления, но не от"
echo "смерти диска. Отправьте архивы на другую машину или используйте MODE=restic."
