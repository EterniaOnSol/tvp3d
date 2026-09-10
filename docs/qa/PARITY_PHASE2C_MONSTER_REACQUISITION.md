# Phase 2C — Slice de paridad: reacquisicion de objetivo de monstruo

Estado: **parcial**. El trabajo local esta completo y verde
(`PARITY-MONSTER-REACQUISITION-001` materializado, replay contra evidencia
grabada `PASS 12/12`, adaptador de captura en vivo implementado y endurecido).
La **certificacion en vivo quedo `BLOCKED`** por una restriccion real del
entorno, documentada abajo sin fabricar ningun resultado.

## Evidencia historica de origen

`docs/qa/PRUEBA_VIVA_REACQUISICION.md` (2026-08-29, estado COMPROBADO).
Registra una corrida valida con: cave rat invocado id `1073764894`, primer
golpe autoritativo nombrando `a cave rat` (133 -> 131 HP), personaje alejado
39 SQM sin logout/muerte/cambio de piso, reingreso con el **mismo** id de
cave rat visible, segundo golpe autoritativo nombrando otra vez `a cave rat`
(131 -> 128 HP), limpieza del monstruo invocado, sin muerte ni perdida de
nivel.

Ese documento tambien registra que una corrida preliminar **se descarto**
porque una `spider` silvestre habia causado las bajadas de vida — hallazgo
que endurecio el oracle para exigir que el nombre del atacante forme parte
obligatoria de la evidencia. Esa corrida invalida NO se usa como evidencia de
este fixture.

## Semantica del fixture

`PARITY-MONSTER-REACQUISITION-001`, `tvp3d.qa.parity_fixture/2.0.0`,
oracle `TVP_772` / `7.72`, clasificacion `MATCH_EXPECTED`.

### Que se observa directamente vs que se infiere

**Directamente observable** (y por lo tanto lo unico que el fixture afirma):

1. un cave rat recien invocado, con runtime id que no existia antes, ataca al
   personaje (mensaje autoritativo de dano que lo nombra + vida que baja);
2. el personaje se aleja sin logout, sin muerte y sin cambio de piso;
3. el runtime id de ese cave rat **desaparece** del conjunto de criaturas
   visibles del personaje;
4. el personaje vuelve;
5. **el mismo** runtime id reaparece en su conjunto visible;
6. un segundo ataque autoritativo de cave rat vuelve a bajarle la vida.

**Inferido, y deliberadamente NO afirmado:** que el monstruo conservo
internamente su puntero `attackedCreature`. El oracle en vivo no expone
estado interno de TFS/TVP, asi que el fixture **no** emite nada equivalente a
`attacked_creature_pointer_preserved`. La evidencia es *consistente con*
retencion/reacquisicion de objetivo; el fixture afirma solo el
comportamiento observable.

Esto tampoco define Monster Domain V2: es evidencia legacy de Phase 2.

## Las 12 aserciones

`ParityExpectationV1` (`tvp3d.qa.parity_expectation/1.0.0`), modo
`SINGLE_OBSERVATION`, 12 aserciones (dentro del rango publicado `1..32`),
todas `EQ`:

| # | `assertion_id` | `left_path` | esperado |
|---|---|---|---|
| 1 | `MONSTER-KIND` | `/monster_kind` | `"cave rat"` |
| 2 | `BEFORE-ATTACK-OBSERVED` | `/before_leave/attack_observed` | `true` |
| 3 | `BEFORE-ATTACKER-MATCHES` | `/before_leave/attacker_matches_monster_kind` | `true` |
| 4 | `BEFORE-HP-DECREASED` | `/before_leave/hp_decreased` | `true` |
| 5 | `GAP-TARGET-LEFT-VISIBLE-SET` | `/visibility_gap/target_left_visible_set` | `true` |
| 6 | `GAP-SESSION-CONTINUED` | `/visibility_gap/player_session_continued` | `true` |
| 7 | `GAP-PLAYER-SURVIVED` | `/visibility_gap/player_survived` | `true` |
| 8 | `AFTER-TARGET-REAPPEARED` | `/after_return/target_reappeared` | `true` |
| 9 | `AFTER-SAME-RUNTIME-ID` | `/after_return/same_runtime_id` | `true` |
| 10 | `AFTER-ATTACK-OBSERVED` | `/after_return/attack_observed` | `true` |
| 11 | `AFTER-ATTACKER-MATCHES` | `/after_return/attacker_matches_monster_kind` | `true` |
| 12 | `AFTER-HP-DECREASED` | `/after_return/hp_decreased` | `true` |

Las 12 estan justificadas por la evidencia historica; no hizo falta reducir
ninguna. La limpieza (retirar el monstruo, devolver al personaje) es higiene
del harness y **no** es parte de la expectativa de paridad.

## Decisiones de normalizacion

Excluidos de la comparacion determinista (`excluded_nondeterministic_fields`):
`monster_runtime_id`, `exact_hp_values`, `exact_damage_amounts`,
`field_coordinates`, `travel_distance`, `wall_clock_timestamp`.

Se preserva la **relacion**, no el valor: el runtime id real se compara solo
en memoria de proceso (mismo id antes y despues), y lo que se versiona es el
booleano `same_runtime_id`. Ningun id, HP, dano ni coordenada entra al
payload.

Una bajada de vida generica NO satisface la condicion de ataque: se exige el
mensaje autoritativo que nombre al cave rat.

## Replay contra evidencia grabada

```text
py -3 qa/parity/tools/replay.py \
  --cases-dir qa/parity/cases/tvp772/monster_reacquisition \
  --observations-dir qa/parity/observations/tvp772/monster_reacquisition/recorded \
  --report qa/parity/reports/replay_recorded_monster_reacquisition_report.json
```

Resultado, dos corridas, reporte byte-identico (confirmado con `diff`):

```text
PASS PARITY-MONSTER-REACQUISITION-001
exit=0 pass=1 fail=0 blocked=0 not_run=0
```

`assertions_total=12`, `assertions_passed=12`. `qa/parity/tools/replay.py` no
se modifico: el comparador generico ya publicado acepto el nuevo dominio sin
cambios, lo que confirma que generaliza mas alla del comportamiento de
corpse.

## Adaptador de captura en vivo

`cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd` + `.tscn`
(nuevos, QA-owned). `prueba_reacquisicion_monstruo.gd` **no se modifico**:
sigue siendo evidencia historica con su configuracion fija.

Reutiliza en modo solo lectura `res://red/conexion772.gd` y
`res://red/estado_mundo.gd`; `cliente3d/red/` no se toco.

Credenciales exclusivamente por entorno, sin defaults y sin literales:
`TVP772_ACCOUNT`, `TVP772_PASSWORD`, `TVP772_GOD_CHARACTER`,
`TVP772_PLAYER_CHARACTER` (opcionales `TVP772_HOST`, `TVP772_LOGIN_PORT`).
Variable ausente produce `BLOCKED missing environment variable <NOMBRE>` sin
imprimir ningun valor, y un personaje no encontrado NO enumera los demas
personajes de la cuenta.

### Protecciones contra falsos positivos (verificadas en vivo)

Estas protecciones no son teoricas: **se dispararon repetidamente durante las
13 corridas en vivo de este turno**, y en ninguna se emitio una observacion
fabricada.

1. **Sin `/killall` amplio inicial.** A diferencia del test historico, este
   adaptador NO limpia el campo con un area de efecto. Antes de invocar
   inspecciona el campo: si ya hay un cave rat vivo visible, aborta
   (`BLOCKED`) en vez de matar fauna preexistente.
2. **Identidad del objetivo.** Se registran todos los ids conocidos antes de
   `/m cave rat`; el objetivo debe tener un id que no existia antes, nombre
   `cave rat`, y estar en el estado autoritativo del personaje normal. Si
   aparece mas de un cave rat nuevo a la vez, aborta por ambiguedad.
3. **Ataque desambiguado.** Una bajada de vida generica nunca alcanza: se
   exige mensaje autoritativo nombrando al cave rat **y** que en ese momento
   exista exactamente un cave rat vivo visible, que sea el objetivo esperado.
   Un ataque de `spider` no puede satisfacer la condicion (se observo
   literalmente esa interferencia en vivo y fue correctamente rechazada).
4. **Reaparicion por id, no por nombre.** Si tras volver aparece un cave rat
   con id distinto mientras el objetivo original sigue ausente, es `FAIL`
   explicito: "mismo nombre, id distinto" NO es reacquisicion de la misma
   instancia.
5. **Salida de vista probada, no inferida.** No se asume "fuera de rango" por
   distancia ni por tiempo: se exige que el runtime id del objetivo
   efectivamente desaparezca del diccionario de criaturas del personaje.
6. **Limpieza acotada.** Ataque dirigido contra el objetivo; `/killall` solo
   como fallback y solo si su area real (AREA_SQUARE1X1, radio Chebyshev 1,
   segun `kill_creatures.lua` + `areas.lua`) no contiene otra criatura viva,
   reusando la regla ya establecida en Phase 2B.2.1.

## Certificacion en vivo: BLOCKED

**No se produjo ninguna observacion `LIVE_ORACLE`. No se creo
`qa/parity/observations/tvp772/monster_reacquisition/live/parity-monster-reacquisition-001.observation.json`
ni `qa/parity/reports/replay_live_monster_reacquisition_report.json`.**

### Prerequisitos (todos disponibles)

- `docker ps`: alcanzable; stack TVP 7.72 arriba, puertos 7171/7172
  respondiendo. Durante el turno el servidor hizo un ciclo propio de
  auto-guardado y apagado programado (rutina legacy, ajena a este adaptador)
  y se lo volvio a levantar con `docker compose up -d`, sin `--build`, sin
  resetear datos ni volumenes.
- Las cuatro variables de entorno fueron provistas por el usuario para la
  ejecucion puntual (nunca escritas a archivo, nunca impresas).

### Razon exacta del bloqueo

Trece ejecuciones en vivo. Ninguna alcanzo una medicion sin ambiguedad. La
causa es un conflicto real entre dos requisitos legitimos del propio turno,
sobre este terreno especifico:

- el turno prohibe (correctamente) el `/killall` amplio inicial que el test
  historico si usaba para limpiar el campo;
- el turno exige (correctamente) abortar si un segundo cave rat puede hacer
  ambigua la identidad del atacante.

El terreno de prueba certificado es **zona de spawn de cave rats de Thais**
(el propio servidor programa un raid `thaiscaverats`). Sin limpieza previa,
cave rats silvestres entran continuamente al campo visible, de modo que la
proteccion 3 se dispara casi siempre. Se probaron ambas casillas ya
certificadas (`(32082,32145,6)` y `(32083,32184,6)`, intercambiando sus
roles); la segunda tiene menos spiders pero sigue teniendo cave rats
silvestres.

Ademas, el personaje de prueba disponible es de nivel 1 con ~140 HP: en las
corridas donde la ambiguedad no se disparo, el dano acumulado de la fauna del
campo lo llevo a cero antes de completar la ventana de medicion (~45 s).

Desglose honesto de las 13 corridas:

| Resultado | Corridas |
|---|---|
| Abortadas por ambiguedad de identidad (proteccion 3) | 8 |
| Abortadas por vida cero del personaje antes de medir | 3 |
| Abortadas por cave rat preexistente antes de invocar (proteccion 1) | 2 |
| Observaciones fabricadas | **0** |

En ningun caso se ajusto la expectativa, se relajo una proteccion ni se
reetiqueto evidencia grabada como en vivo para forzar un verde.

### Muertes de jugador

**Este turno SI produjo muertes del personaje de prueba** (`Valentino`), a
diferencia de Phase 2B.2/2B.2.1. Se registraron mensajes autoritativos
`You are dead` y el servidor lo revivio en su templo. Reportarlo como
"0 muertes" seria falso.

Las primeras muertes fueron consecuencia de un defecto propio de la primera
version del adaptador: al abortar no devolvia al personaje a un lugar seguro,
asi que quedaba expuesto en campo abierto y era atacado apenas reconectaba en
la corrida siguiente. Ese defecto se corrigio a mitad del turno (limpieza de
emergencia + retorno al templo en cualquier salida por fallo) y se verifico
funcionando en corridas posteriores. Las muertes restantes fueron
consecuencia directa de la densidad de fauna del terreno contra un personaje
de nivel 1, no de un defecto del adaptador.

El usuario fue informado de cada muerte y decidio explicitamente continuar.

### Estado final del entorno (verificado)

- `Valentino`: vivo, 134 HP, en el templo `(32369,32241,7)`.
- Cave rats vivos visibles desde el personaje: **0**.
- Cada cave rat invocado por este turno fue retirado por ataque dirigido; dos
  quedaron vivos tras corridas interrumpidas y se limpiaron despues, tambien
  por ataque dirigido puntual, nunca con un area de efecto.
- No se reseteo la base de datos ni se borraron volumenes de Docker.

## Hashes congelados

La implementacion se congelo antes de cada intento de corrida en vivo. Como
**ninguna corrida en vivo tuvo exito**, no existe un par "antes/despues" de
una certificacion: los hashes que siguen son los del codigo efectivamente
commiteado, que es el mismo que se ejecuto en la ultima tanda de intentos.

| Archivo | SHA-256 |
|---|---|
| `qa/parity/fixtures/tvp772/monster_reacquisition/parity-monster-reacquisition-001.json` | `c3078f03f35f38fbd32d691c6f6eaae67acd6093a70667235c30b429dbedbd5f` |
| `qa/parity/cases/tvp772/monster_reacquisition/parity-monster-reacquisition-001.case.json` | `88b81ed0f70b6ade854c07b9067ffb579bf33158a45de8cf687c2285452050c9` |
| `cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd` | `3e444006c6f6668b120a024162e9d45b7484aa29466c9c9905e0b482540d4a66` |
| `qa/parity/tools/replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `qa/parity/tools/wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |

El fixture y la expectativa quedaron congelados **antes** del primer intento
en vivo y no se modificaron en ningun momento posterior: ni una sola de las
13 corridas provoco un ajuste de la expectativa. `replay.py` y
`wrap_live_observation.py` no se modificaron en este turno.

## Credenciales

Ningun archivo nuevo o modificado contiene valores de cuenta, clave o nombre
de personaje. Solo aparecen **nombres** de variables de entorno. No se
comitio ningun log crudo de captura. No se inspecciono `servidor/key.pem`.

## Desalineamiento de mapa 0x64

No se investigo ni se toco `protocolo-red`/`assets`. Sigue como
`INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`. No aparecio como causa
de ninguno de los abortos de este turno.

## Conteos

| Inventario | Antes | Despues |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 | 198 / 0 materializadas | 198 / 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | 4 | **5** |
| Casos de replay `QACaseV2` | 4 | **5** |
| Observaciones `RECORDED_EVIDENCE` | 3 | **4** |
| Observaciones `LIVE_ORACLE` | 1 | 1 (sin cambio; la de reacquisicion quedo `BLOCKED`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 13 intentos, 0 certificaciones |

Ninguna de estas cuentas se combina con otra: los cinco fixtures de paridad
NO cuentan para las 198 obligaciones de contrato Architecture V2.

## Proximo paso recomendado

Para completar la certificacion en vivo de este fixture haria falta resolver
la tension terreno/ambiguedad de forma legitima, por ejemplo: (a) identificar
una casilla del mismo piso, fuera de PZ, que **no** este en zona de spawn de
cave rats, y certificarla como tercer terreno de prueba; (b) usar un
personaje de prueba con suficiente vida para sostener la ventana de medicion
sin morir; o (c) publicar contractualmente una forma acotada y segura de
aislar el campo (mas estrecha que `/killall`) que no dependa de matar fauna
preexistente. Ninguna de las tres se ejecuta en este turno.
