# La página web de TVP3D

Es donde la gente se hace la cuenta y el personaje, y desde donde se ve
quién está online y los highscores. Está en **http://localhost:8072**.

Corre en su propio contenedor de Docker, aparte del servidor del juego,
pero **usa la misma base de datos**: una cuenta creada en la web sirve
para entrar al juego enseguida, sin copiar nada a mano.

**Probado de punta a punta el 27 de agosto de 2026.** Se creó la cuenta
`555111` desde el formulario de la web con el personaje `Test Web Uno`, y
después `pruebas/prueba_login.tscn` entró con esa cuenta al servidor de
verdad: apareció el personaje en la lista, entró al mundo (2.246 bytes de
mapa en el primer mensaje) y caminó para los cuatro lados. La cuenta de
prueba se borró después.

---

## Los botones

| Archivo (están en `TVP3D\`) | Qué hace |
|---|---|
| `ARRANCAR WEB.bat` | Prende la web y abre el navegador |
| `VER WEB.bat` | Muestra en vivo lo que dice la web (errores de PHP) |
| `PARAR WEB.bat` | Apaga la web (el juego sigue prendido) |
| `INSTALAR PLUGIN WEB.bat` | Instala un plugin o tema que dejes en `web\plugins-zip` |

**Primero el servidor, después la web.** La red de Docker la crea
`ARRANCAR SERVIDOR.bat`; la web solo se engancha. Si arrancás la web
sola, te avisa y no hace nada.

La primera vez tarda varios minutos: arma la imagen de PHP, baja las
librerías de MyAAC con composer y jquery/bootstrap/tinymce con npm.
Después arranca en segundos. Se sabe que terminó cuando en `VER WEB.bat`
aparece `>> Web lista en http://localhost:8072`.

---

## Las claves

| Para qué | Cuenta | Clave |
|---|---|---|
| Jugar (la de siempre) | `123456` | `123456` |
| Administrar la web | `100777` | `tvp3d2026` |

El panel de administrador está en **http://localhost:8072/admin**.

**Por qué son dos cuentas distintas.** En Tibia la clave de la web y la
del juego son la misma: las dos salen de `accounts.password`. MyAAC exige
que la clave del administrador tenga entre 8 y 30 caracteres con al menos
una letra y un número, y `123456` no cumple. Ponerle una clave nueva a la
cuenta 123456 habría roto el login del cliente, así que el administrador
vive en una cuenta aparte (`100777`, con el personaje `Tvp Admin`) y la
123456 quedó intacta.

Para cambiar la clave del admin: entrar a la web con `100777`, ir a
*Account Management* → *Change Password*.

---

## Qué es cada cosa

```
web/
  myaac/            MyAAC 2.0-alpha (rama develop). Es la web en sí.
  Dockerfile        PHP 8.3 + Apache + composer + node
  arranque.sh       Lo que corre el contenedor al prender
  docker-compose.yml
  plugins-zip/      Buzón: los .zip de plugins/temas van acá
  cuenta-admin.sql  Crea la cuenta 100777 del administrador
  personaje-molde.sql  Crea la cuenta 1 (ver más abajo)
```

**El tema es el Canary** (`myaac-theme-canary-v2.0.1.zip`), que hace que
se vea como la web oficial de Tibia. Ya está instalado y elegido.

---

## Las tres cosas que hubo que ajustar

MyAAC está pensado para servidores modernos (TFS 1.x / Canary) y TVP es
un 7.72. Tres diferencias importaron:

**1. La cuenta es un número, no un nombre.** La tabla `accounts` de TVP no
tiene columna `name` — la cuenta *es* el `id`, como en el Tibia viejo.
MyAAC se da cuenta solo (`system/init.php:151`) y pasa a modo "Account
Number". Al registrarse, la gente elige su número de 6 a 10 cifras.

**2. MyAAC le agregó columnas a la base del juego.** Al instalarse corrió
`install/tools/5-database.php`, que agrega a `accounts` (`key`, `created`,
`rlname`, `location`, `country`, `web_lastlogin`, `web_flags`, los
`email_*` y `premium_points`) y a `players` (`created`, `hide`,
`comment`). **Todas se agregan con valor por defecto y ninguna se borra
ni se renombra**, así que el servidor sigue leyendo lo suyo sin enterarse.
Aparte creó sus propias tablas `myaac_*`, que son solo de la web.

**3. Los personajes nuevos se copian de un molde.** MyAAC no inventa un
personaje: copia uno que ya existe (`system/src/CreateCharacter.php:124`).
Los moldes los creó él solo al terminar de instalarse, pero los cuelga de
la cuenta número 1 sin fijarse si existe. En TVP la tabla `players` tiene
una clave foránea contra `accounts`, así que sin esa cuenta la instalación
se corta a la mitad — por eso está `personaje-molde.sql`.

El molde que se usa es **`Rook Sample`**: nivel 1, sin vocación, 150 de
vida, 0 de maná, 100 de alma, pueblo 1 (Rookgaard), todas las skills en
10. Son los mismos valores con los que TVP arranca un personaje, sacados
de `servidor/docker/data/02-data.sql`. Se le corrigió el outfit a 128
(el ciudadano de 7.x); MyAAC lo cambia solo a 136 si eligen mujer.

**Todos empiezan en Rookgaard, sin vocación.** En la configuración quedó
un solo molde (`0=Rook Sample`) y un solo pueblo (`10`), así que el
formulario ni siquiera pregunta vocación ni ciudad. Los otros moldes
(`Sorcerer Sample`, `Druid Sample`, `Paladin Sample`, `Knight Sample`)
quedaron escondidos por si algún día se abren las vocaciones. El
`Monk Sample` se borró: la vocación 9 no existe en 7.72
(`servidor/data/XML/vocations.xml` llega hasta la 8).

---

## Cuidado: Rookgaard es el pueblo **10**, no el 1

Esto casi se pasa por alto y habría mandado a todos los novatos a Thais.

De la tabla `towns` del servidor (la llena el `.otbm` al arrancar):

```
 1  Thais          10  Rookgaard
```

El `02-data.sql` de TVP confunde: pone a `GOD VALENTINO` en `town_id = 1`
pero con las coordenadas del templo de Rookgaard. Le funciona porque ese
personaje tiene su posición escrita a mano; uno recién creado no.

Importa porque **TVP saca `sex`, `vocation` y `town_id` de la base de
datos siempre** — lo dice su propio comentario en
`servidor/src/iologindata.cpp:175`, *"Due to OTServers AACs, we have to
set these from the DB all the time"*. El resto (vida, maná, skills,
mochila, ropa) **no** sale de la base: el personaje nuevo se arma con
`servidor/gamedata/players/male.dat` y `female.dat`, que traen
`Position = [32097,32219,7]` (el templo de Rookgaard) y el equipo inicial.
Ninguno de los dos define pueblo, así que el `town_id` de la base es la
única fuente — y es lo que decide adónde vuelve el personaje al morir.

Por eso la configuración dice `10`, y el molde `Rook Sample` también.

---

## El control anti-spam quedó apagado, a propósito

MyAAC trae dos protecciones por IP: una cuenta cada 10 minutos
(`account_create_ip_block_cooldown`) y baneo de IP tras varios logins
fallidos (`account_login_ipban_protection`). Las dos quedaron **apagadas**.

El motivo es que, con Docker en Windows, Apache ve a **todo el mundo con
la misma IP** (`172.22.0.1`, que es la puerta de enlace de Docker, no la
del visitante). Con esas protecciones prendidas, la primera persona que
se registrara le bloquearía el registro a todas las demás por 10 minutos,
y un desconocido tecleando mal la clave las banearía a todas.

**Si algún día la web sale a internet**, hay que volver a prenderlas y
poner un proxy adelante que pase la IP real (`X-Forwarded-For` +
`mod_remoteip`), o instalar el plugin de recaptcha de MyAAC.

---

## Cosas que no funcionan, y no importan

Al instalarse, MyAAC quiso cargar las bibliotecas de monstruos, hechizos
y armas del servidor y no pudo:

```
Cannot load monsters.xml. File is invalid.
Cannot load spells.xml. File not found.
Cannot load file /srv/tvp/data/weapons/weapons.xml
```

Es esperable: TVP tiene los monstruos y los hechizos en **Lua**, no en los
XML que MyAAC sabe leer. Lo único que se pierde son las páginas de
consulta ("Monsters", "Spells"). **La creación de cuentas y personajes,
los highscores, quién está online y el panel de administrador no dependen
de eso** y andan bien.

Los items y los pueblos sí cargaron.

---

## De dónde saca la clave de la base de datos

De ningún lado que haya que configurar: MyAAC lee
`servidor/config.lua` (`mysqlHost`, `mysqlUser`, `mysqlPass`,
`mysqlDatabase`) y se conecta con eso. Por eso el `docker-compose.yml`
monta la carpeta del servidor en `/srv/tvp` **de solo lectura** (`:ro`):
la web necesita leerla, pero no puede tocar ni un archivo del juego.

Si alguna vez cambiás la clave de MySQL en `config.lua`, la web se entera
sola.

---

## Abrirla a internet

Hoy la web solo se ve desde esta PC (`localhost:8072`). Para que entren
de afuera hace falta, además, abrir el puerto en el router o levantar un
túnel (tipo Cloudflare Tunnel), y cambiar `site_url` en el panel de
administrador de `http://localhost:8072/` al dominio real. Eso todavía no
está hecho.
