#!/bin/bash
# Сбор информации о системе для разбора инцидента. ТОЛЬКО ЧТЕНИЕ.
# Скрипт ничего не меняет, не удаляет и не лечит: он собирает срез и пакует его в архив.
#
#   sudo bash collect-audit.sh
#
# ВНИМАНИЕ. В архиве окажутся публичные ключи, внутренние адреса, имена хостов,
# куски конфигов и история команд, где запросто найдется пароль, введенный одной строкой.
# Прежде чем показывать архив кому-то, откройте и вычистите. Приватные ключи скрипт
# не выводит, только имена файлов.
#
# Если Вы разбираете подозрение на взлом: не перезагружайте машину и ничего не удаляйте,
# пока не сняли этот срез. После перезагрузки процессы и открытые соединения пропадут.

set -uo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Запускать от root: sudo bash $0" >&2; exit 1; }

OUT="${AUDIT_OUT:-/root}/audit_$(hostname -s)_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT" || exit 1
ERRORS="$OUT/errors.log"
: > "$ERRORS"

TOTAL=0
run() {   # run <имя файла> <команда одной строкой>
    TOTAL=$((TOTAL + 1))
    # В терминале рисуем счетчик на одной строке, в лог пишем построчно.
    if [ -t 1 ]; then
        printf '\r  собрано блоков: %d  (%-22s)' "$TOTAL" "$1"
    else
        printf '  %2d %s\n' "$TOTAL" "$1"
    fi
    { echo "\$ $2"; echo; eval "$2"; } > "$OUT/$1.txt" 2>>"$ERRORS"
}

echo "Собираю в $OUT"
echo "Дольше всего думает поиск по всему диску, это нормально."
echo

# ---------- Система ----------
run os-release      "cat /etc/os-release"
run uname           "uname -a; cat /proc/version"
run uptime          "uptime; who -b"
run date            "date; timedatectl"
run virt            "systemd-detect-virt; hostnamectl"

# ---------- Железо и диски ----------
run cpu             "lscpu"
run memory          "free -h; cat /proc/meminfo | head -20"
run disk            "df -h; echo; df -i"
run blockdev        "lsblk -f; blkid"
run mounts          "mount | sort; cat /etc/fstab"

# ---------- Пользователи ----------
run passwd          "getent passwd"
run groups          "getent group"
run uid0            "awk -F: '\$3 == 0 { print }' /etc/passwd"
run login-shells    "grep -vE '(nologin|/false)\$' /etc/passwd"
run shadow-state    "awk -F: '{ print \$1, (\$2 ~ /^[!*]/ ? \"заблокирован\" : \"есть пароль\") }' /etc/shadow"
run sudoers         "cat /etc/sudoers; echo; cat /etc/sudoers.d/* 2>/dev/null"
run home-dirs       "ls -la /home /root"

# ---------- SSH ----------
run sshd-config     "cat /etc/ssh/sshd_config; echo; cat /etc/ssh/sshd_config.d/* 2>/dev/null"
run sshd-effective  "sshd -T"
run authorized-keys "find /root /home -name authorized_keys -exec echo '== {}' \; -exec ls -l {} \; -exec cat {} \;"
run ssh-dirs        "find /root /home -maxdepth 2 -name .ssh -exec ls -la {} \;"
run private-keys    "find /root /home -maxdepth 3 -name 'id_*' ! -name '*.pub' -exec ls -l {} \;"

# ---------- Процессы ----------
run ps              "ps auxfww"
run ps-cpu          "ps aux --sort=-%cpu | head -25"
run ps-mem          "ps aux --sort=-%mem | head -25"
run pstree          "pstree -ap"
run proc-tmp        "ls -l /proc/*/exe 2>/dev/null | grep -E '/tmp|/var/tmp|/dev/shm'"
run proc-deleted    "ls -l /proc/*/exe 2>/dev/null | grep deleted"
run open-deleted    "lsof +L1 2>/dev/null | head -60"

# ---------- Сеть ----------
run ip-addr         "ip -d a"
run ip-route        "ip r; ip -6 r"
run dns             "cat /etc/resolv.conf; cat /etc/hosts"
run listening       "ss -tulpn"
run established     "ss -tunp state established"
run ufw             "ufw status verbose"
run iptables        "iptables -S; iptables -t nat -S"
run nftables        "nft list ruleset"

# ---------- systemd ----------
run svc-running     "systemctl list-units --type=service --state=running --no-pager"
run svc-enabled     "systemctl list-unit-files --state=enabled --no-pager"
run svc-failed      "systemctl --failed --no-pager"
run timers          "systemctl list-timers --all --no-pager"
run sockets         "systemctl list-sockets --all --no-pager"
run units-custom    "ls -lR /etc/systemd/system/ /usr/local/lib/systemd/system/ 2>/dev/null"
run units-execstart "grep -rH '^ExecStart' /etc/systemd/system/ 2>/dev/null"
run boot-time       "systemd-analyze blame 2>/dev/null | head -25"

# ---------- Расписания ----------
run cron-root       "crontab -l"
# shellcheck disable=SC2016  # одинарные кавычки намеренно: строка разворачивается внутри eval
run cron-all        'for u in $(cut -d: -f1 /etc/passwd); do out=$(crontab -lu "$u" 2>/dev/null); [ -n "$out" ] && { echo "== $u"; echo "$out"; }; done'
run cron-etc        "cat /etc/crontab; cat /etc/cron.d/* 2>/dev/null"
run cron-dirs       "ls -lR /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly"
run anacron         "cat /etc/anacrontab 2>/dev/null"
run at-jobs         "atq 2>/dev/null; ls -l /var/spool/cron/atjobs 2>/dev/null"

# ---------- Входы и логи ----------
run last            "last -50"
run lastb           "lastb -50"
run lastlog         "lastlog"
run auth-log        "tail -400 /var/log/auth.log 2>/dev/null"
run syslog          "tail -300 /var/log/syslog 2>/dev/null"
run kern-log        "tail -200 /var/log/kern.log 2>/dev/null"
run journal-ssh     "journalctl -u ssh -u sshd --no-pager -n 200"
run journal-sudo    "journalctl -g sudo --no-pager -n 200"
run journal-boot    "journalctl --list-boots --no-pager"

# ---------- Пакеты ----------
run dpkg-list       "dpkg -l"
run apt-history     "tail -300 /var/log/apt/history.log 2>/dev/null"
run apt-upgradable  "apt list --upgradable 2>/dev/null"
run unattended      "cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; cat /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null"
run apt-sources     "cat /etc/apt/sources.list; cat /etc/apt/sources.list.d/* 2>/dev/null"
run snap            "snap list 2>/dev/null"
run docker          "docker ps -a 2>/dev/null; echo; docker images 2>/dev/null"
run scanners        "command -v rkhunter chkrootkit lynis aide 2>/dev/null"

# ---------- Файловая система ----------
run suid            "find / -xdev -perm -4000 -type f -exec ls -l {} \;"
run sgid            "find / -xdev -perm -2000 -type f -exec ls -l {} \;"
run world-writable  "find / -xdev -type f -perm -0002 ! -path '/proc/*' -exec ls -l {} \;"
run ww-dirs         "find / -xdev -type d -perm -0002 ! -perm -1000 -exec ls -ld {} \;"
run recent-etc      "find /etc -xdev -mtime -30 -type f -exec ls -l {} \;"
run recent-bin      "find /bin /sbin /usr/bin /usr/sbin /usr/local/bin -xdev -mtime -30 -type f -exec ls -l {} \;"
run tmp-dirs        "ls -laR /tmp /var/tmp /dev/shm"
run hidden-files    "find /tmp /var/tmp /dev/shm /home /root -name '.*' -maxdepth 3 -exec ls -ld {} \;"
run nouser          "find / -xdev \( -nouser -o -nogroup \) -exec ls -l {} \;"

# ---------- Загрузка библиотек и модулей ----------
run ld-preload      "cat /etc/ld.so.preload 2>/dev/null || echo 'файла нет, это норма'"
run ld-conf         "cat /etc/ld.so.conf; cat /etc/ld.so.conf.d/* 2>/dev/null"
run recent-so       "find /lib /usr/lib /usr/local/lib -name '*.so*' -mtime -30 -exec ls -l {} \;"
run lsmod           "lsmod"
run proc-modules    "cat /proc/modules"
run modprobe        "cat /etc/modprobe.d/* 2>/dev/null"
run dkms            "dkms status 2>/dev/null"

# ---------- Автозапуск оболочек и PAM ----------
run pam-d           "ls -la /etc/pam.d/; echo; cat /etc/pam.d/sshd /etc/pam.d/common-auth /etc/pam.d/common-session"
run security-conf   "ls -la /etc/security/; cat /etc/security/limits.conf 2>/dev/null | grep -v '^#'"
run profile         "cat /etc/profile; echo; cat /etc/profile.d/* 2>/dev/null"
run bashrc          "cat /etc/bash.bashrc; for f in /root/.bashrc /root/.profile /home/*/.bashrc /home/*/.profile; do [ -f \"\$f\" ] && { echo \"== \$f\"; cat \"\$f\"; }; done"
run zshrc           "for f in /root/.zshrc /home/*/.zshrc; do [ -f \"\$f\" ] && { echo \"== \$f\"; cat \"\$f\"; }; done"
run history         "for f in /root/.bash_history /home/*/.bash_history /root/.zsh_history /home/*/.zsh_history; do [ -f \"\$f\" ] && { echo \"== \$f\"; tail -200 \"\$f\"; }; done"
run history-suspect "grep -hiE 'curl|wget|base64|chattr|nc |netcat|chmod \+x|/dev/tcp' /root/.bash_history /home/*/.bash_history 2>/dev/null"

[ -t 1 ] && printf '\r%-60s\n' "  собрано блоков: $TOTAL"

# Пустые файлы только мешают читать.
find "$OUT" -type f -size -12c -delete 2>/dev/null
[ -s "$ERRORS" ] || rm -f "$ERRORS"

ARCHIVE="$OUT.tar.gz"
tar -czf "$ARCHIVE" -C "$(dirname "$OUT")" "$(basename "$OUT")" 2>/dev/null
chmod 600 "$ARCHIVE"

echo
echo "Готово."
echo "  Папка:  $OUT"
echo "  Архив:  $ARCHIVE  ($(du -h "$ARCHIVE" | cut -f1))"
echo
echo "С чего начать чтение:"
echo "  uid0.txt          строка должна быть одна, про root"
echo "  authorized-keys   ключей столько же, сколько у Вас машин?"
echo "  proc-tmp.txt      процессы из /tmp и /dev/shm почти всегда лишние"
echo "  ld-preload.txt    на обычной Ubuntu этого файла нет"
echo "  timers.txt        таймеры systemd сейчас популярнее cron"
echo "  last.txt          успешные входы важнее неудачных из lastb"
echo
echo "Перед тем как показывать архив кому-либо - откройте и вычистите секреты."
