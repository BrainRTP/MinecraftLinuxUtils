#!/bin/bash
# Переключение версий на одной папке сервера. Для тестов и для мультиверсионных сборок.
#
# Старая версия копировала папки туда-обратно при каждом запуске: долго и есть шанс
# потерять мир, если копирование оборвется. Здесь вместо копий симлинки, переключение
# мгновенное и данные не двигаются с места.
#
#   ./ms.sh              выбрать версию из списка
#   ./ms.sh 26.2         переключиться сразу
#   ./ms.sh --add 26.3   завести новую версию
#
# Раскладка:
#   versions/<версия>/plugins/
#   versions/<версия>/world/ world_nether/ world_the_end/
# В корне сервера plugins и миры становятся симлинками на выбранную версию.

set -uo pipefail

cd "$(dirname "$0")" || exit 1
SCRIPT_DIR="$PWD"
VERSIONS_DIR="$SCRIPT_DIR/versions"
CURRENT_FILE="$SCRIPT_DIR/.current-version"
LINKED=(plugins world world_nether world_the_end)

die() { echo "ОШИБКА: $*" >&2; exit 1; }

add_version() {
    local v="$1"
    [ -n "$v" ] || die "укажите версию"
    mkdir -p "$VERSIONS_DIR/$v"/{plugins,world,world_nether,world_the_end}
    echo "$v" > "$VERSIONS_DIR/$v/version"
    echo "Заведена версия $v в $VERSIONS_DIR/$v"
    echo "Разложите туда плагины и миры, потом: ./ms.sh $v"
}

switch_to() {
    local v="$1"
    local base="$VERSIONS_DIR/$v"
    [ -d "$base" ] || die "версия $v не заведена. Сначала: ./ms.sh --add $v"

    # В корне могут лежать настоящие папки с данными, симлинком их заменять нельзя.
    # Если место в versions свободно, переносим сами. Если занято - решает человек.
    for item in "${LINKED[@]}"; do
        [ -e "$SCRIPT_DIR/$item" ] || continue
        [ -L "$SCRIPT_DIR/$item" ] && continue

        if [ ! -e "$base/$item" ] || [ -z "$(ls -A "$base/$item" 2>/dev/null)" ]; then
            rmdir "$base/$item" 2>/dev/null
            mv "$SCRIPT_DIR/$item" "$base/$item" || die "не смог перенести $item"
            echo "Перенесено: $item -> $base/$item"
        else
            die "и в корне, и в $base лежит непустая папка $item.
       Что из этого нужное, скрипт решать не берется. Разберите руками:
         ls -la '$SCRIPT_DIR/$item'
         ls -la '$base/$item'
       Лишнее уберите, потом запустите скрипт снова."
        fi
    done

    for item in "${LINKED[@]}"; do
        mkdir -p "$base/$item"
        ln -sfn "$base/$item" "$SCRIPT_DIR/$item"
    done

    echo "$v" > "$CURRENT_FILE"
    echo "$v" > "$SCRIPT_DIR/version"

    if [ -f "$SCRIPT_DIR/../mc-jar.sh" ]; then
        bash "$SCRIPT_DIR/../mc-jar.sh" paper "$v" "$SCRIPT_DIR" \
            || echo "ВНИМАНИЕ: ядро не обновилось, положите jar руками"
    else
        echo "mc-jar.sh рядом не найден, ядро под $v положите сами"
    fi

    echo "Переключено на $v"
}

case "${1:-}" in
    --add) add_version "${2:-}"; exit 0 ;;
    "") ;;
    *) switch_to "$1"; exit 0 ;;
esac

[ -d "$VERSIONS_DIR" ] || die "нет папки versions. Начните с: ./ms.sh --add 26.2"

mapfile -t LIST < <(find "$VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V)
[ ${#LIST[@]} -gt 0 ] || die "в versions пусто. Начните с: ./ms.sh --add 26.2"

CURRENT="$(cat "$CURRENT_FILE" 2>/dev/null || echo '-')"
echo "Текущая версия: $CURRENT"
echo "Доступные:"
for i in "${!LIST[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${LIST[$i]}"
done

read -rp "Номер: " N
[[ "$N" =~ ^[0-9]+$ ]] || die "нужно число"
[ "$N" -ge 1 ] && [ "$N" -le ${#LIST[@]} ] || die "нет такого номера"

switch_to "${LIST[$((N - 1))]}"
