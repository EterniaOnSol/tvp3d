# Phase 2C.1 — Calificacion de terreno TVP aislado para reacquisicion

Estado: **QUALIFIED_FOR_REACQUISITION_LIVE_TEST**.

Este turno **no certifica** `PARITY-MONSTER-REACQUISITION-001`. Solo califica
el terreno donde esa certificacion podra intentarse en Phase 2C.2. No se
modifico ningun fixture, case, observacion ni el adaptador de captura de
reacquisicion.

## Por que el campo historico no sirve

El campo usado por `docs/qa/PRUEBA_VIVA_REACQUISICION.md` y por los intentos
de Phase 2C —`(32082,32145,6)` y `(32083,32184,6)`— esta dentro de actividad
natural de cave rats de Thais. En las 13 corridas en vivo de Phase 2C eso
produjo: 8 abortos por ambiguedad de identidad del atacante (entraban cave
rats silvestres al conjunto visible), 3 abortos por muerte del personaje de
prueba de nivel 1 antes de completar la ventana de medicion, y 2 abortos por
cave rat preexistente antes de invocar.

La solucion **no** puede ser matar la fauna ni usar `/killall` amplio (muta
estado legacy no relacionado y ya se establecio en Phase 2B.2.1 que `/killall`
es una operacion de area insegura). La solucion es buscar un par de casillas
realmente tranquilas dentro del mundo que ya existe.

## Fuentes estaticas inspeccionadas (todas, sin huecos)

| Fuente | Contenido usado | Entradas |
|---|---|---|
| `servidor/data/world/map.otbm` | existencia de casilla, flag de zona de proteccion, casillas de casa | 94.199 casillas dentro de la ventana de busqueda |
| `servidor/data/world/map-spawn.xml` | `tvpspawn` (monstruos y NPCs) | 9.950 entradas |
| `servidor/data/spawns.dat` | `Spawn (...)` y `Npc (...)` | 9.613 spawns + 337 NPCs |
| `servidor/data/world/map-house.xml` | ids de casa (verificacion cruzada) | parseado completo |
| `servidor/data/raids/*.xml` | `areaspawn` + `monster` | 38 archivos, 349 areaspawns |

**`source_problems` del reporte: 0.** Ninguna entrada quedo sin entender y
ningun formato relevante se salteo en silencio. Se verifico explicitamente
que los archivos de raid solo usan los elementos `raid`, `raids`, `announce`,
`areaspawn`, `monster` y `loot`: no hay ningun `singlespawn` ni otro elemento
de spawn que el parser pudiera estar ignorando.

Nota importante: `map-spawn.xml` y `spawns.dat` **no** coinciden en radios
(por ejemplo la misma Amazon aparece con `radius=30` en el XML y `radius=50`
en el `.dat`). Por eso se parsean ambos y se usa la union, de modo que
siempre gana el radio mas conservador.

## Metodo de calificacion sobre OTBM

`qa/parity/tools/qualify_reacquisition_terrain.py` (nuevo, QA-owned, solo
libreria estandar) reutiliza **en modo lectura** `herramientas/leer_otbm.py`:
su clase `Stream`, su manejo de escapes y sus constantes de nodo/atributo.
El parser no se reescribio ni se modifico.

Si se agrego un filtro de bounds a nivel de area: `leer_otbm.recorrer`
decodifica los atributos de todos los items de todas las casillas de un mundo
de 65000x65000, lo que no termina en un tiempo practico para esta busqueda
(se dejo correr mas de 20 minutos sin resultado). Como aca solo hacen falta
coordenadas, flags y house id, las areas fuera de la ventana se saltean
enteras con `Stream.skip_node_body()` y dentro de la ventana los items
inline se consumen como su id de servidor desnudo (exactamente lo que hace
`_read_item(..., read_attributes=False)`).

**Limitacion honesta:** con los datos disponibles se puede probar que una
casilla existe y tiene contenido, pero **no** se puede determinar
estaticamente que sea caminable/parable sin metadata de items (`items.otb`).
Por eso la sonda en vivo con `/gotopos` es obligatoria: confirmar que el
servidor efectivamente coloca al personaje en esa casilla es la prueba real
de usabilidad.

## Reglas derivadas del codigo fuente (nunca adivinadas)

### Visibilidad

- `servidor/src/map.h:181-182`: `maxClientViewportX = 8`,
  `maxClientViewportY = 6`.
- `servidor/src/protocolgame.cpp:766-767`: en el mismo piso una posicion es
  visible cuando `dx ∈ [-8, +9]` y `dy ∈ [-6, +7]` respecto del observador.
  **La ventana es asimetrica**, no un radio unico.
- `servidor/src/map.h:179-180` + `servidor/src/map.cpp:434-437`:
  `maxViewportX = maxViewportY = 11` es el rango de espectadores por defecto
  del servidor, mas ancho que el del cliente. Se usa **11** como radio de
  visibilidad para toda la matematica de seguridad, por ser el mas
  conservador de los dos.

Deliberadamente **no** se reutilizo el "39 SQM" del documento historico: ese
numero es un detalle de implementacion de aquella corrida, no una regla
derivada del servidor.

### Limite de movimiento de un monstruo

- `Spawns::isInZone` (`servidor/src/spawn.cpp:222-231`) es una **caja de
  Chebyshev**: `dx <= radius && dy <= radius` alrededor del centro del spawn.
- `Monster::isInSpawnRange` (`servidor/src/monster.cpp:1727-1735`) aplica esa
  caja siempre que `allowMonsterOverspawn` sea verdadero, que es justo lo que
  fija `servidor/config.lua`. Es decir: el radio de spawn **si** es un limite
  estatico real de donde puede estar un monstruo spawneado.

### Buffer de seguridad

Un monstruo puede estar en cualquier punto de la caja de Chebyshev de radio
`R` alrededor de su spawn. Se vuelve visible para el jugador cuando queda a
distancia de Chebyshev `<= 11`. Por lo tanto hace falta:

```text
cheb(candidato, centro_del_spawn) > R + 11 + MARGEN
```

`MARGEN = 10`, elegido de forma conservadora para cubrir el comportamiento de
persecucion que el limite estatico no modela del todo y la duracion de una
corrida de medicion. Eso da un **clearance requerido de 21** por encima del
radio del spawn. El radio de spawn mas grande encontrado en los datos es
**50**, asi que en el peor caso hace falta estar a mas de 71 casillas del
centro de ese spawn.

### Separacion entre los dos puntos

Se exige que **ambos** ejes superen 30 casillas. Es muy superior al limite mas
ancho de visibilidad (11), asi que garantiza que el objetivo salga del
conjunto visible cuando el jugador se reubica, sin depender de cual eje se
mueva. La regla del fixture sigue siendo conductual ("alejarse lo suficiente
para que el objetivo deje de ser visible"); estos 30 son solo el criterio de
busqueda.

## Busqueda y ranking

Ventana: centro `(32082,32145)`, radio 150, pisos 6 y 7 (cerca del area de
pruebas conocida, para que depurar siga siendo practico).

- 94.199 casillas dentro de la ventana
- 7.076 casillas calificadas estaticamente
- 58 pares evaluados
- 25 casillas en el pool de emparejamiento

**Bucketing espacial:** las casillas "mas aisladas" son vecinas entre si
(casillas adyacentes comparten casi el mismo clearance), asi que un pool
tomado solo por ranking nunca contiene dos casillas separadas 30+. Se toma un
representante por cubeta de 30x30, lo que reparte el pool por la ventana
manteniendo el resultado totalmente determinista.

Orden determinista: por aislamiento descendente, luego por separacion minima
descendente, luego por coordenadas.

## Top 3 pares candidatos

Los tres comparten el punto B y difieren solo en el punto A.

| # | A | B | dx | dy | aislamiento |
|---|---|---|---:|---:|---:|
| 1 | `(31980,31995,7)` | `(31932,32040,7)` | 48 | 45 | 38 |
| 2 | `(32010,31995,7)` | `(31932,32040,7)` | 78 | 45 | 38 |
| 3 | `(32040,31995,7)` | `(31932,32040,7)` | 108 | 45 | 38 |

Detalle de los puntos (todos: existe la casilla, **no** es zona de
proteccion, **no** es casilla de casa, `house_id = 0`):

| Punto | Spawn estatico mas cercano | Raid mas cercano | NPC mas cercano |
|---|---|---|---|
| `(31980,31995,7)` | `Spider` r=50, cheb 96, **clearance 46** | `The Halloween Hare` r=1, cheb 220, clearance 219 | `al dee` cheb 185 |
| `(32010,31995,7)` | `Spider` r=50, cheb 96, **clearance 46** | `The Halloween Hare` r=1, cheb 220, clearance 219 | `costello` cheb 170 |
| `(32040,31995,7)` | `Spider` r=50, cheb 96, **clearance 46** | `The Halloween Hare` r=1, cheb 220, clearance 219 | `costello` cheb 140 |
| `(31932,32040,7)` | `Bear` r=50, cheb 88, **clearance 38** | `The Halloween Hare` r=1, cheb 175, clearance 174 | `al dee` cheb 140 |

Todos los clearances (38 y 46) superan holgadamente el requerido (21). Los
NPCs quedan a 140+ casillas; se reportan aparte y no invalidan ninguna
casilla porque no interfieren con la prueba.

Margen de visibilidad del par elegido: `x = 39`, `y = 38` por encima de la
ventana del cliente, y `34` por encima del rango de espectadores del
servidor.

## Sonda en vivo, solo god

`cliente3d/pruebas/prueba_parity_terrain_probe.gd` + `.tscn` (nuevos,
QA-owned). Estrictamente no combativa y no mutante:

- **una sola sesion god**; no se pide ni se usa `TVP772_PLAYER_CHARACTER`;
- solo emite `/gotopos` y observa de forma pasiva;
- **no** invoca (`/m`), **no** ataca, **no** mata, **no** usa `/killall`,
  **no** mueve al personaje normal con `/c`;
- si aparece una criatura natural, el candidato **falla** y se pasa al
  siguiente: nunca se "limpia" un candidato.

Credenciales solo por entorno (`TVP772_ACCOUNT`, `TVP772_PASSWORD`,
`TVP772_GOD_CHARACTER`), sin literales y sin imprimir valores. Los puntos y
la ventana de observacion se pasan por `TVP772_PROBE_POINTS` y
`TVP772_PROBE_DWELL`.

### Procedimiento y resultado

Ventana de observacion: **60 segundos por punto** (el minimo pedido). Para
cada punto: teleport con `/gotopos`, confirmar que el servidor reporta la
posicion esperada, y observar pasivamente el conjunto de criaturas visibles
durante la ventana completa.

```text
--- punto 1/2: (31980,31995,7) ---
God llego a (31980, 31995, 7). Observando 60s sin tocar nada.
  sin criaturas naturales durante la ventana completa.
--- punto 2/2: (31932,32040,7) ---
God llego a (31932, 32040, 7). Observando 60s sin tocar nada.
  sin criaturas naturales durante la ventana completa.
Sonda pasiva de terreno: OK
```

| Punto | God llego | Criaturas naturales observadas |
|---|---|---:|
| `(31980,31995,7)` | SI | **0** |
| `(31932,32040,7)` | SI | **0** |

El par #1 paso la sonda al primer intento, asi que no hizo falta probar los
pares #2 y #3.

## Par seleccionado

```text
A = (31980, 31995, 7)
B = (31932, 32040, 7)
```

Estado: **QUALIFIED_FOR_REACQUISITION_LIVE_TEST**. Cumple todo lo exigido:
ambas casillas califican estaticamente, las fuentes de spawn y de raid se
parsearon sin huecos relevantes, ninguna es casa ni zona de proteccion, la
separacion de visibilidad es suficiente con margen, el god llego a ambas
posiciones y la permanencia pasiva no vio ninguna criatura natural en
ninguna de las dos.

## Lo que este turno NO hizo

- **0 sesiones del personaje normal.** El personaje de prueba nunca se
  conecto; ese es precisamente el motivo de existir de este turno.
- **0 muertes de jugador.**
- **0 monstruos invocados.**
- **0 monstruos matados** (ni intencionalmente ni como efecto colateral).
- **0 usos de `/killall`.**
- No se modifico `PARITY-MONSTER-REACQUISITION-001`, su `QACaseV2`, su
  observacion `RECORDED_EVIDENCE`, la observacion `LIVE_ORACLE` existente,
  `replay.py`, `wrap_live_observation.py` ni el adaptador de captura de
  reacquisicion.
- No se investigo el desalineamiento de mapa `0x64`.
- Las coordenadas seleccionadas **no** entran en ningun fixture, case,
  expectation ni observacion: son detalle de implementacion de captura, y por
  eso viven en este documento operativo.

## Limitaciones de esta calificacion

1. La permanencia pasiva de 60 s **no** prueba ausencia eterna de monstruos.
   Por eso el analisis estatico de spawns y raids es obligatorio ademas de la
   sonda: uno cubre el comportamiento programado, la otra el estado real del
   momento.
2. La caminabilidad no se puede determinar estaticamente sin metadata de
   items; queda probada de hecho porque el servidor acepto colocar al god en
   ambas casillas.
3. Los raids se programan con margenes aleatorios; un raid futuro podria
   acercarse a estas casillas. El clearance de 174+ respecto del areaspawn
   mas cercano hace eso muy improbable, pero no imposible.
4. `allowMonsterOverspawn = true` hace que el radio de spawn sea un limite
   real, pero un monstruo persiguiendo a un objetivo podria aun asi
   desplazarse; el margen de 10 sobre el clearance existe justamente para
   eso.

## Proximo paso exacto

**Phase 2C.2** — adaptar el adaptador de captura de reacquisicion existente
al par calificado `A=(31980,31995,7)` / `B=(31932,32040,7)` y ejecutar una
unica certificacion en vivo congelada contra
`PARITY-MONSTER-REACQUISITION-001`, siguiendo el patron ya probado de
congelar-hashear-capturar-rehashear-confirmar.
