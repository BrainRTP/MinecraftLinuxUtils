
#!/bin/bash
PS3='Что хотите запустить? '
options=("Auth" "BungeeCord" "Survival")
select opt in "${options[@]}"
do
    case $opt in
        "Auth")
            cd Auth
            chmod +x start.sh
            screen -A -dmS auth ./start.sh
            exit;
            ;;
         "BungeeCord")
            cd BungeeCord
            chmod +x start.sh
            screen -A -dmS bungee ./start.sh
            exit;
            ;;
         "Survival")
            cd Survival
            chmod +x start.sh
            screen -A -dmS survival ./start.sh
            exit;
            ;;
        *) echo invalid option;;
    esac
done
