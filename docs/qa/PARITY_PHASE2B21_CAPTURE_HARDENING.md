# Phase 2B.2.1 — Endurecimiento y recertificacion de la primera captura viva

Estado: **exito**. El resultado historico de Phase 2B.2
(`PARITY-MONSTER-CORPSE-001`, `LIVE_ORACLE`, `dead rat`, contenedor abrible,
replay `PASS 4/4`, commit `df6d414648aeb61f910979e82d1a0d0632ed7ea4`) sigue
siendo **historico y genuino**: fue un resultado real contra TVP en vivo y no
se reescribe ni se invalida aqui. Este turno es de endurecimiento: corrige
cuatro defectos de robustez detectados en revision y **vuelve a certificar en
vivo el codigo final exacto que se commitea**, porque Phase 2B.2 habia
aplicado un ajuste de higiene de codigo *despues* de su corrida exitosa, sin
recapturar contra ese codigo final.

## Por que hacia falta recertificar

1. Phase 2B.2 documento explicitamente que el script de captura recibio una
   correccion de higiene de codigo (una transicion de fase faltante antes de
   `_abrir_corpse()`) **despues** de la corrida exitosa. El adaptador
   exactamente commiteado nunca habia corrido en vivo.
2. El payload serializaba `_nombre_corpse.to_lower()`, ocultando cualquier
   diferencia de capitalizacion real que TVP pudiera emitir.
3. El fallback `/killall` se emitia sin verificar su area real de efecto,
   arriesgando matar una criatura salvaje preexistente como colateral.
4. `wrap_live_observation.py` decia consumir "exactamente una" linea
   `OBSERVATION_JSON` pero en realidad devolvia la primera coincidencia y
   ignoraba silenciosamente cualquier otra.

## Fix 1 — nombre de corpse preservado tal cual

`cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd`,
`_emitir_observacion()`: se elimino `.to_lower()` sobre `_nombre_corpse` al
construir el payload. La comparacion en minusculas se sigue usando
**exclusivamente como logica de descubrimiento** (`_buscar_monstruo`,
`_contenedor_en`) para localizar candidatos por nombre; el hecho observado
que se versiona es el string exacto que emitio el servidor. Si TVP emitiera
`"Dead Rat"` o `"DEAD RAT"`, la observacion lo preservaria tal cual y
`qa/parity/tools/replay.py` (sin modificar) decidiria `FAIL` contra la
expectativa publicada (`"dead rat"`), en vez de que la captura oculte la
diferencia.

## Fix 2 — `/killall` acotado a su area real

Se leyo, sin modificar:

- `servidor/data/scripts/talkactions/god/kill_creatures.lua`: el talkaction
  ejecuta `combat:execute(player, Variant(player:getPosition()))` con
  `combat:setArea(createCombatArea(AREA_SQUARE1X1))`, y su callback
  `onTargetCreature` inflige dano letal (`-getMaxHealth()`) a **todo**
  monstruo alcanzado, no solo al objetivo de la prueba.
- `servidor/data/scripts/spells/areas.lua`: `AREA_SQUARE1X1` es una matriz
  3x3 (`{{1,1,1},{1,3,1},{1,1,1}}`), es decir radio Chebyshev 1 centrado en
  el origen — en este talkaction, la posicion propia de quien lo dice (el
  god), no la del objetivo.

Se agrego `_area_de_killall_segura(centro)`: antes de cada intento de
`/killall`, recorre `_estado.criaturas` y rechaza el envio si existe **otra**
criatura viva (excluyendo al god y a la rata de esta corrida) dentro de un
cuadrado de radio 1 alrededor de la posicion actual del god, en el mismo
piso. Si la deteccion falla la comprobacion, `/killall` **no se emite** ese
ciclo (se imprime un diagnostico y se sigue esperando el ataque directo ya
enviado); nunca se reposiciona a otra casilla con logica nueva. Si el
monstruo nunca muere, el timeout global existente (`LIMITE_TOTAL`, 180s) ya
produce un `FAIL` honesto por tiempo agotado — no se inventa un mecanismo de
reintento adicional.

**En la corrida de recertificacion de este turno, `/killall` nunca llego a
emitirse**: la rata invocada murio por el ataque directo
(`enviar_atacar`/`enviar_modos_combate`) antes de que se cumpliera el umbral
de espera de 6 segundos que dispara el fallback. La funcion de aislamiento
quedo escrita y lista, pero no fue ejercitada por esta corrida especifica
porque no hizo falta.

## Fix 3 — sin enumeracion de personajes en el log de fallo

`_al_recibir_personajes`: el mensaje de fallo cuando
`TVP772_GOD_CHARACTER` no coincide con ningun personaje de la cuenta ya no
imprime la lista de nombres disponibles. El mensaje ahora es exactamente:

```text
FAIL character configured by TVP772_GOD_CHARACTER was not found
```

Sin el valor configurado, sin los demas nombres de personaje, sin id de
cuenta ni clave.

## Fix 4 — regla de una sola etiqueta en el wrapper

`qa/parity/tools/wrap_live_observation.py`, `extract_payload()`: ahora
escanea el archivo de log completo y junta **todas** las lineas que empiezan
con `OBSERVATION_JSON: `. Comportamiento exacto:

| Cantidad de lineas etiquetadas | Resultado |
|---|---|
| 0 | rechazado (`WrapError`) |
| exactamente 1 | se parsea y se usa |
| 2 o mas | rechazado como ambiguo (`WrapError`), nunca se elige la primera |
| JSON invalido en la unica linea | rechazado |
| JSON valido pero no es un objeto (por ejemplo un array) | rechazado |

Ademas, en el mismo endurecimiento:

- **Validacion de `--source-evidence`:** cada path se valida con las mismas
  reglas ya publicadas para `OracleObservationV1.source_evidence[].logical_path`
  (relativo al repositorio, sin `/` inicial, sin unidad de disco Windows,
  sin backslash, sin segmento `..`, debe resolver a un archivo existente).
  Se rechaza antes de escribir cualquier salida.
- **Escritura atomica:** el documento se escribe primero a un archivo
  temporal en el mismo directorio de destino (`tempfile.mkstemp`) y recien
  se reemplaza el destino con `os.replace()` una vez que el documento
  completo esta listo. Un fallo a mitad de camino nunca deja un archivo
  truncado ni pisa una salida preexistente; el temporal se borra en
  cualquier excepcion.
- **Auto-prueba (`--selftest`, stdlib-only):** 14 comprobaciones en memoria/
  directorio temporal, todas `OK`, codigo de salida 0. Cubre exactamente los
  casos exigidos: cero etiquetas, una etiqueta valida, dos etiquetas,
  JSON malformado, array en vez de objeto, payload con forma de secreto,
  path POSIX absoluto, path Windows absoluto, traversal `..`, archivo de
  evidencia inexistente, path valido aceptado, que un fallo no pise un
  archivo de salida centinela preexistente, y que una escritura exitosa
  efectivamente contenga `LIVE_ORACLE` sin dejar temporales huerfanos.

## `replay.py` sin modificar

`qa/parity/tools/replay.py` ya habia producido el resultado valido 4/4 en
Phase 2B.2. No se detecto ningun defecto concreto durante este turno de
endurecimiento, asi que **no se modifico**: la recertificacion en vivo usa
exactamente el mismo comparador generico ya commiteado.

## Congelamiento del codigo antes de la corrida en vivo

Workflow seguido exactamente como exige este turno:

1. se terminaron todos los cambios de codigo de captura/wrapper;
2. se corrieron las pruebas locales (`--check-only` de Godot sobre el `.gd`;
   `--selftest` del wrapper, 14/14 `OK`);
3. se reviso el diff completo de ambos archivos contra el commit anterior;
4. se congelo la implementacion y se calcularon los hashes SHA-256:

| Archivo | SHA-256 antes de la corrida en vivo |
|---|---|
| `cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` | `a36a2ac414899c91355952cd0fb1e8bfdffc2d25d311f83fa01ca2e28f999b3b` |
| `qa/parity/tools/wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |

5. se ejecuto la captura en vivo contra TVP real;
6. se genero la `OracleObservationV1`;
7. se replayo dos veces;
8. se confirmo que los reportes son deterministicos (byte-identicos);
9. se recalcularon los mismos dos hashes:

| Archivo | SHA-256 despues de la corrida en vivo |
|---|---|
| `cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` | `a36a2ac414899c91355952cd0fb1e8bfdffc2d25d311f83fa01ca2e28f999b3b` |
| `qa/parity/tools/wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |

**Ambos hashes coinciden exactamente entre "antes" y "despues".** El codigo
que se commitea es exactamente el codigo que corrio en vivo; no se modifico
ninguno de los dos archivos despues de la corrida certificada.

## Prerequisitos verificados antes de la recertificacion

- `docker ps`: alcanzable. El stack de TVP de Phase 2B.2
  (`servidor-server-1`, `servidor-mariadb-1`) seguia arriba (decision del
  usuario en el turno anterior de no apagarlo); no hizo falta levantarlo de
  nuevo en este turno.
- Variables de entorno `TVP772_ACCOUNT`/`TVP772_PASSWORD`/
  `TVP772_GOD_CHARACTER`: comprobada solo su presencia/ausencia (nunca
  valores) al abrir el turno; estaban ausentes en el shell de esta sesion
  (variables de proceso, no persistentes). El usuario confirmo reusar las
  mismas credenciales ya validadas en Phase 2B.2 sin necesidad de volver a
  pegarlas en la conversacion.

## Ejecucion en vivo (post-congelamiento)

Una unica ejecucion de
`cliente3d/pruebas/prueba_parity_monster_corpse_capture.tscn`, codigo de
salida `0`:

```text
Dentro con la sesion god.
God en el campo: (32081, 32144, 6).
Invocado rat con id 1073764897.
Corpse encontrado en (32081, 32142, 6): dead rat
Corpse abierto como contenedor: 'dead rat'.
OBSERVATION_JSON: {"corpse":{"name":"dead rat","openable_container":true,"present":true},"monster_kind":"rat"}
Prueba de captura en vivo (monster corpse): OK
```

Exactamente una linea `OBSERVATION_JSON:` en el log (confirmado con
`grep -c`).

**`/killall` no se emitio en esta corrida:** la rata invocada murio por el
ataque directo antes de que se cumpliera el umbral de 6 segundos del
fallback, asi que la guarda de aislamiento de area (Fix 2) quedo lista pero
no fue ejercitada por necesidad real en esta ejecucion especifica.

## Mutacion exacta ejecutada

- Una rata de prueba invocada por el god (id de runtime nuevo,
  `1073764897`, nunca versionado en la observacion).
- Esa misma rata, matada por el **ataque directo** del god (no por
  `/killall`).
- Su corpse, creado y abierto como contenedor real.

**Prueba de que no hubo colateral:** `/killall` nunca se envio en esta
corrida (no aparece en el log de captura), por lo tanto el area de efecto de
ese talkaction nunca se activo y ninguna otra criatura pudo resultar
afectada por el. Cero jugadores murieron; no se ejecuto duelo ni
reentrada; no se toco al personaje normal (`Valentino`).

## Nombre de corpse observado (crudo, sin normalizar)

`"dead rat"` — exactamente como lo emitio el servidor, ya en minusculas de
forma nativa. No se fuerzo ninguna capitalizacion; la ausencia de
`.to_lower()` en el codigo de serializacion significa que, si el servidor
hubiera emitido otra capitalizacion, este documento la habria preservado
igual.

## Observacion normalizada

Regenerada con `qa/parity/tools/wrap_live_observation.py` (version
endurecida), con `--source-evidence` apuntando a este mismo documento:

```json
{
  "schema": "tvp3d.qa.oracle_observation",
  "version": "1.0.0",
  "fixture_id": "PARITY-MONSTER-CORPSE-001",
  "oracle": "TVP_772",
  "oracle_version": "7.72",
  "capture_origin": "LIVE_ORACLE",
  "source_evidence": [
    {"logical_path": "docs/qa/PARITY_PHASE2B21_CAPTURE_HARDENING.md"}
  ],
  "payload": {
    "corpse": {"name": "dead rat", "openable_container": true, "present": true},
    "monster_kind": "rat"
  }
}
```

Ruta: `qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`
(reemplaza, no acumula, la observacion `LIVE_ORACLE` de Phase 2B.2 para este
mismo `fixture_id`; sigue existiendo una sola observacion viva canonica por
fixture).

## Replay

```text
py -3 qa/parity/tools/replay.py \
  --cases-dir qa/parity/cases/tvp772/death_corpse_loot \
  --observations-dir qa/parity/observations/tvp772/death_corpse_loot/live \
  --case-id PARITY-MONSTER-CORPSE-001 \
  --report qa/parity/reports/replay_live_monster_corpse_report.json
```

Ejecutado dos veces contra la misma observacion fresca:

```text
PASS PARITY-MONSTER-CORPSE-001
exit=0 pass=1 fail=0 blocked=0 not_run=0
```

| Campo | Valor |
|---|---|
| `status` | `PASS` |
| `assertions_total` | 4 |
| `assertions_passed` | 4 |

Reporte byte-identico entre ambas corridas (confirmado con `diff`). El
resultado es genuino: el comportamiento fresco de TVP coincidio con la
expectativa ya publicada sin ajustar nada para forzarlo.

## Sin credenciales almacenadas

Ningun archivo nuevo o modificado en este turno contiene un valor de cuenta,
contraseña, clave privada o cualquier literal con forma de secreto.
Verificado con un escaneo de patrones de secreto sobre todos los archivos
nuevos/modificados antes del commit. No se comito ningun log crudo de
captura ni volcado de paquetes.

## Desalineamiento de mapa 0x64

No se investigo ni se toco `protocolo-red`/`assets` en este turno. Sigue
como `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`.

## Archivos de implementacion sin cambios despues de la corrida certificada

Confirmado explicitamente: ningun cambio se aplico a
`cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` ni a
`qa/parity/tools/wrap_live_observation.py` entre el congelamiento (paso 4) y
el commit de este turno. Los hashes SHA-256 de la tabla de arriba lo
confirman byte a byte.

## Conteos

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A) | 4 | 4 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (Phase 2B.1) | 4 | 4 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | 1 (`PARITY-MONSTER-CORPSE-001`) | 1 (recertificada, `PASS`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 1 |

## Proximo paso recomendado

El camino de captura en vivo ahora esta endurecido y re-certificado contra
su propio codigo final. Un turno futuro puede reutilizar la misma tecnica
para investigar el desalineamiento de mapa `0x64` como su propia linea de
evidencia, o evaluar si algun otro fixture `SINGLE_OBSERVATION` amerita su
propio adaptador de captura narrow siguiendo este mismo patron (congelar
codigo -> hash -> capturar -> re-hashear -> confirmar identico).
