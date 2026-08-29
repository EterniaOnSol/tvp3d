# Prueba viva de muerte, corpse y loot

Fecha: 2026-08-29
Carril: qa
Servidor: TVP 7.72 en Docker, `servidor-server-1`, puertos 7171/7172

## Que prueba y que no

Esta prueba habla con el servidor autoritativo y solo afirma lo que el
servidor confirmo. No simula paquetes, no inventa un opcode de muerte —esta
rama no tiene `sendDeath` ni `sendReLoginWindow`— y no decide por su cuenta
que un personaje murio: consume la senal `jugador_muerto` que emite
`cliente3d/red/estado_mundo.gd` cuando el `0x6C` retira a `mi_id` con las
stats autoritativas en vida cero.

Archivo: `cliente3d/pruebas/prueba_muerte_loot_vivo.tscn`.

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d ^
  pruebas/prueba_muerte_loot_vivo.tscn
```

Media prueba repetible sin costo para ningun personaje:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d ^
  pruebas/prueba_muerte_loot_vivo.tscn -- --solo-loot
```

## Etapas

| Etapa | Que hace | Que comprueba |
|---|---|---|
| SONDEO | Entra con el personaje normal, anota su casilla y sale con logout | Nada; solo configura el duelo donde el personaje ya esta |
| PREPARAR | Entra con el personaje god, `/gotopos` a esa casilla y `/m demon` | El god llega y el servidor invoca al verdugo |
| MUERTE | Vuelve a entrar con el personaje normal y no envia ninguna intencion | Vida autoritativa cero, corpse del jugador en la casilla, `jugador_muerto`, logout `0x14` y cierre de sesion por el servidor |
| REENTRADA | Vuelve a entrar | El personaje esta vivo y no en el sitio de la muerte |
| LOOT | Con el god: `/killall` limpia al verdugo, `/m rat`, se lo mata y se abre su corpse con `0x82` | El corpse es un contenedor real y su contenido es el que puso `Monster::dropLoot` |

La etapa LOOT se teletransporta siempre a `32082,32145,6`, una casilla
comprobada fuera de zona de proteccion, y limpia el demon que ella misma
creo.

## Resultado del 2026-08-29

Mitad de muerte, corrida completa, salida textual del servidor:

```text
Dentro con Valentino en el sitio del duelo. No se envia nada.
  [srv] You lose 27 hitpoints due to an attack by a demon.
  corpse del jugador en (32082, 32145, 6): dead human
  [srv] You are dead.
  [srv] You were downgraded from Level 3 to Level 2.
MUERTE confirmada por el servidor en (32082, 32145, 6).
  OK  la muerte llega con vida autoritativa cero
  OK  la muerte deja al jugador fuera del mundo
  OK  el servidor dejo el corpse del jugador en su casilla
El servidor corto la conexion despues del logout 0x14.
  OK  el logout tras morir termina la sesion
Reingreso confirmado en (32369, 32241, 7) con vida 145.
  OK  la reentrada deja al personaje vivo
  OK  la reentrada no devuelve al personaje al sitio de la muerte
```

Mitad de corpse y loot, dos corridas independientes con `--solo-loot`:

```text
Invocado rat con id 1073764898 en (32081, 32144, 6). Se ataca con 0xA1.
El monstruo murio y dejo corpse en (32081, 32143, 6): dead rat
  OK  el monstruo muerto deja un corpse contenedor
Corpse abierto como contenedor 0: 'dead rat' con 1 cosas.
   loot: gold coin x3
  OK  el corpse del monstruo se abre como contenedor real
  OK  el nombre del corpse nombra al monstruo
Prueba viva de muerte, corpse y loot: OK
```

La segunda corrida devolvio `gold coin x4`: el loot lo decide el servidor en
cada muerte y el cliente solo lo muestra.

Lo que queda comprobado con esto:

- El servidor deja corpse del jugador (`dead human`) antes de retirarlo.
- El `0x6C` de `mi_id` con vida cero es la unica senal de muerte de la rama.
- El logout `0x14` posterior termina la sesion, tal como hace
  `ProtocolGame::logout` cuando el jugador ya fue removido.
- El reingreso devuelve un personaje vivo en su templo.
- El corpse de un monstruo se abre como contenedor y su loot es el del
  servidor.

## Precondicion que sigue siendo manual

El duelo ocurre donde el personaje normal esta parado. Despues de morir, el
servidor lo devuelve al templo, y **dentro de una zona de proteccion ningun
monstruo puede atacarlo**: `Monster::selectTarget` rechaza cualquier objetivo
en `ZONE_PROTECTION` y `Game.createMonster` tampoco deja invocar ahi.

Por eso, para repetir la corrida completa hay que dejar antes al personaje
fuera del templo. La prueba no camina sola: hacerlo a ciegas no saca a nadie
de la zona de proteccion —se probo y avanza apenas unas casillas— y un
auto-walk inventado seria justamente la clase de intencion del cliente que
esta prueba no debe simular. Cuando la precondicion no se cumple, la etapa de
duelo lo dice con todas las letras en vez de quedarse colgada:

```text
FAIL Nadie ataca a Valentino en (32369, 32248, 7). Suele ser zona de
proteccion: sacalo del templo antes de repetir la prueba.
```

Pendiente para automatizarla del todo: reusar el pathfinding real del cliente
para llevar al personaje a una casilla abierta, o dejar que el god arme un
teleport con `/i` y `/attr destination` junto a la casilla de entrada.

La mitad de corpse y loot no tiene esta precondicion y se repite sola con
`--solo-loot`.

## Efectos de una corrida completa

- El personaje normal pierde nivel y experiencia segun `Player::death`. En la
  corrida del 2026-08-29 bajo de nivel 3 a nivel 2.
- Sus objetos quedan en el corpse `dead human` de la casilla del duelo, y ahi
  siguen hasta que alguien los recoge o el servidor los descompone.
- El demon invocado lo retira la propia prueba con `/killall`.

Para restaurar el personaje sin tocar el juego a mano estan la semilla
`servidor/docker/data/02-data.sql` y los archivos `servidor/gamedata/players/`
versionados en el repositorio.
