#!/bin/bash
# -Xms равен -Xmx намеренно: так куча не растет рывками во время игры.
bash "$HOME/scripts/newLogic/start.sh" paper mainServer "$HOME/mainServer" 240 20 -Xms6G -Xmx6G
