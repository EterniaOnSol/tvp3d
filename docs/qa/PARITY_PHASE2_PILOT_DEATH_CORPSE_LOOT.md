# Phase 2A — Piloto LEGACY_PARITY: muerte, corpse, reentrada y loot

Estado: Phase 2 (`LEGACY_PARITY`), evidencia de oracle legacy. Este documento
NO define comportamiento nativo V2 y NO afirma paridad del servidor Godot
nativo contra TVP. Es evidencia legacy materializada como
`ParityFixtureV2` (`tvp3d.qa.parity_fixture/2.0.0`, publicado por
`worklog/qa/CONTRATO.md` 2.0.1), consumible por Phase 3 cuando exista
implementacion nativa que comparar.

## Que se hizo en este turno

Se materializaron cuatro fixtures `LEGACY_PARITY` a partir de evidencia ya
grabada, sin ejecutar TVP, sin iniciar Docker, sin credenciales y sin mutar
ningun estado legacy. Se valido localmente esa evidencia contra el schema
publicado con un harness Python determinista propio de QA.

**No se ejecuto TVP en vivo en este turno.** El reporte correcto es: "4
fixtures de paridad materializadas desde evidencia grabada de TVP 7.72 y
validadas localmente", no "TVP paso paridad hoy".

## Evidencia fuente

`docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md` — prueba viva original del 2026-08-29 y
su correccion compensatoria posterior. No se reescribio ese documento.

## Los cuatro fixtures

| `fixture_id` | Archivo | Clasificacion |
|---|---|---|
| `PARITY-DEATH-CORPSE-001` | `qa/parity/fixtures/tvp772/death_corpse_loot/parity-death-corpse-001.json` | `MATCH_EXPECTED` |
| `PARITY-DEATH-REENTRY-001` | `qa/parity/fixtures/tvp772/death_corpse_loot/parity-death-reentry-001.json` | `MATCH_EXPECTED` |
| `PARITY-MONSTER-CORPSE-001` | `qa/parity/fixtures/tvp772/death_corpse_loot/parity-monster-corpse-001.json` | `MATCH_EXPECTED` |
| `PARITY-LOOT-RANDOMNESS-001` | `qa/parity/fixtures/tvp772/death_corpse_loot/parity-loot-randomness-001.json` | `MATCH_EXPECTED` |

Manifest deterministico: `qa/parity/fixtures/tvp772/death_corpse_loot/manifest.json`
(metadata propia de QA para este piloto; no es un contrato nuevo).

### `PARITY-DEATH-CORPSE-001`

El servidor deja un corpse `dead human` en la casilla de muerte, con vida
autoritativa cero, antes de retirar al personaje. Normaliza posicion exacta,
dano y perdida de nivel como no deterministicos entre corridas.
Deliberadamente NO se ancla al heuristico fragil "el `0x6C` de `mi_id`
siempre alcanza por si solo": el propio documento fuente (seccion "Lo que
destapo el duelo repetible", punto 1) muestra que esa regla de deteccion
tenia una condicion de carrera, corregida despues por `protocolo-red 1.2.0`
("Correccion compensatoria"). El fixture solo captura el resultado
autoritativo (corpse + vida cero), no el parser superado.

### `PARITY-DEATH-REENTRY-001`

Tras la muerte y el logout autoritativo, el reingreso deja al personaje vivo
en una posicion distinta de la de muerte. Se normaliza el valor exacto de HP
al reingresar (145 en una corrida, 140 en otras dos) como no deterministico;
se exige solo "vivo" y "posicion distinta de la de muerte".

### `PARITY-MONSTER-CORPSE-001`

Un rat invocado y muerto deja un corpse `dead rat` que se abre como
contenedor real. Este fixture usa **exclusivamente** las corridas
`--solo-loot`, que no dependen de la alineacion completa del mensaje de mapa
`0x64`. Ver "Caveat de desalineamiento de mapa" mas abajo para el motivo
exacto de esa exclusion deliberada.

### `PARITY-LOOT-RANDOMNESS-001`

El contenido exacto del corpse (`gold coin x3`, `gold coin x4`, `cheese x1`,
o vacio) varia entre corridas equivalentes; la regla estable es que el
servidor decide el contenido y el cliente solo lo muestra. La clasificacion
es `MATCH_EXPECTED` porque el fixture representa la regla de
no-determinismo en si misma, no un valor de loot especifico.

## Decisiones de normalizacion

Ver el campo `normalization_rules` de cada fixture. En resumen:

- **Muerte/corpse:** coordenadas como `PosicionTibia` entera valida, no como
  literal fijo; se ignoran dano, perdida de nivel y timestamps.
- **Reentrada:** se ignora el HP exacto; se compara `vivo=true` y
  `posicion != posicion_de_muerte`.
- **Corpse de monstruo:** se identifica por nombre semantico ('dead rat'),
  nunca por el runtime id de la criatura entre corridas.
- **Loot:** el contenido exacto (item/cantidad/ausencia) queda excluido de
  la comparacion deterministica; solo se exige que sea un contenedor real
  cuyo contenido decide el servidor.

## Que se decidio NO codificar

- **No** se creo un quinto fixture para el heuristico de deteccion de
  muerte del lado cliente ("`0x6C` de `mi_id` siempre alcanza"): es un
  detalle de parser ya superado, no comportamiento autoritativo del
  servidor TVP.
- **No** se eligio ningun contenido de loot especifico como "el esperado".
- **No** se afirma que estos cuatro fixtures certifiquen el servidor Godot
  nativo V2: `Phase 3` (no iniciada) es quien eventualmente los consumira
  contra una implementacion real.
- **No** se definio ningun contrato de dominio (Combat, Item/Inventory,
  Monster/Spawn, Map/World): estos fixtures son evidencia legacy en esas
  areas, no una especificacion V2. Por ejemplo, "TVP genera loot aleatorio
  en el corpse de un rat" es evidencia; no define por si sola el
  comportamiento de un futuro Monster Domain/Item Inventory V2.

## Caveat de desalineamiento de mapa (excluido deliberadamente)

El documento fuente registra, en su seccion "Correccion compensatoria", que
una corrida **completa** (no `--solo-loot`) sufrio un desalineamiento del
mensaje de mapa `0x64`: el jugador no aparecio en `mi_pos` y los bytes
siguientes se leyeron como client ids imposibles
(`MAPA DESALINEADO ... cids_sin_catalogo=[0,10,38560,38400,41316]`). El
propio documento aclara que, aun con esa deuda, "ambas corridas mataron un
rat, recibieron `dead rat`, abrieron el corpse y leyeron loot real": el
problema esta en la certificacion de la pila de una casilla del mapa, no en
que el servidor haya fallado en crear el corpse.

Esta revision **no** promueve ese desalineamiento a comportamiento
autoritativo de TVP ni a un fixture `KNOWN_LEGACY_BUG`: la evidencia no
prueba que el servidor produjera un estado invalido, solo que el
lector/parser de mapa del lado cliente tuvo un problema de alineacion en esa
corrida especifica. `PARITY-MONSTER-CORPSE-001` evita esa ambiguedad usando
solo las corridas `--solo-loot`, que no dependen de esa lectura de mapa.
Queda anotado aqui como **investigacion de paridad futura** para
`protocolo-red`/`assets`, no como hallazgo de este piloto.

## Harness de validacion local

`qa/parity/tools/validate_pilot.py` (Python 3, solo libreria estandar, sin
dependencias externas). Responsabilidades:

1. leer `manifest.json` y confirmar que `fixture_ids` esta en orden
   alfabetico estable;
2. localizar cada archivo de fixture de forma deterministica por
   `fixture_id`;
3. parsear JSON UTF-8 y rechazar `fixture_id` duplicado;
4. exigir `schema=tvp3d.qa.parity_fixture`, `version=2.0.0`,
   `oracle=TVP_772`, `oracle_version=7.72`;
5. validar la clasificacion contra el enum cerrado publicado;
6. exigir que `source_evidence.logical_path` sea relativo al repositorio y
   resuelva a un archivo existente; rechazar paths absolutos;
7. escanear todo el contenido en busca de literales con forma de secreto;
8. validar tipos basicos de todos los campos requeridos;
9. emitir un reporte deterministico (sin timestamps/hostname/PID) en
   `qa/parity/reports/pilot_death_corpse_loot_report.json`, con los
   fixtures en orden alfabetico y su `sha256` de contenido.

Ejecucion:

```text
py -3 qa/parity/tools/validate_pilot.py
```

Resultado de esta sesion: `OK 4 fixtures validated
(tvp3d.qa.parity_fixture/2.0.0)`, codigo de salida 0, ejecutado dos veces
con reporte byte-identico entre corridas.

Auto-prueba negativa (nunca escribe un archivo malformado versionado):

```text
py -3 qa/parity/tools/validate_pilot.py --selftest
```

Ejercita 11 documentos malformados en memoria (schema/version/oracle
incorrectos, clasificacion desconocida, campo faltante, paths absolutos
Windows/POSIX, evidencia inexistente, secreto literal, tipo incorrecto) y
confirma que el validador los rechaza a todos. Ademas, durante esta sesion
se corrompio temporalmente `parity-death-corpse-001.json` (clasificacion
invalida), se confirmo que el harness normal termina con codigo de salida
distinto de cero, y el archivo se restauro a su contenido original antes de
cualquier commit.

## Conteos (no se combinan)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.0.1` seccion 5) | 198 | 0 (sin cambio) |
| Corpus de piloto `LEGACY_PARITY` (este turno) | 4 | 4 (validadas localmente contra evidencia grabada) |
| Ejecuciones frescas de oracle TVP en este turno | — | 0 |

## Proximo paso de captura de oracle recomendado (no ejecutado en este turno)

Un turno futuro de `qa` puede construir una herramienta de captura/replay
controlada contra un TVP real (Docker) para producir observaciones frescas y
compararlas contra estos cuatro fixtures, y para investigar el caveat de
desalineamiento de mapa como su propia linea de evidencia. Ese turno no se
ejecuta aqui.
