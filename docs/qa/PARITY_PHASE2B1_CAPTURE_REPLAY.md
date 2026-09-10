# Phase 2B.1 — Captura controlada de oracle TVP y replay generico

Estado: Phase 2 (`LEGACY_PARITY`), implementacion de captura/replay contra el
boundary maquina-legible publicado por `worklog/qa/CONTRATO.md` 2.1.1
(`OracleObservationV1`, `ParityExpectationV1`, comparador generico de nueve
operadores, seccion 16A-16F). Este documento NO redefine ese contrato: solo
documenta la implementacion que lo consume.

## Arquitectura de replay

```
ParityFixtureV2 (evidencia legacy, Phase 2A, sin modificar)
        +
QACaseV2 (class=LEGACY_PARITY) / ParityExpectationV1 embebido en `expected`
        +
OracleObservationV1 (RECORDED_EVIDENCE o LIVE_ORACLE)
        |
        v
comparador generico (RFC 6901 + registro cerrado de 9 operadores)
        |
        v
QAReportV2 (suite_id=PARITY_TVP_772, profile=LEGACY_TVP_772)
```

El comparador (`qa/parity/tools/replay.py`) no contiene ningun valor
especifico de fixture (ningun nombre de criatura/item, ninguna coordenada,
ningun dato de cuenta); todos esos valores viven exclusivamente en los
archivos JSON de caso/fixture/observacion versionados. Verificado por diseno
(seccion 16C, fixture de contrato `COMPARATOR-GENERIC-001`) y confirmado con
`grep` sobre el archivo fuente antes de este commit (sin coincidencias para
`dead human`, `dead rat`, `Valentino`, `GOD VALENTINO`, `32082`, `32145`).

## Los cuatro casos de replay

| `case_id` | Archivo | Modo | Aserciones |
|---|---|---|---|
| `PARITY-DEATH-CORPSE-001` | `qa/parity/cases/tvp772/death_corpse_loot/parity-death-corpse-001.case.json` | `SINGLE_OBSERVATION` | 5 (`EQ` x5) |
| `PARITY-DEATH-REENTRY-001` | `qa/parity/cases/tvp772/death_corpse_loot/parity-death-reentry-001.case.json` | `SINGLE_OBSERVATION` | 2 (`EQ`, `NE` path-a-path) |
| `PARITY-MONSTER-CORPSE-001` | `qa/parity/cases/tvp772/death_corpse_loot/parity-monster-corpse-001.case.json` | `SINGLE_OBSERVATION` | 4 (`EQ` x4) |
| `PARITY-LOOT-RANDOMNESS-001` | `qa/parity/cases/tvp772/death_corpse_loot/parity-loot-randomness-001.case.json` | `EVIDENCE_ONLY` | 0 (`assertions: []`) |

`case_id == fixture_id` para los cuatro, tal como congela la seccion 16D.1.
Los cuatro archivos `ParityFixtureV2` de Phase 2A
(`qa/parity/fixtures/tvp772/death_corpse_loot/*.json`) **no se modificaron**
en este turno; se verificaron byte-identicos antes y despues.

## Observaciones `RECORDED_EVIDENCE`

Materializadas para los tres casos `SINGLE_OBSERVATION`, en
`qa/parity/observations/tvp772/death_corpse_loot/recorded/`, usando
exclusivamente hechos ya publicados en `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`
(sin inventar timestamps, sin ids de runtime, sin credenciales):

- `parity-death-corpse-001.observation.json`
- `parity-death-reentry-001.observation.json` (posiciones de muerte/reingreso
  tomadas literalmente de la corrida documentada: muerte en `(32081,32145,6)`,
  reingreso en `(32369,32241,7)`)
- `parity-monster-corpse-001.observation.json`

## Comparador generico

`qa/parity/tools/replay.py` (Python 3, solo libreria estandar). Responsabilidades
implementadas exactamente segun el pedido de este turno:

1. carga `QACaseV2` y valida su forma minima para replay;
2. carga el `ParityFixtureV2` referenciado por `input_fixture.logical_path`;
3. valida `case_id == fixture_id` (seccion 16D.1);
4. valida `class == LEGACY_PARITY`;
5. valida la `ParityExpectationV1` embebida en `expected` (modo, `1..32`
   aserciones segun corresponda, forma de `right`);
6. carga la `OracleObservationV1` (`<case_id_en_minusculas>.observation.json`
   dentro del directorio de observaciones dado);
7. valida `observation.fixture_id == case_id`;
8. valida que `oracle`/`oracle_version` de la observacion coincidan con los
   del fixture referenciado;
9. resuelve JSON Pointer RFC 6901 contra `observation.payload`;
10. evalua el registro cerrado de nueve operadores;
11. produce `PASS`/`FAIL` deterministico por caso;
12. trata `EVIDENCE_ONLY` como `NOT_RUN` (nunca `PASS`, nunca `REQUIRED`
    para el codigo de salida);
13. emite `tvp3d.qa.report/2.0.0` (`suite_id=PARITY_TVP_772`,
    `profile=LEGACY_TVP_772`);
14. sale con codigo distinto de cero cuando corresponde (seccion 9: `1` si
    algun caso `SINGLE_OBSERVATION` selecionado da `FAIL`, `2` si ninguno
    falla pero alguno queda `BLOCKED`/`NOT_RUN`, `0` si todos los
    `SINGLE_OBSERVATION` dan `PASS`).

### Los nueve operadores implementados

`EQ, NE, EXISTS, NOT_EXISTS, GT, GTE, LT, LTE, ONE_OF`. Ningun operador
adicional; sin `eval`; sin expresiones Python en datos de fixture; sin
evaluador de regex.

Reglas exactas respetadas: `left_path` ausente falla la aserción especifica
para todo operador salvo `NOT_EXISTS` (nunca un crash de harness); un tipo
incompatible en `GT/GTE/LT/LTE` falla la aserción sin coercion; `bool` se
excluye explicitamente como operando numerico aunque en Python
`bool` es subclase de `int`; no hay coercion string->numero; `ONE_OF` exige
`right.literal` como array con igualdad profunda contra sus miembros; el
orden de JSON Pointer decodifica primero `~1` y despues `~0` (el orden
inverso decodificaria mal un token que codifica un `~1` literal, encodeado
como `~01`).

### Auto-prueba (nunca escribe un archivo malformado versionado)

```text
py -3 qa/parity/tools/replay.py --selftest
```

46 comprobaciones en memoria, todas `OK`, codigo de salida 0. Cubre los
nueve operadores (caso exitoso y fallido donde aplica), decodificacion
`~0`/`~1` incluyendo el caso de orden sensible, indices de array validos e
invalidos, `left_path` ausente para cada operador (sin crash), rechazo de
cadena numerica y de `bool` como operando numerico, rechazo estructural de
`right` con ambos operandos o ninguno, `right` prohibido/obligatorio segun
operador, `ONE_OF` con forma `path` rechazado, `EVIDENCE_ONLY` con
aserciones no vacias rechazado, `SINGLE_OBSERVATION` sin aserciones
rechazado, deteccion de `case_id`/`fixture_id` distintos, oracle distinto
del fixture referenciado, schema/version incorrectos de caso/fixture/
observacion, path absoluto en `source_evidence` y literal con forma de
secreto en el payload.

## Resultado del replay contra evidencia grabada

```text
py -3 qa/parity/tools/replay.py \
  --cases-dir qa/parity/cases/tvp772/death_corpse_loot \
  --observations-dir qa/parity/observations/tvp772/death_corpse_loot/recorded \
  --report qa/parity/reports/replay_recorded_death_corpse_loot_report.json
```

Resultado, ejecutado dos veces con reporte byte-identico entre corridas
(confirmado con `diff`):

```text
PASS PARITY-DEATH-CORPSE-001
PASS PARITY-DEATH-REENTRY-001
NOT_RUN PARITY-LOOT-RANDOMNESS-001
PASS PARITY-MONSTER-CORPSE-001
exit=0 pass=3 fail=0 blocked=0 not_run=1
```

Reporte deterministico: `qa/parity/reports/replay_recorded_death_corpse_loot_report.json`.

### Prueba de mutacion deliberada (negativa)

Se corrompio temporalmente `parity-monster-corpse-001.observation.json`
(`corpse.name` de `"dead rat"` a `"dead spider"`), se confirmo que el
replay reporta `FAIL PARITY-MONSTER-CORPSE-001` con codigo de salida `1`, y
se restauro el archivo a su contenido original antes de cualquier commit
(verificado byte-a-byte con `sha256sum`,
`5ac6889d098b050a3824c9b6c9d451d76a5924f392fb6d5a07e1f09cf51f864e` antes y
despues de la corrupcion/restauracion).

## Captura en vivo — solo corpse de monstruo

**No se ejecuto TVP en vivo en este turno. Resultado: `BLOCKED`.**

Se investigaron, sin inventar nada, los dos prerequisitos exactos que exige
la politica de credenciales de este turno:

1. **Motor de Docker inalcanzable.** `docker ps` fallo de inmediato:
   `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine:
   ... The system cannot find the file specified`. Docker Desktop no estaba
   en ejecucion; no es el problema de puente WSL con el motor vivo ya
   conocido de otros turnos, sino el motor mismo apagado.
2. **Credenciales de runtime ausentes.** Las variables de entorno
   `TVP772_ACCOUNT`, `TVP772_PASSWORD` y `TVP772_GOD_CHARACTER` no estan
   definidas en este entorno (comprobado sin imprimir ningun valor, solo su
   presencia/ausencia).

Cualquiera de los dos prerequisitos ausentes ya bloquea la captura; ambos lo
estan. Siguiendo la politica de este turno de forma literal:

- **no** se arranco Docker Desktop para intentar resolver el primer punto,
  porque el segundo bloqueo (credenciales) es independiente y no se puede
  resolver dentro de este turno sin violar la regla de credenciales (no
  inventar, no copiar desde otro archivo, no imprimir);
- **no** se fabrico ninguna observacion `LIVE_ORACLE`;
- **no** se copio ni re-etiqueto la observacion `RECORDED_EVIDENCE` de
  `PARITY-MONSTER-CORPSE-001` como si fuera `LIVE_ORACLE`;
- **no** se reporta `PASS` para la captura en vivo;
- **no** se creo `qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`
  (el directorio `live/` existe vacio, listo para un turno futuro con
  credenciales disponibles);
- **no** se creo `qa/parity/reports/replay_live_monster_corpse_report.json`,
  porque no hay ninguna observacion real que replayar; fabricar ese reporte
  habria sido indistinguible de inventar un resultado.

### Procedimiento que se habria seguido (documentado, no ejecutado)

Si el entorno hubiera estado disponible, el plan minimo era: reutilizar
exactamente el modo `--solo-loot` de
`cliente3d/pruebas/prueba_muerte_loot_vivo.gd` (que ya invoca, mata y abre el
corpse de un `rat` sin tocar al personaje normal ni requerir duelo), leer las
credenciales exclusivamente desde `TVP772_ACCOUNT`/`TVP772_PASSWORD`/
`TVP772_GOD_CHARACTER` en tiempo de ejecucion (nunca copiadas a un literal
nuevo), y agregar un modo de salida narrow que emita solo el payload
canonico:

```json
{
  "monster_kind": "rat",
  "corpse": {"present": true, "name": "dead rat", "openable_container": true}
}
```

excluyendo explicitamente id de runtime de la criatura, coordenadas exactas
del corpse, contenido del loot, timestamp de reloj de pared, hostname, PID,
usuario de maquina, id de cuenta, contraseña, clave privada y volcado crudo
de paquetes. Ese modo se agregaria a `prueba_muerte_loot_vivo.gd` como una
rama opcional (Opcion A del turno) o como un script QA-owned separado que
reutiliza `cliente3d/red/conexion772.gd`/`estado_mundo.gd` sin refactorizarlos
(Opcion B), sin tocar `cliente3d/red/`, `estado_mundo.gd` ni
`conexion772.gd` en si mismos. **No implementado en este turno** porque no
hay forma de probarlo sin credenciales ni Docker, y "codigo sin poder
ejecutarlo contra el oracle real" no habria sido replay verificado, solo
codigo sin probar.

### Mutacion de estado documentada (para un turno futuro que si capture)

Si se ejecutara, la operacion de captura en vivo **mutaria el mundo legacy
de desarrollo**: invoca una rata de prueba, la mata y crea/abre su corpse.
Esa mutacion pertenece a la operacion de *adquisicion de oracle*, no al
`QACaseV2` de replay: el `QACaseV2` de `PARITY-MONSTER-CORPSE-001` sigue
siendo `class=LEGACY_PARITY`, `mutates_external_state=false`, porque el
replay en si mismo solo consume una observacion ya capturada; no se
reinterpreta ese campo ni se inventa un segundo significado de "mutar".

## Desalineamiento de mapa 0x64

No investigado ni corregido en este turno, tal como exige el alcance. Sigue
como `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`. No se promovio a
regla de oracle autoritativa ni se codificaron ids de cliente imposibles
como hechos esperados.

## Sin credenciales en ningun artefacto nuevo

Ningun archivo creado en este turno (`qa/parity/cases/**`,
`qa/parity/observations/**`, `qa/parity/tools/replay.py`,
`qa/parity/reports/replay_recorded_death_corpse_loot_report.json`, este
documento, `worklog/qa/STATE.md`, `worklog/EVENTS.jsonl`) contiene un valor
de cuenta, contraseña, clave privada o cualquier literal con forma de
secreto. El validador de observaciones (`validate_observation` en
`replay.py`) escanea el `payload` contra los mismos patrones de forma de
secreto que ya usaba `qa/parity/tools/validate_pilot.py` y rechaza
(`QA_SECRET_EXPOSURE`) cualquier coincidencia.

## Conteos (no se combinan)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1` seccion 5) | 198 | 0 (sin cambio) |
| Corpus de piloto `LEGACY_PARITY` (Phase 2A, sin cambio este turno) | 4 | 4 |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (este turno) | 4 | 4 (3 `SINGLE_OBSERVATION`, 1 `EVIDENCE_ONLY`) |
| Observaciones `RECORDED_EVIDENCE` materializadas | 3 | 3 |
| Observaciones `LIVE_ORACLE` frescas | 1 (planeada: `PARITY-MONSTER-CORPSE-001`) | 0 (`BLOCKED`) |

Replayar los cuatro casos de paridad legacy **no** materializa ninguna de las
198 obligaciones de contrato Architecture V2: esas dos cuentas permanecen
estrictamente separadas.

## Proximo paso recomendado (no ejecutado en este turno)

Un turno futuro con Docker y credenciales `TVP772_ACCOUNT`/
`TVP772_PASSWORD`/`TVP772_GOD_CHARACTER` disponibles puede ejecutar el
procedimiento documentado arriba para producir la primera observacion
`LIVE_ORACLE` real de `PARITY-MONSTER-CORPSE-001` y replayarla con este mismo
comparador genérico, y por separado investigar el caveat de desalineamiento
de mapa `0x64` como su propia linea de evidencia.
