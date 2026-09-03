#!/bin/bash
# Серверу авторизации много памяти не нужно: игроки на нем не задерживаются.
bash "$HOME/scripts/newLogic/start.sh" paper authServer "$HOME/authServer" 120 7 -Xms1G -Xmx1G
