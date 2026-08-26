# Docker Compose instruction

To run OTS in `docker compose` on Windows, you have to install Docker Desktop for Windows:

https://docs.docker.com/desktop/setup/install/windows-install/

It's the hardest part of running OTS in docker, but it is pretty automated in 2026.
A few years ago it was like 60 minutes of typing PowerShell commands and PC restarts. Now it's just a few clicks and probably 1 PC restart.

With Docker Compose, OTS will compile and run on Linux, but you will be able to connect to it from Windows using Tibia Client/OTClient.

All files - except C++ - and in real-time synchronization between Windows and Linux. You can modify .lua/.xml files ex. `config.lua` and use `/reload config` GOD to reload config.

C++ changes are only noticed on docker compose restart with `--build` option. The more information below.

## Configuration required for docker in `config.lua`

You have to set it up to connect to `mariadb` host:
```lua
mysqlHost = "mariadb"
mysqlUser = "root"
mysqlPass = "root"
mysqlDatabase = "tvp"
mysqlPort = 3306
```
> From Windows point of view, MariaDB runs on port `3371`, but inside `docker compose` network, it's on port `3306`

## Access

The default account with the GOD character is:
```
123456
123456
```

`docker/02-data.sql` contains initial database structure and data.

- **OTS**: ports 7171, 7172
- **phpMyAdmin**: http://localhost:8071
    - User: `root`
    - Password: `root`
- **MariaDB**: localhost:3371
    - User: `root`
    - Password: `root`
    - Database: `tvp`

## Docker Compose management

### Compile C++ sources and start

Make docker compose detect if there are changes in C++/CMake files, and if there are, compile the engine before starting:
```bash
docker-compose up --build
```
> You can always use this command. It won't waste time to compile C++ if there are no changes in C++ files since the last build.

### Start (without C++ compilation)

Make docker compose start the last C++ build, it won't check for changes in C++:
```bash
docker-compose up
```

### Stop

Press `CTRL+C` in the terminal with docker or in separate terminal type:
```bash
docker-compose stop
```

### Stop and remove docker containers

Disable auto-start on Windows startup:
```bash
docker-compose down
```

### Reset Database

By default, up/stop/down will keep database structure and data.

To remove database data, you have to remove its 'docker volume'.

To remove all docker compose volumes, execute `down` with `-v` parameters:
```bash
docker-compose down -v
```
On the next start (build), it will load clean database schema and data.
