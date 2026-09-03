#!/bin/bash
# Тонкая обертка. Вся логика в ~/scripts/newLogic/start.sh.
# Аргументы: тип, имя, папка, сколько ждать старта, интервал проверки, флаги java.
bash "$HOME/scripts/newLogic/start.sh" velocity proxy "$HOME/proxy" 90 5 -Xms512M -Xmx1G
