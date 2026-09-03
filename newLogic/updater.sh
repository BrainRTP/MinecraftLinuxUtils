#!/bin/bash
# Обертка над mc-jar.sh, сохраняет старый интерфейс: updater.sh <версия>.
# Качает свежий Paper в текущую папку под именем paper.jar.
#
# Старая версия этого скрипта ходила в papermc.io/api/v1, которого больше нет.
# Вся работа теперь в mc-jar.sh, здесь только совместимость со старыми вызовами.

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Использование: $0 <версия>   например: $0 26.2" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MC_JAR="$SCRIPT_DIR/../mc-jar.sh"

[ -x "$MC_JAR" ] || [ -f "$MC_JAR" ] || { echo "ОШИБКА: не найден $MC_JAR" >&2; exit 1; }

# Общий каталог кладем рядом с сервером, чтобы скрипт работал и без прав на /opt.
export MC_JARS_DIR="${MC_JARS_DIR:-$PWD/.jars}"

bash "$MC_JAR" paper "$VERSION"

LATEST="$(find "$MC_JARS_DIR" -maxdepth 1 -name "paper-$VERSION-*.jar" -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)"
[ -n "$LATEST" ] || { echo "ОШИБКА: ядро не скачалось" >&2; exit 1; }

ln -sfn "$LATEST" paper.jar
echo "paper.jar -> $LATEST"
