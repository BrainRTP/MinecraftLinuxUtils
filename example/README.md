# Пример окружения

Готовая раскладка папок и конфигов, с которой скрипты из этого репозитория
работают как есть. Пиратский сервер с авторизацией на отдельном сервере Paper.

```
игрок -> Velocity 4.1.1 (25565, единственный порт наружу)
             |
             +-- auth  Paper 26.2 (127.0.0.1:25566)  вход, регистрация
             +-- main  Paper 26.2 (127.0.0.1:25567)  выживание
```

## Что здесь есть и чего нет

Репозиторий про скрипты, а не про тонкую настройку ядер. Поэтому в `velocity.toml`
и `server.properties` оставлено только то, без чего скрипты и связка прокси с
серверами не заработают: адреса, порты, `online-mode` и форвардинг. Все остальные
ключи опущены намеренно, Paper и Velocity создадут их сами при первом запуске.

Считайте эти файлы псевдокодом: они показывают, что должно совпадать между собой,
а не как настраивать сервер. За настройками ядра идите в
[документацию Paper](https://docs.papermc.io/) и
[Velocity](https://docs.papermc.io/velocity/).

Секретов тут нет: forwarding-секрет заменен плейсхолдером и генерируется свой.

```
example/
  servers.conf            список серверов для mcstart.sh и restart.sh
  backup-exclude.conf     что не тащить в бэкап
  proxy/
    velocity.toml
    start.sh              тонкая обертка над newLogic/start.sh
    version               какую версию качает mc-jar.sh
  authServer/
    server.properties
    start.sh
    version
  mainServer/
    server.properties
    start.sh
    version
```

## Что с чем должно совпадать

Три пары значений. Разъедется любая - и связка не работает.

`server-port` каждого сервера Paper совпадает с портом в секции `[servers]`
файла `velocity.toml`. Разъехались - прокси стучится в пустоту.

`online-mode` серверов Paper совпадает с `online-mode` прокси. Разъехались -
игроки получают невнятные ошибки входа, а причину искать полдня.

Секрет из `proxy/forwarding.secret` лежит в `proxies.velocity.secret` конфига
`config/paper-global.yml` каждого сервера Paper.

Порты у всех разные, два процесса один порт не займут. Порт 25565 отдаем прокси:
это тот порт, который клиент подставляет сам, когда игрок вводит адрес без
двоеточия. Серверам Paper - что угодно дальше.

## Как развернуть

```bash
sudo adduser --disabled-password --gecos "" mc
sudo -u mc -i

git clone https://github.com/BrainRTP/MinecraftLinuxUtils.git ~/scripts
cp -r ~/scripts/example/{proxy,authServer,mainServer} ~/
cp ~/scripts/example/servers.conf ~/scripts/
cp ~/scripts/example/backup-exclude.conf ~/scripts/

openssl rand -base64 32 > ~/proxy/forwarding.secret
chmod 600 ~/proxy/forwarding.secret
```

Ядра качаем в общий каталог, симлинки расставляются сами:

```bash
sudo mkdir -p /opt/mc/jars && sudo chown mc /opt/mc/jars
~/scripts/mc-jar.sh velocity 4.1.1 ~/proxy
~/scripts/mc-jar.sh paper 26.2 ~/authServer
~/scripts/mc-jar.sh paper 26.2 ~/mainServer
```

Поднимаем и заходим в консоль:

```bash
~/scripts/mcstart.sh
tmux attach -t minecraft
```

Первый запуск создаст `config/paper-global.yml` у каждого сервера Paper. Туда
вписываем секрет и включаем форвардинг:

```yaml
proxies:
  velocity:
    enabled: true
    online-mode: false
    secret: 'содержимое proxy/forwarding.secret'
```

После этого перезапускаем: `~/scripts/restart.sh && ~/scripts/mcstart.sh`.

## Файрвол

Наружу смотрят SSH и 25565, больше ничего.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 25565/tcp
sudo ufw enable
```

Правила для 25566 и 25567 не нужны: оба сервера Paper слушают `127.0.0.1`.

Проверять надо с другой машины, а не с самой себя:

```bash
nc -zv ВАШ_IP 25565    # должен открыться
nc -zv ВАШ_IP 25566    # должен отказать
```

## Память

`-Xms` равен `-Xmx` намеренно: так куча не растет рывками во время игры.
Серверу нельзя отдавать всю память машины, оставьте системе пару гигабайт.
Раскладка в примере рассчитана на машину с 8 ГБ: прокси 1, авторизация 1,
основной 6 придется ужать до 5.

## Плагины

`servers.conf` и исключения бэкапа собраны под такой набор.

Основной сервер: LuckPerms, PlaceholderAPI, Vault, EssentialsX, WorldGuard,
FastAsyncWorldEdit, CoreProtect, AbstractMenus, DecentHolograms, TAB, GSit,
PlayerWarps, AuctionHouse, MysteryBoxes, BattlePass, LushRewards, HeadDatabase,
OvRandomTeleport, AntiRelog, WGExtender, spark.

Сервер авторизации: LimboAuth или LibreLogin, SkinsRestorer, spark.
Больше там ничего быть не должно, игроки на нем не задерживаются.

Прокси: ботфильтр (Sonar или LimboFilter), ViaVersion с ViaBackwards, LuckPerms.
ViaVersion ставится на прокси, а не на сервера Paper.

CoreProtect нужен не от гриферов, а после инцидента: только по его журналу можно
откатить действия одного игрока вместо раскатки вчерашнего бэкапа на всех.
