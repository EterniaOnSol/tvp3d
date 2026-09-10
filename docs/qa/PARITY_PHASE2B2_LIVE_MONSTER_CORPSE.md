# Phase 2B.2 — Primera captura fresca de oracle TVP en vivo (monster corpse)

Estado: **exito**. Se completo el primer ciclo real de extremo a extremo:

```
TVP 7.72 real -> adquisicion controlada de corpse de monstruo ->
OracleObservationV1 LIVE_ORACLE normalizada -> replay.py existente ->
QAReportV2 PASS (4/4)
```

Exclusivamente para `PARITY-MONSTER-CORPSE-001`. Cero jugadores murieron;
no se ejecuto ningun flujo de muerte/reentrada.

## Verificacion de prerequisitos (antes de tocar nada)

### Motor de Docker

`docker ps` respondio de inmediato al abrir este turno: alcanzable. Unico
contenedor arriba en ese momento: `tvp3d_web`. El stack de TVP 7.72
(`servidor-server-1`, `servidor-mariadb-1`) no estaba levantado.

### Credenciales

Se comprobo unicamente presencia/ausencia de
`TVP772_ACCOUNT`/`TVP772_PASSWORD`/`TVP772_GOD_CHARACTER`: las tres estaban
ausentes al abrir el turno. Siguiendo la instruccion literal del turno, se
detuvo el trabajo de implementacion antes de tocar cualquier archivo y se
pidio al usuario que las definiera. El usuario opto por proveerlas
directamente en la conversacion para esta ejecucion puntual, en vez de
configurarlas como variables de entorno persistentes del sistema.

**Tratamiento de esas credenciales en este turno:** en ningun momento se
escribieron a un archivo, se imprimieron en la salida de un comando, ni se
incluyeron en un mensaje de commit, evento o documento. Se usaron
exclusivamente como variables de entorno `export` dentro de una unica
invocacion de shell que lanzo el proceso de Godot, y se hizo `unset`
inmediatamente despues. El script de captura las lee solo con
`OS.get_environment(...)`; el archivo fuente no contiene ningun valor
literal de cuenta/clave/personaje.

Nombres de variables usadas (nunca sus valores en ningun artefacto
versionado): `TVP772_ACCOUNT`, `TVP772_PASSWORD`, `TVP772_GOD_CHARACTER`.

### Iteracion de credenciales (documentada porque es parte real de lo ocurrido)

El primer intento con una cuenta nueva fue rechazado por el servidor
("Account number or password is not correct."): esa cuenta no existia en
esta base de datos especifica. El usuario opto por usar en su lugar la
cuenta de prueba ya documentada como valor por defecto en
`ARRANCAR SERVIDOR.bat` (no repetida aqui). El segundo intento con esa
cuenta fallo porque el nombre exacto del personaje god no coincidia
(diferencia de mayusculas). El script de captura ya imprime, ante ese fallo
especifico, la lista de nombres de personajes disponibles en la cuenta (dato
no sensible), lo que permitio identificar el nombre exacto
(`GOD VALENTINO`, todo en mayusculas) sin adivinar ni inspeccionar ningun
otro archivo. El tercer intento, con el nombre exacto, tuvo exito.

## Stack de TVP 7.72

**Este turno SI inicio el stack.** No estaba levantado al abrir el turno.

```text
cd servidor
docker compose up --build -d
```

Primera vez: reconstruyo la imagen del servidor (compilacion C++ completa,
~5 minutos) porque no habia imagen previa disponible en este entorno. No se
modifico `docker-compose.override.yml` ni ningun archivo de configuracion.
No se reseteo la base de datos ni se borraron volumenes: `servidor-server-1`
y `servidor-mariadb-1` ya existian (`Exited`) de una sesion anterior y se
recrearon/arrancaron sobre los mismos datos persistentes.

**Incidente intermedio:** justo despues de que la imagen terminara de
construirse, el puente CLI-a-motor de Docker Desktop se corto
(`failed to connect to the docker API ... The system cannot find the file
specified`), un problema ya conocido en este entorno. El usuario reinicio
Docker Desktop; eso detuvo los contenedores recien creados (comportamiento
normal de un reinicio del motor). Se corrio `docker compose up -d` una
segunda vez (sin `--build`, la imagen ya existia) y el stack quedo arriba
limpio: `servidor-mariadb-1` sano, `servidor-server-1` con
`>> TVP3D Server Online!` en su log.

Se verificaron ambos puertos abiertos con una conexion TCP simple antes de
capturar: `7171` (login) y `7172` (juego).

**Decision del usuario:** dejar el stack de TVP corriendo despues de este
turno (no se ejecuto `docker compose stop`).

## Adaptador de captura implementado

`cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` +
`.tscn` (nuevo, QA-owned, no reemplaza ni reescribe
`prueba_muerte_loot_vivo.gd`). Reutiliza en modo solo lectura
`res://red/conexion772.gd` y `res://red/estado_mundo.gd`; ninguno de los dos
se modifico.

Responsabilidades exactas implementadas:

1. conecta con la sesion god (unica sesion; no hay personaje normal en este
   camino, no hay duelo);
2. va al campo documentado `(32082,32145,6)` con `/gotopos` (misma casilla
   ya verificada fuera de zona de proteccion en Phase 2A; nunca aparece en
   el payload de salida);
3. registra ids de criaturas y casillas con corpse preexistentes antes de
   invocar, para poder identificar sin ambiguedad lo que crea esta corrida;
4. invoca exactamente una rata de prueba (`/m rat`);
5. identifica esa rata por id nuevo + nombre;
6. la mata reutilizando el mecanismo ya establecido (`enviar_atacar` +
   `/killall` de refuerzo, igual que el modo `--solo-loot` historico);
7. identifica su corpse nuevo (nombre que empieza con `dead `, casilla sin
   corpse previo);
8. confirma el nombre semantico observado (`dead rat`, en minusculas);
9. lo abre como contenedor real (`enviar_usar_item`);
10. confirma que el servidor lo trato como contenedor abrible (evento
    `contenedor_actualizado` recibido);
11. emite en stdout **una unica linea** `OBSERVATION_JSON: {...}` con
    exactamente los tres hechos normalizados, y nada mas.

El adaptador **no** decide PASS/FAIL: solo observa y serializa. Esa
responsabilidad sigue siendo exclusiva de `qa/parity/tools/replay.py`
(sin modificar en este turno), que compara la observacion contra la
`ParityExpectationV1` ya publicada en `qa 2.1.1`.

Se corrigio durante este turno un detalle de calidad menor detectado en la
propia corrida (no afecta el resultado ya capturado): al encontrar el
corpse, el script re-enviaba `enviar_usar_item` en cada frame mientras
esperaba la respuesta del servidor, en vez de pasar a un estado de espera.
Se agrego la transicion de fase faltante (`_pasar_a("saquear")`) para que
solo se envie una vez. Es una correccion de higiene de codigo sobre un
archivo nuevo de este mismo turno, no una recaptura contra TVP.

## Mutacion exacta ejecutada

- **Una** rata de prueba invocada por el god (`/m rat`).
- Esa misma rata, **matada** por el god.
- Su corpse, **creado y abierto** como contenedor real.

Nada mas se mutó: ningun jugador murió, no se ejecutó duelo ni reentrada, y
no se tocó al personaje normal (`Valentino`) en ningún momento de este
turno.

## Limpieza

El corpse `dead rat` creado por esta corrida queda en el mundo para
descomponerse de forma normal (comportamiento estandar del servidor); no se
ejecutó ninguna limpieza adicional ni se usó ningún comando de reinicio de
base de datos. No hace falta una limpieza especial: es exactamente el mismo
tipo de residuo que ya dejaban las corridas históricas `--solo-loot` de
`prueba_muerte_loot_vivo.gd`.

## Observacion normalizada

`qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`:

```json
{
  "schema": "tvp3d.qa.oracle_observation",
  "version": "1.0.0",
  "fixture_id": "PARITY-MONSTER-CORPSE-001",
  "oracle": "TVP_772",
  "oracle_version": "7.72",
  "capture_origin": "LIVE_ORACLE",
  "source_evidence": [
    {"logical_path": "docs/qa/PARITY_PHASE2B2_LIVE_MONSTER_CORPSE.md"}
  ],
  "payload": {
    "corpse": {"name": "dead rat", "openable_container": true, "present": true},
    "monster_kind": "rat"
  }
}
```

Construida por `qa/parity/tools/wrap_live_observation.py` (nuevo, QA-owned,
stdlib-only): toma la unica linea `OBSERVATION_JSON: ...` que emitio el
script de captura y la envuelve con la identidad de schema exacta. No
contiene id de runtime de la criatura, coordenadas del corpse, contenido de
loot, cuenta, clave, hostname, usuario, PID, timestamp de reloj de pared,
path absoluto ni volcado de paquetes: exactamente los tres hechos
normalizados que exige la seccion 16A del contrato.

## Replay

```text
py -3 qa/parity/tools/replay.py \
  --cases-dir qa/parity/cases/tvp772/death_corpse_loot \
  --observations-dir qa/parity/observations/tvp772/death_corpse_loot/live \
  --case-id PARITY-MONSTER-CORPSE-001 \
  --report qa/parity/reports/replay_live_monster_corpse_report.json
```

Mismo comparador generico ya committeado en Phase 2B.1, sin modificar. Se
ejecuto dos veces contra la misma observacion capturada:

```text
PASS PARITY-MONSTER-CORPSE-001
exit=0 pass=1 fail=0 blocked=0 not_run=0
```

Reporte byte-identico entre ambas corridas (confirmado con `diff`).

| Campo | Valor |
|---|---|
| `status` | `PASS` |
| `assertions_total` | 4 |
| `assertions_passed` | 4 |

El comportamiento fresco de TVP coincidio exactamente con la expectativa ya
publicada; no se ajusto la expectativa para forzar el resultado (el
resultado fue verde de forma genuina en la primera corrida valida).

## Desalineamiento de mapa 0x64

No se investigo ni se toco `protocolo-red`/`assets`. La corrida no dependio
del camino completo de duelo (unica sesion god, sin personaje normal), asi
que no se acerco al escenario donde aparecio ese desalineamiento en Phase
2A. Sigue como `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`, sin
resolverse ni promoverse falsamente a resuelto.

## Sin credenciales almacenadas

Ningun archivo nuevo o modificado en este turno (`cliente3d/pruebas/*.gd`,
`.tscn`, `qa/parity/tools/*.py`, la observacion, el reporte, este documento,
`worklog/qa/STATE.md`, `worklog/EVENTS.jsonl`) contiene un valor de cuenta,
contraseña, clave privada o cualquier literal con forma de secreto.
Verificado con un escaneo de patrones de secreto sobre todos los archivos
nuevos/modificados antes del commit.

## Conteos

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A) | 4 | 4 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (Phase 2B.1) | 4 | 4 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 (sin cambio) |
| Observaciones `LIVE_ORACLE` | 1 (planeada) | **1** (`PARITY-MONSTER-CORPSE-001`, `PASS`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 1 |

Ninguna de estas cuentas se combina con otra: capturar y replayar esta
observacion no materializa ninguna de las 198 obligaciones de contrato
Architecture V2.

## Proximo paso recomendado

Con el boundary de replay ya probado de extremo a extremo contra un oracle
real, un turno futuro puede: (a) extender la misma tecnica a
`PARITY-DEATH-CORPSE-001`/`PARITY-DEATH-REENTRY-001` si alguna vez se
decide certificar esos dos en vivo (lo que si implicaria un flujo de
muerte/reentrada real, fuera del alcance de este turno), o (b) investigar el
desalineamiento de mapa `0x64` como su propia linea de evidencia, ahora que
existe un camino de captura en vivo probado y mas simple (solo god, sin
duelo) que podria servir de base para aislar ese problema sin volver a
depender de la corrida completa de duelo.
