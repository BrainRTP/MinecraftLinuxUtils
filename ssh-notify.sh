#!/bin/bash
# Уведомление в Telegram при входе на сервер по SSH.
#
# Вешается через PAM, а не через /etc/profile.d. Разница существенная: хук на profile.d
# срабатывает только при запуске интерактивной оболочки и молчит при SFTP и при
# "ssh сервер команда". PAM ловит любой вход.
#
# Установка:
#   install -m 750 ssh-notify.sh /usr/local/bin/ssh-notify
#   install -m 600 ssh-notify.conf.example /etc/ssh-notify.conf   и заполнить
#   в конец /etc/pam.d/sshd добавить строку:
#       session optional pam_exec.so seteuid /usr/local/bin/ssh-notify
#
# Перезапускать sshd не нужно, PAM читает конфиг на каждую сессию.
#
# ВАЖНО: скрипт обязан всегда возвращать 0. Ненулевой код из pam_exec способен
# заблокировать вход на сервер. Поэтому здесь нет set -e и везде стоит "|| true".

CONF="/etc/ssh-notify.conf"

# Реагируем только на открытие сессии, иначе на каждый вход придет два сообщения.
[ "${PAM_TYPE:-}" = "open_session" ] || exit 0

[ -r "$CONF" ] || exit 0
# shellcheck disable=SC1090
. "$CONF" 2>/dev/null || exit 0

[ -n "${TG_TOKEN:-}" ] || exit 0
[ -n "${TG_CHAT_ID:-}" ] || exit 0

# Свои же адреса не спамят: перечислите их в IGNORE_HOSTS через пробел.
for skip in ${IGNORE_HOSTS:-}; do
    [ "${PAM_RHOST:-}" = "$skip" ] && exit 0
done

HOSTNAME_S="$(hostname -f 2>/dev/null || hostname)"
WHEN="$(date '+%d.%m.%Y %H:%M:%S %Z')"

TEXT="Вход по SSH
Сервер: ${HOSTNAME_S}
Пользователь: ${PAM_USER:-?}
Откуда: ${PAM_RHOST:-локально}
Сервис: ${PAM_SERVICE:-?}
Время: ${WHEN}"

# В фоне и с таймаутом, чтобы медленная сеть не задерживала вход.
(
    curl -s -m 10 -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=${TEXT}" \
        --data-urlencode "disable_web_page_preview=true" >/dev/null 2>&1
) &

exit 0
