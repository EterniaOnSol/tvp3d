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

Tercer modo, solo la precondicion, sin que muera nadie:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d ^
  pruebas/prueba_muerte_loot_vivo.tscn -- --solo-campo
```

## Etapas

| Etapa | Que hace | Que comprueba |
|---|---|---|
| DUELO | El personaje normal entra y se queda. En paralelo, por su propia conexion, el god va al campo con `/gotopos`, trae al personaje con `/c` y deja un demon con `/m` | El god llega al campo, el personaje termina en el campo segun su propia sesion, y el servidor invoca al verdugo |
| MUERTE | El personaje normal no envia ninguna intencion | Vida autoritativa cero, corpse del jugador en la casilla, `jugador_muerto`, logout `0x14` y cierre de sesion por el servidor |
| REENTRADA | Vuelve a entrar | El personaje esta vivo y no en el sitio de la muerte |
| LOOT | Con el god: `/killall` limpia al verdugo, `/m rat`, se lo mata y se abre su corpse con `0x82` | El corpse es un contenedor real y su contenido es el que puso `Monster::dropLoot` |

El campo es siempre `32082,32145,6`, una casilla comprobada fuera de zona de
proteccion. La prueba limpia el demon que ella misma creo.

## La precondicion ya no es manual

El duelo exige que el personaje este fuera de una zona de proteccion, y el
templo lo esta. Quien lo saca de ahi es el servidor, no el cliente:

1. El god se para en el campo con `/gotopos`.
2. El god dice `/c <personaje>`
   (`data/scripts/talkactions/god/teleport_creature_here.lua`), que mueve a la
   criatura a la casilla libre mas cercana a quien lo dijo.
3. La prueba confirma el resultado con la sesion del propio personaje: su
   posicion autoritativa, no la del god.

El cliente no camina, no usa pathfinding y no simula ninguna intencion: la
unica orden es una talkaction del servidor. Si esa casilla dejara de servir, la
etapa del duelo lo dice al no recibir ningun golpe en 30 segundos.

`--solo-campo` hace solo esa parte, retira el verdugo con `/killall` antes de
que mate a nadie y devuelve el personaje a su templo con `omani`
(`data/scripts/talkactions/gamemasters/teleport_creature_to_town.lua`). Es
repetible y no le cuesta un nivel a nadie.

Dos detalles del servidor que la prueba respeta:

- `Ban::acceptConnection` (`servidor/src/ban.cpp:13-45`) bloquea a quien abre
  mas de cinco conexiones en cinco segundos desde la misma IP. La prueba
  aprende los puertos en un unico login y separa cada sesion nueva seis
  segundos.
- El campo es campo abierto: hay ratas y arañas salvajes, y corpses de
  corridas anteriores. La mitad de loot solo acepta la criatura cuyo id no
  existia antes de su `/m` y el corpse de una casilla que no tenia corpse
  antes de la caza.

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

## Resultado del 2026-08-29, segunda vuelta

Con la precondicion automatica, tres corridas completas seguidas llevaron al
personaje del templo al campo y lo hicieron morir sin tocar nada:

```text
Valentino entro en (32369, 32241, 7).
Dentro con GOD VALENTINO para armar el campo.
  OK  el god llego al campo fuera de zona de proteccion
Trayendo a Valentino al campo con /c.
El servidor movio a Valentino de (32369, 32241, 7) a (32081, 32145, 6).
  OK  el personaje esta en el campo del duelo, junto al god
  OK  el servidor invoco al demon en el campo
  [srv] You lose 125 hitpoints due to an attack by a demon.
  corpse del jugador en (32081, 32145, 6): dead human
  [srv] You are dead.
```

`--solo-campo` termina en codigo cero con cinco comprobaciones: god en el
campo, personaje en el campo, verdugo invocado, verdugo retirado y personaje
devuelto a su templo.

`--solo-loot` termina en codigo cero: invoca su propia rata, la mata, abre el
corpse `dead rat` y lee lo que decidio el servidor —`gold coin x3`, `x4`,
`cheese x1` y una vez ningun objeto, que tambien es una respuesta valida de
`Monster::dropLoot`.

## Lo que destapo el duelo repetible

La corrida completa **no** termina en verde. Al poder repetir la muerte
aparecieron dos fallos que antes quedaban tapados por la precondicion manual.

### 1. La muerte de un golpe no emite `jugador_muerto`

En las tres corridas completas del 2026-08-29 por la tarde, el servidor mato a
Valentino y dejo su corpse, pero el cliente **no** emitio la senal de muerte y
por lo tanto no envio el logout `0x14`:

```text
  [srv] You lose 125 hitpoints due to an attack by a demon.
  corpse del jugador en (32081, 32145, 6): dead human
  [srv] You are dead.
El servidor corto la conexion despues del logout 0x14.
  FAIL el logout tras morir termina la sesion
```

La regla vigente de `protocolo-red` 1.1.0 es que la retirada `0x6C` de `mi_id`
solo significa muerte si las stats autoritativas mas recientes tienen vida
cero. `Player::death` restaura vida y mana **antes** de que
`Game::removeCreature` mande el `0x6C`, asi que cuando el golpe mortal y la
restauracion caen en el mismo tick el cliente nunca llega a ver un `0xA0` con
vida cero: ve el valor ya restaurado y descarta la muerte.

Esto no es un fallo de la prueba ni de la precondicion: es la regla de deteccion
la que depende de una carrera. Queda como solicitud al carril `protocolo-red`,
dueño de `cliente3d/red/`. La mitad de muerte del 2026-08-29 por la mañana si
la emitio, con el daño repartido en dos ticks; por eso el fallo no aparecio
hasta que la prueba se pudo repetir.

### 2. El corpse del monstruo no siempre se puede nombrar

En una corrida completa el corpse del rat llego a la casilla como un item sin
nombre resoluble (`pila: ?`), asi que la prueba no lo reconocio como `dead rat`
y fallo con su mensaje explicito a los 90 segundos. Con `--solo-loot` el mismo
recorrido termina en verde, de modo que el hueco esta en el nombre de alguna
etapa de descomposicion y no en el recorrido de corpse y loot.

## Precondicion que ya no es manual

Hasta el 2026-08-29 por la mañana, el duelo ocurria donde el personaje ya
estaba parado. Despues de morir el servidor lo devuelve al templo, y **dentro
de una zona de proteccion ningun monstruo puede atacarlo**:
`Monster::selectTarget` rechaza cualquier objetivo en `ZONE_PROTECTION` y
`Game.createMonster` tampoco deja invocar ahi. Repetir la corrida completa
exigia entonces sacar al personaje a mano.

Se descarto caminar con el cliente: a ciegas avanza apenas unas casillas y un
auto-walk inventado seria justo la clase de intencion que esta prueba no debe
simular. La orden `/c` del propio servidor resuelve lo mismo sin que el cliente
decida nada, y por eso reemplazo a esa precondicion manual.

El aviso de campo inservible sigue existiendo, ahora apuntando al campo y no al
templo:

```text
FAIL Nadie ataca a Valentino en (32081, 32145, 6), que es el campo al que lo
llevo el servidor. Revisa si esa casilla dejo de estar fuera de zona de
proteccion o si el demon no llego a invocarse.
```

La mitad de corpse y loot nunca tuvo esta precondicion y se repite sola con
`--solo-loot`.

## Efectos de una corrida completa

- El personaje normal pierde nivel y experiencia segun `Player::death`. En la
  primera corrida del 2026-08-29 bajo de nivel 3 a nivel 2, y las corridas de
  la tarde le siguieron costando niveles.
- La corrida completa mata al personaje de verdad cada vez que se ejecuta. Para
  probar solo la precondicion esta `--solo-campo`, que no le cuesta nada.
- Sus objetos quedan en el corpse `dead human` de la casilla del duelo, y ahi
  siguen hasta que alguien los recoge o el servidor los descompone.
- El demon invocado lo retira la propia prueba con `/killall`.

Para restaurar el personaje sin tocar el juego a mano estan la semilla
`servidor/docker/data/02-data.sql` y los archivos `servidor/gamedata/players/`
versionados en el repositorio.

## Correccion compensatoria: corrida viva posterior

La evidencia posterior invalida dos inferencias de la seccion historica
"Lo que destapo el duelo repetible"; se conserva arriba para no borrar la
historia del diagnostico.

Primero, `protocolo-red` 1.2.0 cerro la carrera de muerte. La retirada `0x6C`
se reconoce por `mi_id` **o** por la casilla autoritativa `mi_pos`, siempre con
vida cero. Dos corridas independientes confirmaron muerte, logout `0x14`,
cierre de sesion y reingreso vivo:

```text
[srv] You lose 140 hitpoints due to an attack by a demon.
MUERTE confirmada por el servidor en (32081, 32145, 6).
  OK  la muerte llega con vida autoritativa cero
  OK  la muerte deja al jugador fuera del mundo
El servidor corto la conexion despues del logout 0x14.
Reingreso confirmado en (32369, 32241, 7) con vida 140.
```

Segundo, `pila: ?` no era una etapa de corpse sin nombre. La auditoria de
assets cruzo 114 corpse roots y 307 etapas `decayto`; para el rat la cadena es
server `2813 -> 2814 -> 2815 -> 0`, client `3994 -> 3995 -> 3996`, siempre
`dead rat`.

La instrumentacion viva encontro el fallo antes del corpse: al terminar el
`0x64`, el jugador no aparece en `mi_pos` y los bytes siguientes se leen como
client ids imposibles. Dos corridas y el diagnostico aislado reprodujeron:

```text
MAPA DESALINEADO GOD VALENTINO:
  mi_pos=(32082,32146,6)
  items_sin_catalogo=19
  cids_sin_catalogo=[0,10,38560,38400,41316]
  primer_item={donde=(32097,32155,0), cid=0}
```

Los ids cambian segun los mensajes posteriores al mapa, por lo que son
payload/opcodes reinterpretados y no items reales. Aun con esa deuda, ambas
corridas mataron un rat, recibieron `dead rat`, abrieron el corpse y leyeron
loot real (`cheese x1` y `gold coin x3`). La prueba ahora falla como mapa
desalineado y conserva los ids diagnosticos; ya no acusa al servidor de omitir
un corpse cuando la pila local no es certificable.
