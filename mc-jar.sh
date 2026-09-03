#!/bin/bash
# Качает ядро Paper или Velocity в общий каталог и раскладывает симлинки по серверам.
# Смысл в атомарности: один файл на все сервера, обновился один раз - обновились все.
#
#   ./mc-jar.sh paper 26.2                     скачать, если появился новый билд
#   ./mc-jar.sh paper 26.2 /home/mc/main       то же плюс симлинк в папку сервера
#   ./mc-jar.sh velocity 3.4.0-SNAPSHOT /home/mc/proxy
#
# Требует curl и jq.

set -euo pipefail

JARS_DIR="${MC_JARS_DIR:-/opt/mc/jars}"
API="https://fill.papermc.io/v3/projects"
# Брать только стабильные сборки. MC_ALLOW_EXPERIMENTAL=1 разрешает остальные.
ALLOW_EXPERIMENTAL="${MC_ALLOW_EXPERIMENTAL:-0}"

die() { echo "ОШИБКА: $*" >&2; exit 1; }

for cmd in curl jq; do
    command -v "$cmd" >/dev/null || die "нужен $cmd (apt install $cmd)"
done

PROJECT="${1:-}"
VERSION="${2:-}"
TARGET_DIR="${3:-}"

if [ -z "$PROJECT" ] || [ -z "$VERSION" ]; then
    echo "Использование: $0 <paper|velocity> <версия> [папка сервера]"
    echo "Список версий:  curl -s $API/paper | jq '.versions'"
    exit 1
fi

mkdir -p "$JARS_DIR"

echo "Спрашиваю последний билд $PROJECT $VERSION..."
BUILD_JSON="$(curl -fsSL "$API/$PROJECT/versions/$VERSION/builds/latest")" \
    || die "не смог получить данные о сборке. Проверьте название версии."

BUILD="$(jq -r '.id' <<<"$BUILD_JSON")"
CHANNEL="$(jq -r '.channel' <<<"$BUILD_JSON")"
NAME="$(jq -r '.downloads["server:default"].name' <<<"$BUILD_JSON")"
URL="$(jq -r '.downloads["server:default"].url' <<<"$BUILD_JSON")"
SHA="$(jq -r '.downloads["server:default"].checksums.sha256' <<<"$BUILD_JSON")"

[ "$NAME" != "null" ] || die "в ответе API нет файла сборки"

if [ "$CHANNEL" != "STABLE" ] && [ "$ALLOW_EXPERIMENTAL" != "1" ]; then
    die "последний билд $BUILD имеет канал $CHANNEL. Запустите с MC_ALLOW_EXPERIMENTAL=1, если это осознанно."
fi

JAR="$JARS_DIR/$NAME"

if [ -f "$JAR" ] && [ "$(sha256sum "$JAR" | cut -d' ' -f1)" = "$SHA" ]; then
    echo "Уже актуально: $NAME (билд $BUILD, $CHANNEL)"
else
    echo "Качаю $NAME (билд $BUILD, $CHANNEL)..."
    TMP="$(mktemp "$JARS_DIR/.download.XXXXXX")"
    trap 'rm -f "$TMP"' EXIT
    curl -fSL --progress-bar -o "$TMP" "$URL" || die "скачивание не удалось"

    GOT="$(sha256sum "$TMP" | cut -d' ' -f1)"
    [ "$GOT" = "$SHA" ] || die "контрольная сумма не совпала. Ожидалось $SHA, получено $GOT"

    mv "$TMP" "$JAR"
    chmod 644 "$JAR"
    trap - EXIT
    echo "Готово: $JAR"
fi

# Симлинк с именем сервера в названии, чтобы в ps auxfww было видно, кто есть кто.
if [ -n "$TARGET_DIR" ]; then
    [ -d "$TARGET_DIR" ] || die "папка $TARGET_DIR не найдена"
    SERVER_NAME="$(basename "$TARGET_DIR")"
    LINK="$TARGET_DIR/$SERVER_NAME-$PROJECT.jar"

    ln -sfn "$JAR" "$LINK"
    echo "Симлинк: $LINK -> $JAR"
    echo "В скрипте запуска указывайте именно $SERVER_NAME-$PROJECT.jar"
fi

# Оставляем три последние сборки этого проекта и версии, остальные удаляем.
KEEP=3
mapfile -t OLD < <(find "$JARS_DIR" -maxdepth 1 -name "$PROJECT-$VERSION-*.jar" -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | tail -n +$((KEEP + 1)) | cut -d' ' -f2-)
for f in "${OLD[@]:-}"; do
    [ -n "$f" ] || continue
    # Не трогаем то, на что кто-то ссылается.
    if find /opt /home /srv -maxdepth 4 -type l -lname "$f" 2>/dev/null | grep -q .; then
        continue
    fi
    echo "Удаляю старую сборку: $(basename "$f")"
    rm -f "$f"
done
