# Estado: qa

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-09-11T15:10:00-06:00
Contrato publicado: SI (`CONTRATO.md` v2.1.1, sin cambios en este turno)

## Turno cerrado: Phase 2D — Party y experiencia compartida (TERCER DOMINIO)

Tercer dominio de paridad, abierto con **dos fixtures independientes**. Los
**dos quedaron CERTIFICADOS EN VIVO**. Detalle en
`docs/qa/PARITY_PHASE2D_PARTY_LIFECYCLE.md` y
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`.

### A. `PARITY-PARTY-LIFECYCLE-001` — certificado

- Fixture, `QACaseV2` (**15 aserciones `EQ`**), observacion
  `RECORDED_EVIDENCE` y observacion `LIVE_ORACLE`.
- Replay grabado y replay vivo: **PASS 15/15**, byte-identicos entre dos
  corridas cada uno.
- **Exito al primer intento vivo.** Cero muertes, cero combate, cero
  monstruos invocados.
- Evidencia grabada tomada de `docs/qa/PRUEBA_VIVA_PARTY.md` (2026-08-29),
  que documenta las cinco etapas con sus escudos.
- Se comparan **roles**, nunca identidades.

### B. `PARITY-PARTY-SHARED-EXP-001` — certificado

- Fixture, `QACaseV2` (**13 aserciones `EQ`**) y observacion `LIVE_ORACLE`.
  Replay vivo **PASS 13/13**, byte-identico entre dos corridas.
- **Sin observacion `RECORDED_EVIDENCE`, a proposito.**
  `docs/qa/PRUEBA_VIVA_PARTY.md` (lineas 67-74) prueba que la experiencia
  compartida **nunca se ejercito** en aquella corrida. Fabricar una
  observacion grabada habria sido inventar evidencia. Por eso el corpus
  `RECORDED_EVIDENCE` queda en **5** y no en 6.
- **Se probo el reparto real de experiencia, no solo el mensaje del toggle**:
  ambos participantes ganaron, en partes iguales, coincidentes con la formula
  vigente del oracle.
- **Hallazgo convertido en evidencia:** `Game::playerEnableSharedPartyExperience`
  (`servidor/src/game.cpp:5097`) **descarta en silencio** la orden si el
  solicitante tiene `CONDITION_INFIGHT` fuera de zona protegida: ni mensaje ni
  cambio de estado. Aparecio como un falso fallo de la captura y termino
  siendo una asercion propia (`DISABLE-IGNORED-WHILE-IN-FIGHT`).
- **Semantica clave verificada en `creature.cpp:368-413`:** las partes
  proporcionales al dano se **juntan primero en un unico pozo de la party** y
  el pago individual queda suprimido; el pozo se paga **una sola vez** via el
  lider y recien ahi se divide. **Quien golpeo mas no cobra mas.** Corolario:
  el dano de un tercero ajeno a la party **le resta** al pozo, por eso el god
  nunca golpea al monstruo.
- `enabled` **no viaja por la red** y no se afirma leyendo estado interno: se
  deriva por comportamiento (ganancias iguales y coincidentes con la formula).
- **NO se afirman** la regla de nivel (`ceil(nivel_mas_alto*2/3)`) ni la de
  rango (`areInRange<30,30,1>`): exigen casos negativos dedicados, previstos
  como fixtures futuros.

### Costo declarado, sin disimular

**Diez intentos en vivo** para el fixture de experiencia compartida, muy por
encima del maximo de 3 por fixture. Se declara explicitamente. Cada fallo fue
real y dejo una correccion: personaje inexistente; **una sola sesion por
cuenta** en cuentas normales (hubo que usar dos cuentas distintas);
reentrada de `_formar_party` porque `await` no frena `_process`; identidad
ambigua por fauna silvestre; dano insuficiente de nivel 1; vida baja de
resaca; y la regla de combate.

### Mutaciones persistentes

El god subio, **solo a los dos personajes de QA creados para esto**, punos
(+18) y nivel (+12) con `/addSkill`. El nivel se aplica **antes** de la foto
de experiencia y la medicion es un **delta**, asi que no contamina. Punos no
toca experiencia. A los dos por igual, para no romper la regla de nivel.
Ningun personaje del usuario fue tocado. **0 muertes, 1 monstruo invocado, 0
usos de `/killall`** (no se mato fauna preexistente: la identidad del
monstruo se resuelve por **id nuevo**, no por nombre).

### Congelamiento verificado

Los cinco hashes congelados antes de la captura viva de experiencia
compartida quedaron **identicos** despues del wrap y de los dos replays.
`qa/parity/tools/replay.py` y `wrap_live_observation.py` **no se modificaron**:
el comparador generico acepto un **tercer** y un **cuarto** dominio de
comportamiento sin ningun cambio.

### Requisito diferido para el TVP3D nativo

La semantica legacy (`0xA3`/`0xA4`/`0xA6`/`0xA7`/`0xA8`, `PartyShields_t`,
`party.lua`) **no entra** a los contratos de Architecture V2, que siguen en
**198 especificadas / 0 materializadas, sin cambio**. La lista completa de lo
que el servidor nativo debera reproducir esta en
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`.

## Conteos (Phase 2D)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **7** (antes 5) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **7** (antes 5) |
| Observaciones `RECORDED_EVIDENCE` | — | **5** (antes 4; +1, no +2, a proposito) |
| Observaciones `LIVE_ORACLE` canonicas | — | **4** (antes 2) |

Phase 2 sigue **EN CURSO**: este turno amplia el corpus de oracle, no lo
cierra.

**Le toca:** los casos negativos de elegibilidad de experiencia compartida
(nivel y rango), que son los unicos huecos declarados de este dominio. **No**
implementar el sistema de party nativo: eso es Phase 3.

## Turno cerrado: Regresion QA de identidades conocidas del legacy 7.72

Turno estrecho de regresion. **No** cambia `PARITY-MONSTER-REACQUISITION-001`
ni ningun artefacto de paridad, y **no** crea una tercera observacion
`LIVE_ORACLE`. Detalle en
`docs/qa/KNOWN_CREATURE_IDENTITY_LIVE_REGRESSION.md`.

- **Solicitud aceptada de `protocolo-red`:** registrado el caso
  `identidad_conocida_protocolo` en `cliente3d/pruebas/matriz_qa_local.gd`
  (ruta de este carril), apuntando a
  `red/identidad_conocida_self_test.gd`. El self-test en si **no se toco**.
- **Self-test determinista: 20/20 OK, codigo 0.** Correccion de un dato mal
  reportado en el cierre de `protocolo-red`: alli se dijo "21/21". El conteo
  correcto es **20**; el 21 salia de contar tambien la linea de definicion
  `func _comprobar(...)`. La prueba no cambio, solo la cifra.
- **Matriz QA local completa: 18/18 OK.** Los 17 casos previos siguen verdes
  mas el nuevo; no se removio ni salteo ninguno.
- **Regresion viva nueva:**
  `cliente3d/pruebas/prueba_known_creature_identity_live.gd` + `.tscn`
  (QA-owned). No es oracle de paridad: no emite `OBSERVATION_JSON`, no usa
  `wrap_live_observation.py` y no crea artefactos de paridad. Solo dos
  sesiones (god + personaje), y como mutacion unicamente `/gotopos` y `/c`.
- **Resultado vivo: 11/11 OK, codigo 0.** El personaje aprendio al god con
  la forma completa (`0x61` con nombre), luego un `/c` forzo refrescos de
  mapa completo (**5 mapas contra 2 al aprender**, es decir 3 refrescos que
  vacian el mundo visible), y tras eso el **mismo runtime id** volvio con el
  **nombre exacto**, no vacio. El propio personaje tampoco perdio su nombre.
- **La transicion fue realmente de forma conocida**, no una llegada `0x61`
  de primera vez: se verifico que el conjunto conocido nunca se acerco al
  tope de 150 del servidor y que nunca encogio, asi que no pudo haber
  desalojo y el reenvio tuvo que ser `0x62`.
- `identidad_conocida_ausente`: **0 avisos**. Identidades verificadas con
  nombre vacio: **0**.
- **0 muertes de jugador, 0 monstruos invocados, 0 acciones de combate, 0
  usos de `/killall`.**
- La prueba **solo lee** `identidades_conocidas`; verificado por `grep` que
  no hay ninguna escritura ni `clear`/`erase` desde QA. No se fabrico un
  PASS tocando internals del parser.
- **Artefactos de Phase 2C.2 sin tocar**, verificado por hash: el adaptador
  de captura conserva su hash certificado `caa969e6...` y su workaround
  `_ids_cave_rat` (ahora defensa en profundidad); fixtures, cases,
  observaciones y reportes de paridad byte-identicos.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1` y `worklog/protocolo-red/` no se
  toco (ni contrato ni estado ni implementacion).
- El desalineamiento de mapa `0x64` sigue abierto y separado: aca `0x64` se
  usa solo como disparador legitimo del refresco de mundo visible.

## Conteos (regresion, sin cambio de inventarios)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 5 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 2 (sin cambio) |
| `LEGACY_KNOWN_CREATURE_IDENTITY` | — | **PASS** (determinista 20/20, matriz 18/18, viva 11/11) |

**Le toca:** abrir un **tercer dominio de paridad**. No volver a modificar la
reacquisicion de monstruo salvo que aparezca una regresion nueva.

## Turno cerrado: Phase 2C.2 — Certificacion en vivo de reacquisicion (EXITO)

`PARITY-MONSTER-REACQUISITION-001` quedo **CERTIFICADO EN VIVO**: observacion
`LIVE_ORACLE` fresca contra TVP 7.72 real y replay `PASS 12/12` con el
comparador generico sin modificar. Detalle completo en
`docs/qa/PARITY_PHASE2C2_MONSTER_REACQUISITION_LIVE.md`.

- **Terreno usado:** `A=(32008,32400,7)` (invocacion/medicion) y
  `B=(32008,32339,7)` (hueco de visibilidad). **El par preseleccionado por
  Phase 2C.1 (`A=(31980,31995,7)`/`B=(31932,32040,7)`) fallo**: no es
  colocable, `/c` (`getClosestFreePosition`) no encuentra casilla libre ahi.
  Esas casillas estaban libres de monstruos justamente porque son terreno
  inhabitable — la correlacion perversa entre "aislado" e "inhabitable" que
  la propia Phase 2C.1 habia anticipado como limitacion. El par nuevo tiene
  aislamiento 73 y 43 (requerido 21), no es PZ ni casa, paso la sonda pasiva
  solo-god de 60 s por punto sin criaturas naturales, y ademas se comprobo
  en vivo que si acepta al personaje.
- **Correccion de criterio:** exigir 30 de separacion en ambos ejes era una
  heuristica propia, mas estricta que la regla real. Segun
  `protocolgame.cpp:766-767` basta que un eje quede fuera de
  `dx ∈ [-8,+9]` / `dy ∈ [-6,+7]`. El par usado tiene `dy=61` (50 de margen
  sobre el rango de espectadores). La desaparicion real se sigue exigiendo en
  runtime; la separacion nunca se usa como prueba por si sola.
- **Defecto real encontrado y corregido en el adaptador:**
  `cliente3d/red/estado_mundo.gd` puede reconstruir una criatura ya conocida
  con `nombre` vacio; se observo en vivo con el objetivo, el god y el propio
  personaje los tres sin nombre. La desambiguacion dependia de ese nombre.
  Ahora la identidad de cave rat se memoriza **por runtime id** en cuanto el
  servidor si lo entrega. **Ninguna asercion se debilito:** objetivo por id
  nuevo y unico, atacante por mensaje autoritativo que lo nombre,
  reaparicion exigiendo el MISMO id (mismo nombre con id distinto sigue
  siendo `FAIL`), y ambiguedad rechazada si hay mas de un cave rat conocido
  vivo. Ese parser pertenece a `protocolo-red` y **no se modifico**; queda
  como solicitud a ese carril.
- **Intentos en vivo: 6** (la tarea fijaba maximo 3; el exceso se consulto
  con el usuario tras el tercero y fue autorizado, y se reporta de forma
  transparente). 1 fallo por terreno no colocable, 2-4 por el defecto de
  nombre, 5 confirmo la reacquisicion pero sin dano posterior porque la
  armadura del sorcerer nivel 100 absorbia los golpes, 6 exitoso con el
  personaje de armadura baja que usaba la evidencia historica.
- **Cadena completa observada:** primer golpe de cave rat con identidad sin
  ambiguedad; desaparicion real del objetivo del diccionario de criaturas;
  misma sesion, vivo, mismo piso; reaparicion del **mismo** runtime id;
  segundo golpe de cave rat posterior a esa reaparicion. Exactamente una
  linea `OBSERVATION_JSON`.
- **Hashes congelados antes de la corrida certificada y recalculados
  despues: identicos los seis.** El codigo commiteado es exactamente el que
  produjo la observacion; la expectativa nunca se modifico tras ver el
  resultado.
- **Muertes de jugador: 0** en los seis intentos. **Monstruos colaterales
  matados: 0**; `/killall` no se emitio en ninguna corrida. Cada rata
  invocada se retiro por ataque dirigido y el personaje volvio vivo a su
  templo.
- Fixture, `QACaseV2` (12 aserciones), observacion `RECORDED_EVIDENCE`,
  `replay.py`, `wrap_live_observation.py`, el qualifier de terreno, su
  reporte y la sonda de terreno quedaron **sin modificar**. El `.tscn` del
  adaptador tampoco se toco.
- Desalineamiento de mapa `0x64` no investigado ni tocado.

## Conteos (Phase 2C.2)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 5 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | **2** (antes 1) |
| `PARITY-MONSTER-REACQUISITION-001` | — | **LIVE CERTIFIED, `PASS 12/12`** |
| `REACQUISITION_TEST_TERRAIN` | — | `QUALIFIED` (`A=(32008,32400,7)`, `B=(32008,32339,7)`) |
| Certificaciones frescas de oracle en este turno | — | 1 |
| Muertes de jugador en este turno | — | 0 |

**Le toca:** con dos dominios de comportamiento distintos ya certificados en
vivo (corpse de monstruo y reacquisicion de objetivo) y las herramientas
genericas probadas contra ambos sin cambios, Phase 2 puede seguir con un
tercer dominio de paridad, o abrir como linea propia la deuda de
`protocolo-red` (perdida de nombre de criatura conocida) y la investigacion
del desalineamiento de mapa `0x64`.

## Turno cerrado: Phase 2C.1 — Calificacion de terreno aislado para reacquisicion

Turno de calificacion de terreno. **No certifica**
`PARITY-MONSTER-REACQUISITION-001`; solo habilita el intento de Phase 2C.2.
Detalle completo en `docs/qa/PARITY_PHASE2C1_TERRAIN_QUALIFICATION.md`.

- **Herramienta nueva** `qa/parity/tools/qualify_reacquisition_terrain.py`
  (QA-owned, solo libreria estandar). Reutiliza **en modo lectura**
  `herramientas/leer_otbm.py` (su `Stream`, escapes y constantes); el parser
  no se reescribio. Se agrego un filtro de bounds a nivel de area porque
  `recorrer` decodifica los atributos de todos los items de un mundo
  65000x65000 y no termina en tiempo practico.
- **Reglas derivadas del codigo fuente, no adivinadas:** visibilidad de
  cliente asimetrica `dx ∈ [-8,+9]` / `dy ∈ [-6,+7]`
  (`map.h:181-182` + `protocolgame.cpp:766-767`); rango de espectadores del
  servidor 11 (`map.h:179-180` + `map.cpp:434-437`), que es el mas ancho y
  por eso el usado para la matematica de seguridad; limite de movimiento de
  monstruo = caja de Chebyshev del radio de spawn (`spawn.cpp:222-231`),
  efectivamente aplicado porque `allowMonsterOverspawn = true`
  (`monster.cpp:1727-1735` + `config.lua`). **No se reutilizo el "39 SQM"**
  del documento historico.
- **Buffer de seguridad derivado:** `clearance > radio_spawn + 11 + 10`, es
  decir 21 por encima del radio. Radio de spawn maximo en los datos: 50.
  Separacion exigida entre los dos puntos: 30 en **ambos** ejes.
- **Fuentes parseadas sin huecos:** `map.otbm` (94.199 casillas en ventana),
  `map-spawn.xml` (9.950 entradas), `spawns.dat` (9.613 spawns + 337 NPCs,
  con radios distintos y a veces mayores que el XML, por eso se usa la
  union), `map-house.xml`, y los 38 archivos de `raids/` (349 `areaspawn`).
  **`source_problems` = 0**; se verifico que los raids solo usan
  `raid/raids/announce/areaspawn/monster/loot`, sin `singlespawn` ni otro
  elemento de spawn ignorado.
- **Resultado estatico:** 7.076 casillas calificadas, 58 pares evaluados,
  top 3 reportados. Reporte determinista
  `qa/parity/reports/reacquisition_terrain_candidates.json`, byte-identico
  entre dos corridas.
- **Sonda en vivo solo god** (`cliente3d/pruebas/prueba_parity_terrain_probe.gd`
  + `.tscn`, nuevos): solo `/gotopos` y observacion pasiva; sin `/m`, sin
  ataque, sin `/killall`, sin `/c`, sin personaje normal. Ventana de 60 s por
  punto. El par #1 paso al primer intento: el god llego a ambas casillas y
  **no aparecio ninguna criatura natural** en ninguna de las dos.
- **Par seleccionado:** `A=(31980,31995,7)` / `B=(31932,32040,7)`.
  `REACQUISITION_TEST_TERRAIN: QUALIFIED`.
- **0 sesiones del personaje normal, 0 muertes de jugador, 0 monstruos
  invocados, 0 monstruos matados, 0 usos de `/killall`.**
- Las coordenadas calificadas **no** entraron en ningun fixture, case,
  expectation ni observacion: son detalle de implementacion de captura y
  viven solo en el documento operativo. El adaptador de reacquisicion
  **no se modifico** (eso es Phase 2C.2).
- Desalineamiento de mapa `0x64` no investigado ni tocado.

## Conteos (Phase 2C.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 5 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 1 (sin cambio) |
| Certificacion en vivo de reacquisicion | — | sigue **BLOCKED** hasta Phase 2C.2 |
| `REACQUISITION_TEST_TERRAIN` | — | **QUALIFIED** (`A=(31980,31995,7)`, `B=(31932,32040,7)`) |

**Le toca:** Phase 2C.2 — adaptar el adaptador de captura de reacquisicion al
par calificado y ejecutar una unica certificacion en vivo congelada contra
`PARITY-MONSTER-REACQUISITION-001`.

## Turno cerrado: Phase 2C.0.1 — Higiene de normalizacion del fixture de reacquisicion

Turno de correccion de datos/documentacion. **Sin ejecucion en vivo de TVP,
sin Docker, sin observacion `LIVE_ORACLE` nueva.** Detalle en el addendum de
`docs/qa/PARITY_PHASE2C_MONSTER_REACQUISITION.md`.

- Se limpio la prosa de
  `qa/parity/fixtures/tvp772/monster_reacquisition/parity-monster-reacquisition-001.json`:
  los valores concretos y volatiles de la corrida historica (runtime id
  concreto, secuencia exacta de HP, distancia exacta de 39 SQM) ya no se
  duplican en el fixture reutilizable. Estaban declarados como excluidos en
  `excluded_nondeterministic_fields` pero seguian apareciendo en
  `input_action`, en una `normalization_rules` y en `determinism_notes`.
  Ahora el fixture expresa relaciones: id que no existia antes y que se
  observa identico tras el regreso, vida que baja tras cada ataque
  autoritativo que nombra al cave rat, y alejamiento definido de forma
  **conductual** (que el objetivo deje de ser visible) en vez de una
  distancia fija como invariante.
- Los valores historicos exactos siguen accesibles via `source_evidence` ->
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`, que **no se modifico**.
- Sin cambio de semantica: `fixture_id`, `schema`/`version` (`2.0.0`),
  `oracle`/`oracle_version`, `classification` (`MATCH_EXPECTED`) y
  `excluded_nondeterministic_fields` identicos. La regla observable no se
  debilito ni se reforzo.
- **Las 12 aserciones no cambiaron.** `QACaseV2` byte-identico
  (`sha256 88b81ed0...`). Observacion `RECORDED_EVIDENCE` byte-identica
  (`sha256 df3b45e3...`), ya estaba correctamente normalizada.
- Replay contra evidencia grabada: **`PASS 12/12`**, dos corridas,
  byte-identico entre si y byte-identico al reporte ya commiteado en Phase
  2C (`sha256 e9f70a1b...`), confirmando que el cambio de prosa no altero
  semantica de replay. `qa/parity/tools/replay.py` y
  `wrap_live_observation.py` no se tocaron; el adaptador de captura tampoco.
- **Certificacion en vivo de reacquisicion: sigue `BLOCKED`**, sin cambios
  respecto a Phase 2C.

## Conteos (Phase 2C.0.1, sin cambio)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 |
| Fixtures `LEGACY_PARITY` | — | 5 |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 |
| Observaciones `RECORDED_EVIDENCE` | — | 4 |
| Observaciones `LIVE_ORACLE` canonicas | — | 1 (monster-corpse; reacquisicion `BLOCKED`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 0 |

**Le toca:** Phase 2C.1 — calificar un terreno de prueba TVP aislado para
reacquisicion de monstruo.

## Turno cerrado: Phase 2C — Slice de paridad de reacquisicion (PARCIAL, live BLOCKED)

Detalle completo en `docs/qa/PARITY_PHASE2C_MONSTER_REACQUISITION.md`.
Trabajo local completo y verde; **certificacion en vivo BLOQUEADA** por una
restriccion real del entorno. No se fabrico ninguna observacion.

- **Materializado** `PARITY-MONSTER-REACQUISITION-001`: fixture
  (`tvp3d.qa.parity_fixture/2.0.0`, `MATCH_EXPECTED`), `QACaseV2`
  (`case_id == fixture_id`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`) con
  `ParityExpectationV1` de **12 aserciones**, y observacion
  `RECORDED_EVIDENCE` derivada solo de hechos ya probados por
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`.
- **Replay contra evidencia grabada: `PASS 12/12`**, codigo 0, reporte
  byte-identico en dos corridas. `qa/parity/tools/replay.py` **no se
  modifico**: el comparador generico acepto un dominio de comportamiento
  distinto (reacquisicion, no corpse) sin cambios, confirmando que
  generaliza.
- **Limite semantico respetado:** el fixture afirma solo lo observable
  (mismo runtime id reaparece + segundo ataque autoritativo nombrando al
  cave rat). NO afirma `attacked_creature_pointer_preserved` ni ningun otro
  estado interno de TFS/TVP.
- **Adaptador de captura nuevo:**
  `cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd`+`.tscn`.
  `prueba_reacquisicion_monstruo.gd` no se toco. Credenciales solo por
  entorno (`TVP772_ACCOUNT`/`PASSWORD`/`GOD_CHARACTER`/`PLAYER_CHARACTER`),
  sin defaults ni literales; fallo de personaje no enumera la cuenta. Sin
  `/killall` amplio inicial. `cliente3d/red/` no se toco.
- **Certificacion en vivo: `BLOCKED`.** 13 ejecuciones, 0 observaciones
  emitidas. Causa: conflicto real entre "prohibido `/killall` amplio
  inicial" y "abortar si otro cave rat hace ambigua la identidad del
  atacante", sobre un terreno que es zona de spawn de cave rats de Thais.
  Desglose: 8 abortos por ambiguedad, 3 por vida cero antes de medir, 2 por
  cave rat preexistente. Se probaron las dos casillas ya certificadas
  intercambiando roles; ambas tienen fauna. Ningun ajuste de expectativa,
  ninguna proteccion relajada, ninguna evidencia grabada reetiquetada como
  en vivo.
- **Muertes de jugador en este turno: NO fueron cero.** `Valentino` murio
  varias veces (`You are dead`, revivido por el servidor en su templo). Las
  primeras muertes vinieron de un defecto propio de la primera version del
  adaptador (no devolvia al personaje a lugar seguro al abortar, quedando
  expuesto entre corridas); ese defecto se corrigio a mitad del turno y se
  verifico funcionando. Las restantes fueron densidad de fauna contra un
  personaje nivel 1. Se informo al usuario en cada caso y decidio continuar.
- **Estado final del entorno verificado:** `Valentino` vivo con 134 HP en el
  templo `(32369,32241,7)`; 0 cave rats vivos visibles; cada monstruo
  invocado por este turno fue retirado por ataque dirigido puntual (nunca
  por area). No se reseteo base de datos ni volumenes.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1`. Los cuatro fixtures de Phase 2A,
  los cuatro `QACaseV2` de Phase 2B.1, las tres observaciones
  `RECORDED_EVIDENCE` previas y la observacion `LIVE_ORACLE` de
  monster-corpse quedan byte-identicas.
- Desalineamiento de mapa `0x64` no investigado ni tocado; no fue causa de
  ningun aborto.

## Conteos (Phase 2C)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **5** (antes 4) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **5** (antes 4) |
| Observaciones `RECORDED_EVIDENCE` | — | **4** (antes 3) |
| Observaciones `LIVE_ORACLE` canonicas | — | 1 (sin cambio; reacquisicion quedo `BLOCKED`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 13 intentos / 0 certificaciones |

Estos conteos no se combinan: los cinco fixtures de paridad NO cuentan para
las 198 obligaciones Architecture V2.

**Le toca:** para cerrar la certificacion en vivo de reacquisicion hace falta
resolver la tension terreno/ambiguedad de forma legitima — (a) certificar una
tercera casilla fuera de zona de spawn de cave rats, (b) usar un personaje de
prueba con vida suficiente para sostener la ventana de medicion, o (c)
publicar contractualmente un aislamiento de campo acotado y seguro que no
dependa de matar fauna preexistente.

## Turno cerrado: Phase 2B.2.1 — Endurecimiento y recertificacion de la primera captura viva

Detalle completo en `docs/qa/PARITY_PHASE2B21_CAPTURE_HARDENING.md`. El
resultado de Phase 2B.2 (mas abajo) sigue siendo historico y genuino; este
turno no lo reescribe, lo endurece y lo recertifica contra el codigo final
exacto que se commitea.

- **Motivo:** Phase 2B.2 aplico una correccion de higiene de codigo al
  adaptador de captura **despues** de su corrida exitosa, sin recapturar.
  Revision encontro ademas tres defectos de robustez: el nombre de corpse
  observado se forzaba a minusculas antes de serializarse (podia ocultar
  una diferencia real de capitalizacion de TVP); el fallback `/killall` no
  verificaba su area real de efecto antes de emitirse; y el log de fallo de
  personaje god enumeraba innecesariamente los demas nombres de personaje
  de la cuenta.
- **Fix 1:** `_emitir_observacion()` ya no aplica `.to_lower()` al nombre de
  corpse observado; el hecho versionado preserva el string exacto del
  servidor. La comparacion en minusculas sigue existiendo solo como logica
  de descubrimiento interno.
- **Fix 2:** se leyo (sin modificar)
  `servidor/data/scripts/talkactions/god/kill_creatures.lua` y
  `servidor/data/scripts/spells/areas.lua`: `/killall` ejecuta un Combat con
  `AREA_SQUARE1X1` (matriz 3x3, radio Chebyshev 1) centrado en la posicion
  propia del god, matando a todo monstruo alcanzado. Se agrego
  `_area_de_killall_segura(centro)`: rechaza emitir `/killall` si existe
  otra criatura viva (distinta de la rata de la corrida) dentro de ese
  cuadrado. En la corrida de recertificacion, `/killall` no llego a
  emitirse: la rata murio por el ataque directo antes del umbral de 6s.
- **Fix 3:** el fallo de `TVP772_GOD_CHARACTER` no encontrado ya no imprime
  la lista de personajes de la cuenta; mensaje generico sin metadata de
  cuenta.
- **Fix 4:** `wrap_live_observation.py` ahora escanea el log completo,
  exige exactamente una linea `OBSERVATION_JSON` (rechaza 0 y 2+ como
  ambiguo, nunca elige la primera silenciosamente), exige que el payload
  etiquetado sea un objeto JSON, valida cada `--source-evidence` con las
  mismas reglas repo-relativas de `OracleObservationV1`, y escribe el
  archivo de salida de forma atomica (temporal + `os.replace`). Auto-prueba
  nueva (`--selftest`, stdlib-only): 14/14 `OK`, codigo 0.
- **`qa/parity/tools/replay.py` sin modificar:** no se detecto ningun
  defecto concreto; la recertificacion usa el mismo comparador generico ya
  commiteado en Phase 2B.1.
- **Congelamiento y hashes:** SHA-256 de
  `cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` y
  `qa/parity/tools/wrap_live_observation.py` calculados antes de la corrida
  en vivo y recalculados despues; **identicos en ambos casos**
  (`a36a2ac4...f999b3b` y `920783f0...5769b1` respectivamente). El codigo
  commiteado es exactamente el codigo que corrio en vivo.
- **Recertificacion en vivo:** una ejecucion exitosa (codigo 0) contra el
  stack de TVP que seguia arriba de Phase 2B.2 (decision previa del usuario
  de no apagarlo). Mutacion: una rata de prueba invocada, matada por el
  ataque directo del god (no por `/killall`, que nunca se emitio en esta
  corrida), su corpse creado y abierto como contenedor real. Cero
  colateral: `/killall` nunca se envio, asi que su area de efecto nunca se
  activo. Cero jugadores murieron; no se ejecuto duelo ni reentrada.
- **Observacion regenerada** (reemplaza, no acumula, la de Phase 2B.2 para
  el mismo `fixture_id`):
  `qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`,
  `source_evidence` apuntando a `docs/qa/PARITY_PHASE2B21_CAPTURE_HARDENING.md`.
  Nombre de corpse observado crudo: `"dead rat"` (exacto, sin normalizar).
- **Replay:** mismo comparador generico, dos corridas contra la misma
  observacion fresca: `PASS`, `assertions_total=4`, `assertions_passed=4`,
  codigo `0`, reporte byte-identico entre corridas.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1`, sin cambios. Los cuatro
  `ParityFixtureV2` de Phase 2A y los cuatro `QACaseV2` de replay de Phase
  2B.1 quedan byte-identicos.
- El desalineamiento de mapa `0x64` no se investigo ni se toco; sigue
  `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`.

## Conteos (Phase 2B.2.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A) | 4 | 4 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (Phase 2B.1) | 4 | 4 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | 1 (`PARITY-MONSTER-CORPSE-001`) | 1 (recertificada, `PASS`; reemplaza la de Phase 2B.2 para el mismo fixture, no se suma) |
| Ejecuciones frescas de oracle TVP en este turno | — | 1 |

**Le toca:** investigar el desalineamiento de mapa `0x64` como su propia
linea de evidencia, o evaluar si otro fixture `SINGLE_OBSERVATION` amerita
su propio adaptador narrow siguiendo el mismo patron de congelar-hashear-
capturar-rehashear-confirmar.

## Turno cerrado: Phase 2B.2 — Primera captura fresca de oracle TVP en vivo (EXITO)

Detalle completo en `docs/qa/PARITY_PHASE2B2_LIVE_MONSTER_CORPSE.md`. Se
completo el primer ciclo real de extremo a extremo (TVP 7.72 real ->
adquisicion de corpse de monstruo -> `OracleObservationV1` `LIVE_ORACLE` ->
`qa/parity/tools/replay.py` sin modificar -> `QAReportV2` `PASS` 4/4) para
`PARITY-MONSTER-CORPSE-001`. Cero jugadores murieron; ningun flujo de
muerte/reentrada se ejecuto.

- Motor de Docker: alcanzable al abrir el turno. El stack de TVP 7.72 no
  estaba arriba; **este turno si lo levanto**
  (`cd servidor && docker compose up --build -d`, sin modificar
  `docker-compose.override.yml` ni resetear datos). Incidente intermedio: el
  puente CLI-motor de Docker Desktop se corto justo despues del build (falla
  conocida de este entorno); el usuario reinicio Docker Desktop, lo que
  detuvo los contenedores recien creados, y se los volvio a levantar con
  `docker compose up -d` (sin `--build`, imagen ya existente). Verificado
  `>> TVP3D Server Online!` en el log y los puertos `7171`/`7172` abiertos
  antes de capturar. Por decision explicita del usuario, el stack quedo
  corriendo al cerrar este turno (no se ejecuto `docker compose stop`).
- Credenciales: las tres variables (`TVP772_ACCOUNT`, `TVP772_PASSWORD`,
  `TVP772_GOD_CHARACTER`) estaban ausentes al abrir el turno; siguiendo la
  instruccion literal, se detuvo el trabajo de implementacion y se le pidio
  al usuario que las proveyera. El usuario opto por darlas directamente para
  esta ejecucion puntual en vez de configurarlas como variables persistentes
  del sistema. Se usaron exclusivamente como `export` dentro de una unica
  invocacion de shell que lanzo Godot, con `unset` inmediato despues; nunca
  se escribieron a un archivo, se imprimieron en un comando, ni entraron a
  un commit/evento/documento. El primer intento (cuenta nueva) fue
  rechazado por el propio servidor ("Account number or password is not
  correct"); el usuario paso entonces a la cuenta de prueba ya documentada
  como valor por defecto en `ARRANCAR SERVIDOR.bat` (no repetida aqui). El
  segundo intento fallo por
  una diferencia de mayusculas en el nombre del personaje god; el script de
  captura ya imprime, ante ese fallo especifico, la lista de nombres de
  personajes disponibles (dato no sensible), lo que permitio identificar
  `GOD VALENTINO` (todo en mayusculas) sin inspeccionar ningun otro archivo.
  El tercer intento tuvo exito.
- **Se creo** `cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` +
  `.tscn` (nuevo, QA-owned; no reemplaza ni reescribe
  `prueba_muerte_loot_vivo.gd`). Reutiliza en modo solo lectura
  `res://red/conexion772.gd` y `res://red/estado_mundo.gd`, sin modificarlos.
  Lee credenciales exclusivamente via `OS.get_environment(...)`; el archivo
  fuente no contiene ningun literal de cuenta/clave/personaje.
- **Mutacion exacta ejecutada:** una rata de prueba invocada por el god,
  matada, su corpse creado y abierto como contenedor real. Nada mas: ningun
  jugador murio, no se toco al personaje normal (`Valentino`). El corpse
  queda para descomponerse de forma normal; no se ejecuto limpieza especial
  ni reset de base de datos.
- **Se creo** la observacion `LIVE_ORACLE`:
  `qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`,
  construida por el nuevo `qa/parity/tools/wrap_live_observation.py`
  (QA-owned, stdlib-only) a partir de la unica linea `OBSERVATION_JSON: ...`
  que emite el script de captura. Payload exacto:
  `{"monster_kind": "rat", "corpse": {"present": true, "name": "dead rat",
  "openable_container": true}}`. Sin ids de runtime, coordenadas, loot,
  credenciales, timestamps ni paths absolutos.
- Replay con el mismo comparador generico de Phase 2B.1 (sin modificar),
  ejecutado dos veces contra la misma observacion:
  `PASS PARITY-MONSTER-CORPSE-001`, `assertions_total=4`,
  `assertions_passed=4`, codigo de salida `0`, reporte byte-identico entre
  corridas (`qa/parity/reports/replay_live_monster_corpse_report.json`).
  El comportamiento fresco de TVP coincidio con la expectativa ya publicada
  sin ajustar nada para forzarlo.
- Correccion de higiene de codigo sobre el propio archivo nuevo de este
  turno: el script re-enviaba "abrir contenedor" en cada frame mientras
  esperaba respuesta; se agrego la transicion de fase faltante. No implico
  una recaptura contra TVP.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1`, sin cambios. Los cuatro
  `ParityFixtureV2` de Phase 2A y los cuatro `QACaseV2` de replay de Phase
  2B.1 quedan byte-identicos.
- El desalineamiento de mapa `0x64` no se investigo ni se toco; sigue
  `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`.

## Conteos (Phase 2B.2)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A) | 4 | 4 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (Phase 2B.1) | 4 | 4 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 (sin cambio) |
| Observaciones `LIVE_ORACLE` frescas | 1 (planeada) | **1** (`PARITY-MONSTER-CORPSE-001`, `PASS`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 1 |

Ninguna de estas cuentas se combina con otra: replayar paridad legacy no
materializa ninguna obligacion de contrato Architecture V2.

**Le toca:** (a) si algun turno futuro decide certificar
`PARITY-DEATH-CORPSE-001`/`PARITY-DEATH-REENTRY-001` en vivo, eso implicaria
un flujo de muerte/reentrada real, fuera del alcance de este turno; (b)
investigar el desalineamiento de mapa `0x64` como su propia linea de
evidencia, ahora con un camino de captura en vivo mas simple (solo god, sin
duelo) disponible como base.

## Turno cerrado: Phase 2B.1 — Captura controlada de oracle TVP y replay generico

Turno de implementacion (no contract-only). `worklog/qa/CONTRATO.md` **no se
modifico**: se implemento exactamente contra `qa 2.1.1` publicado en el turno
anterior. Detalle completo en
`docs/qa/PARITY_PHASE2B1_CAPTURE_REPLAY.md`.

- Materializados cuatro `QACaseV2` `LEGACY_PARITY` de replay en
  `qa/parity/cases/tvp772/death_corpse_loot/`, uno por cada `ParityFixtureV2`
  de Phase 2A, con `case_id == fixture_id` (seccion 16D.1) y un
  `ParityExpectationV1` embebido en `expected`: tres `SINGLE_OBSERVATION`
  (`PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001`,
  `PARITY-MONSTER-CORPSE-001`) y uno `EVIDENCE_ONLY` con `assertions: []`
  (`PARITY-LOOT-RANDOMNESS-001`). Los cuatro fixtures de Phase 2A quedan
  byte-identicos; no se tocaron.
- Materializadas tres `OracleObservationV1` `RECORDED_EVIDENCE` en
  `qa/parity/observations/tvp772/death_corpse_loot/recorded/`, usando
  solo hechos ya publicados en `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md` (sin
  timestamps inventados, sin ids de runtime, sin credenciales).
- Implementado `qa/parity/tools/replay.py` (Python 3, solo libreria
  estandar): carga caso/fixture/expectativa/observacion, resuelve JSON
  Pointer RFC 6901 (decodificando `~1` antes que `~0`, orden correcto segun
  RFC 6901 seccion 4), evalua el registro cerrado de nueve operadores
  (`EQ, NE, EXISTS, NOT_EXISTS, GT, GTE, LT, LTE, ONE_OF`) sin `eval` y sin
  coercion de tipos (incluye rechazo explicito de `bool` como operando
  numerico), y emite `tvp3d.qa.report/2.0.0`
  (`suite_id=PARITY_TVP_772`, `profile=LEGACY_TVP_772`). Confirmado por
  `grep` que el archivo no contiene ningun valor especifico de fixture.
- Auto-prueba en memoria (`--selftest`): 46/46 comprobaciones `OK`, codigo de
  salida 0. Nunca escribe un archivo malformado versionado.
- Replay contra las tres observaciones grabadas:
  `PARITY-DEATH-CORPSE-001 PASS`, `PARITY-DEATH-REENTRY-001 PASS`,
  `PARITY-MONSTER-CORPSE-001 PASS`, `PARITY-LOOT-RANDOMNESS-001 NOT_RUN`;
  codigo de salida `0`. Ejecutado dos veces: reporte
  `qa/parity/reports/replay_recorded_death_corpse_loot_report.json`
  byte-identico entre corridas (confirmado con `diff`).
- Prueba de mutacion deliberada: se corrompio temporalmente
  `parity-monster-corpse-001.observation.json`, el replay reporto `FAIL`
  con codigo `1`, y el archivo se restauro byte-a-byte antes de cualquier
  commit (hash `sha256` identico antes/despues).
- Captura en vivo de `PARITY-MONSTER-CORPSE-001`: **no ejecutada, `BLOCKED`**.
  Dos prerequisitos ausentes de forma independiente: el motor de Docker
  esta inalcanzable (`docker ps` fallo de inmediato, motor apagado, no el
  problema de puente WSL con motor vivo de turnos anteriores) y las
  variables de entorno `TVP772_ACCOUNT`/`TVP772_PASSWORD`/
  `TVP772_GOD_CHARACTER` no estan definidas. No se fabrico ninguna
  observacion `LIVE_ORACLE`, no se reetiqueto la observacion grabada como
  si fuera en vivo, no se reporto `PASS`, y no se creo
  `qa/parity/reports/replay_live_monster_corpse_report.json` (no hay
  observacion real que replayar). `cliente3d/red/`, `estado_mundo.gd` y
  `conexion772.gd` no se tocaron; `prueba_muerte_loot_vivo.gd` tampoco se
  modifico.
- Ningun jugador murio en este turno (cero ejecuciones de la corrida
  completa de duelo); no se ejecuto TVP/Docker en absoluto.
- Ninguna credencial se escribio, imprimio ni copio a ningun archivo nuevo.

## Conteos (Phase 2B.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A, sin cambio) | 4 | 4 |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (este turno) | 4 | 4 (3 `SINGLE_OBSERVATION` / 1 `EVIDENCE_ONLY`) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 |
| Observaciones `LIVE_ORACLE` frescas | 1 (planeada) | 0 (`BLOCKED`) |

Estos conteos no se combinan entre si: replayar paridad legacy no
materializa ninguna obligacion de contrato Architecture V2.

**Le toca:** un turno futuro con Docker y credenciales `TVP772_*`
disponibles puede ejecutar la captura en vivo documentada en
`docs/qa/PARITY_PHASE2B1_CAPTURE_REPLAY.md` y, por separado, investigar el
caveat de desalineamiento de mapa `0x64`.

## Turno cerrado: QA 2.1.1 — Erratum de conteo de operadores de replay

- `qa 2.1.0` publico correctamente el registro normativo de nueve
  operadores en la seccion 16C (`EQ, NE, EXISTS, NOT_EXISTS, GT, GTE, LT,
  LTE, ONE_OF`). Una frase descriptiva (la fila `2.1.0` de "Historial de
  contrato de qa") decia "8 operadores" por error de conteo; el evento de
  publicacion de aquel turno en `worklog/EVENTS.jsonl` repitio el mismo
  error descriptivo.
- `qa 2.1.1` corrige unicamente esa frase descriptiva a "9 operadores" y
  agrega su propia fila al historial. **No cambio ningun operador, schema
  ni semantica de replay.** El registro de la seccion 16C es byte-a-byte el
  mismo que en `2.1.0`.
- La linea historica de `worklog/EVENTS.jsonl` que dice "8 operadores
  deterministicos" NO se reescribio: es un evento append-only y se preserva
  tal cual, con una nueva linea de aclaracion agregada a continuacion.
- Sin cambio de conteos: obligaciones Architecture V2 siguen en 198
  especificadas / 0 materializadas; corpus piloto `LEGACY_PARITY` sigue en
  4 fixtures materializados. Ninguna ejecucion fresca de TVP/Docker en este
  turno; ningun archivo bajo `qa/` ni `docs/qa/` se toco.
- **Phase 2B.1 sigue siendo la siguiente tarea de implementacion** (captura/
  replay controlada de TVP contra el boundary publicado en `2.1.0`), no
  ejecutada en este turno.

## Turno cerrado: Phase 2B.0 — Boundary de replay de oracle legacy

Turno contract-only puro: no se creo ni ejecuto ningun archivo bajo `qa/` ni
`docs/qa/`, no se toco Docker/TVP, y los cuatro fixtures/harness de Phase 2A
quedan exactamente iguales.

- Publicado `qa 2.1.0` (extension minor): agrega `OracleObservationV1`
  (`tvp3d.qa.oracle_observation/1.0.0`, nueva identidad de schema) y
  `ParityExpectationV1` (`tvp3d.qa.parity_expectation/1.0.0`, nueva
  identidad de schema), secciones 16A-16F.
- `capture_origin` cerrado `LIVE_ORACLE|RECORDED_EVIDENCE`; ninguno implica
  `PASS`. Frontera explicita captura cruda (nunca versionada automaticamente)
  vs observacion normalizada (segura, versionable tras redaccion de
  secretos/paths/diagnosticos volatiles).
- `mode` cerrado `SINGLE_OBSERVATION|EVIDENCE_ONLY`. Registro de 8
  operadores deterministicos (`EQ,NE,EXISTS,NOT_EXISTS,GT,GTE,LT,LTE,ONE_OF`)
  sobre JSON Pointer RFC 6901; sin `eval`, sin expresiones arbitrarias. El
  comparador generico no puede contener ningun valor especifico de fixture.
- Reuso exacto de `tvp3d.qa.case/2.0.0` y `tvp3d.qa.report/2.0.0` para
  replay, sin publicar un tercer schema de caso ni un segundo de reporte.
  Congelada la regla `QACaseV2.case_id == ParityFixtureV2.fixture_id`;
  confirmado sin contradiccion contra la grammar de `case_id` ya publicada
  (el prefijo `PARITY` ya estaba reservado en la seccion 3.1).
- `tvp3d.qa.error` avanza `2.0.0 -> 2.1.0` (mismo patron que
  `modelo-comun 2.1.0` para `tvp3d.domain_error`) solo para agregar
  `QA_OBSERVATION_INVALID`; sus campos/tipos/rangos no cambian.
- Documentado el mapeo (sin modificar los archivos) de los cuatro fixtures
  de Phase 2A: `PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001` y
  `PARITY-MONSTER-CORPSE-001` quedan replayables como `SINGLE_OBSERVATION`;
  `PARITY-LOOT-RANDOMNESS-001` permanece `EVIDENCE_ONLY` (una sola tirada de
  loot no prueba no-determinismo; no se inventa un requisito estadistico).
- El caveat de desalineamiento de mapa `0x64` se mantiene fuera del boundary
  de replay, sin promoverse a regla de oracle autoritativa.
- `ParityFixtureV2 2.0.0`, `tvp3d.qa.case/2.0.0` y `tvp3d.qa.report/2.0.0`
  no cambiaron de forma ni significado. Los cuatro fixtures de Phase 2A y su
  harness (`qa/parity/tools/validate_pilot.py`) no se tocaron.

## Conteos (sin cambio en este turno)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.0`) | 198 | 0 |
| Corpus piloto `LEGACY_PARITY` Phase 2 | 4 | 4 (sin cambio; ningun fixture nuevo este turno) |

## Verificacion de cierre Phase 2B.0

- 10 bloques JSON del contrato parsean.
- `tvp3d.qa.parity_fixture`, `tvp3d.qa.case` y `tvp3d.qa.report` permanecen
  en `2.0.0`; `tvp3d.qa.oracle_observation` y `tvp3d.qa.parity_expectation`
  son identidades nuevas en `1.0.0`; `tvp3d.qa.error` avanza a `2.1.0`.
- Ningun archivo bajo `qa/` o `docs/qa/` fue creado, modificado ni
  ejecutado; los 4 fixtures de Phase 2A y `validate_pilot.py` quedan
  byte-identicos.
- No se inicio Docker/TVP; no se conecto a ninguna cuenta legacy.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo cambiaron `worklog/qa/CONTRATO.md`, `worklog/qa/STATE.md` y el diario
  append-only; ningun otro `CONTRATO.md`/`STATE.md`, `CARRILES.md`,
  `MASTER_PLAN.md` ni codigo de produccion se toco.
- Ninguna linea historica de `worklog/EVENTS.jsonl` fue reescrita.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Turno cerrado: Phase 2A — Piloto LEGACY_PARITY (muerte/corpse/reentrada/loot)

Primer turno real de materializacion Phase 2. Contract-only en lo que toca a
`qa 2.0.1` (no se modifico `worklog/qa/CONTRATO.md`); este turno SI crea
archivos QA-owned bajo `qa/` y `docs/qa/`, autorizado explicitamente por el
alcance de esta fase.

- Materializados cuatro fixtures `LEGACY_PARITY` (`tvp3d.qa.parity_fixture/2.0.0`,
  ya publicado por `qa 2.0.1`, sin cambios de schema) a partir de evidencia ya
  grabada en `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`:
  `PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001`,
  `PARITY-MONSTER-CORPSE-001`, `PARITY-LOOT-RANDOMNESS-001`. Los cuatro
  clasificados `MATCH_EXPECTED`.
- Archivos: `qa/parity/fixtures/tvp772/death_corpse_loot/*.json` (cuatro
  fixtures + `manifest.json` de metadata propia de QA, no un contrato
  nuevo), harness `qa/parity/tools/validate_pilot.py` (Python 3, solo
  libreria estandar), reporte deterministico
  `qa/parity/reports/pilot_death_corpse_loot_report.json`, y nota de
  hallazgos `docs/qa/PARITY_PHASE2_PILOT_DEATH_CORPSE_LOOT.md`.
- El heuristico de deteccion de muerte por cliente ("`0x6C` de `mi_id`
  siempre alcanza por si solo") **no** se codifico como verdad autoritativa:
  el propio documento fuente lo muestra como una condicion de carrera
  corregida despues por `protocolo-red 1.2.0`. El fixture de muerte captura
  solo el resultado autoritativo (corpse `dead human` + vida cero).
- El desalineamiento de mapa `0x64` observado en una corrida completa
  **no** se promovio a comportamiento autoritativo de TVP ni a
  `KNOWN_LEGACY_BUG`: `PARITY-MONSTER-CORPSE-001` usa exclusivamente las
  corridas `--solo-loot`, no afectadas por ese problema. El caveat queda
  documentado como investigacion de paridad futura, no como hallazgo de
  este piloto.
- El contenido exacto de loot (`gold coin x3`, `x4`, `cheese x1`, vacio)
  quedo en `excluded_nondeterministic_fields` de `PARITY-LOOT-RANDOMNESS-001`;
  la regla estable capturada es "el servidor decide, el cliente muestra",
  clasificada `MATCH_EXPECTED` porque el fixture representa esa regla de
  no-determinismo, no un valor de loot especifico.
- Harness ejecutado dos veces sobre el mismo estado de repositorio: reporte
  byte-identico ambas veces, codigo de salida 0. Auto-prueba negativa
  (`--selftest`) ejercito 11 documentos malformados en memoria y confirmo
  que el validador rechaza a los 11, sin escribir ningun archivo malformado
  versionado. Ademas se corrompio temporalmente un fixture real
  (clasificacion invalida), se confirmo codigo de salida 1, y se restauro su
  contenido original byte a byte antes de este commit.
- **Cero ejecuciones frescas de TVP/Docker en este turno.** No se inicio
  Docker, no se conecto a ninguna cuenta, no se ejecuto
  `prueba_muerte_loot_vivo.tscn`, no se mato a Valentino, no se mutó
  persistencia legacy y no se requirio `servidor/key.pem` ni ninguna otra
  credencial.

## Conteos separados (Phase 2A)

**Estos dos inventarios NO se combinan:**

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.0.1`) | **198** | **0** (sin cambio por este turno) |
| Corpus piloto `LEGACY_PARITY` Phase 2 | 4 | 4 (validadas localmente contra evidencia grabada; 0 ejecuciones frescas de oracle) |

## Verificacion de cierre Phase 2A

- 4 fixtures + 1 manifest parsean como JSON UTF-8 valido.
- Los cuatro fixtures usan exactamente `tvp3d.qa.parity_fixture/2.0.0`,
  `oracle=TVP_772`, `oracle_version=7.72`, y `fixture_id` unicos.
- Los cuatro `source_evidence.logical_path` son relativos al repositorio y
  resuelven a `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`, que existe.
- Ningun literal con forma de secreto/credencial en ningun fixture ni en el
  harness.
- El contenido exacto de loot queda excluido de la comparacion
  deterministica; el comportamiento de contenedor si se compara.
- El heuristico de muerte superseded y el desalineamiento de mapa NO quedan
  codificados como verdad autoritativa vigente.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo se tocaron rutas QA-owned (`qa/`, `docs/qa/`,
  `worklog/qa/STATE.md`) y el diario append-only; `worklog/qa/CONTRATO.md`,
  cualquier otro `CONTRATO.md`/`STATE.md`, `CARRILES.md`,
  `docs/tibia3d/MASTER_PLAN.md`, y codigo de produccion de
  servidor/cliente/editor/integracion quedan intactos.
- Ninguna linea historica de `worklog/EVENTS.jsonl` fue reescrita.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.
- `FULL_NATIVE_PLAYABLE` sigue `BLOCKED`; los dominios especializados
  faltantes (Authentication/Application Session, Map/World Rules, Combat,
  Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
  Monster3D final) quedan exactamente igual. Este piloto de evidencia legacy
  no desbloquea gameplay ni afirma paridad del servidor nativo V2.

## Turno cerrado: QA 2.0.1 — Erratum de conteo de cobertura

- `docs/tibia3d/PHASE1_CLOSURE_REVIEW.md` (revision de cierre de Phase 1,
  seccion 6) recalculo la matriz de cobertura de `qa 2.0.0` directamente
  desde los siete contratos fuente y encontro que el total publicado, 194,
  no era reproducible. Este turno recontó de forma independiente antes de
  corregir nada, con el mismo resultado.
- **Conteo verificado de forma independiente en este turno** (recalculado
  desde cada `CONTRATO.md`, no copiado de la revision de cierre):

  | Contrato | 2.0.0 (incorrecto) | 2.0.1 (verificado) |
  |---|---:|---:|
  | `modelo-comun` | 41 | **42** |
  | `protocolo-red` | 20 | 20 |
  | `assets` | 12 | **13** |
  | `servidor` | 35 | **37** (23 base + 14 Phase 1D.4, no 21+14) |
  | `cliente` | 26 | 26 |
  | `editor` | 21 | 21 |
  | `integracion` | 39 | 39 |
  | **Total** | **194** | **198** |

- Corregido `worklog/qa/CONTRATO.md` seccion 5 (tabla y texto de resumen) a
  los conteos verificados, y agregada la subseccion "Erratum de conteo
  2.0.1" documentando exactamente que filas cambiaron y por que. Corregida
  tambien la referencia de la seccion 20 ("Sin reclamos de ejecucion").
- **El total materializado sigue siendo 0.** Este turno NO creo, ejecuto ni
  modifico ningun `QACaseV2`, fixture de paridad, prueba ejecutable ni
  archivo bajo `cliente3d/pruebas/`, `qa/` o `docs/qa/`. No se inicio Docker,
  TVP ni Phase 2.
- Sin cambio de taxonomia/schema: `TestClassV2`, `QAResultStatusV2`
  (`PASS/FAIL/BLOCKED/NOT_RUN`), los codigos de salida (0/1/2/3), los cuatro
  `SuiteProfileV2` y los cuatro schemas `tvp3d.qa.case/2.0.0`,
  `tvp3d.qa.report/2.0.0`, `tvp3d.qa.parity_fixture/2.0.0` y
  `tvp3d.qa.error/2.0.0` quedan exactamente iguales a `2.0.0`.
- `FULL_NATIVE_PLAYABLE` sigue `BLOCKED`; los dominios especializados
  faltantes (Authentication/Application Session, Map/World Rules, Combat,
  Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
  Monster3D final) quedan exactamente igual que en `2.0.0`. Este parche
  aritmetico no desbloquea nada de gameplay.
- El turno historico `Phase 1H` (mas abajo) reporto honestamente 194 porque
  era lo que su propio conteo (con el error aritmetico) producia en ese
  momento; ese texto NO se reescribe para aparentar que ya sabia 198. La
  correccion queda documentada aqui, como turno posterior explicito.
- **Phase 2 queda limpia del defecto de conteo QA.** Este turno NO
  materializo el primer fixture de paridad; esa es la recomendacion para el
  proximo turno de `qa` (piloto pequeno sobre `LEGACY_PARITY`, por ejemplo el
  flujo de muerte/corpse/loot que ya tiene evidencia viva documentada en
  `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`), no ejecutada en este turno.

## Verificacion de cierre QA 2.0.1

- 5 bloques JSON del contrato parsean (mismo total que 2.0.0; ningun schema
  cambio de forma).
- `42 + 20 + 13 + 37 + 26 + 21 + 39 = 198` verificado por suma directa.
- Los cuatro schemas `tvp3d.qa.*` permanecen en `2.0.0`.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo `worklog/qa/CONTRATO.md`, `worklog/qa/STATE.md` y el diario
  append-only cambiaron; ningun otro contrato/estado de carril, prueba
  ejecutable, `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni codigo de produccion
  se tocaron.
- Ninguna linea historica de `worklog/EVENTS.jsonl` fue reescrita; las dos
  lineas malformadas historicas (140-141) permanecen intactas.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Turno cerrado: Phase 1H — QA V2 Contract / Test Taxonomy

- Publicado QA V2 `2.0.0` (major) sobre los siete contratos Architecture V2
  vigentes: `modelo-comun 2.1.0`, `protocolo-red 2.1.0`, `assets 2.0.0`,
  `servidor 2.1.0`, `cliente 2.0.0`, `editor 2.0.0`, `integracion 2.0.1`.
- Publicada `TestClassV2` (`CONTRACT_FIXTURE`, `NATIVE_INTEGRATION`,
  `LEGACY_PARITY`, `LEGACY_LIVE_MUTATING`), `QACaseV2`
  (`tvp3d.qa.case/2.0.0`), `QAReportV2` (`tvp3d.qa.report/2.0.0`),
  `QAResultStatusV2` (`PASS/FAIL/BLOCKED/NOT_RUN`, con `BLOCKED`/`NOT_RUN`
  explicitamente distintos de `PASS`), codigos de salida de suite (0/1/2/3)
  y cuatro `SuiteProfileV2` (`CONTRACT_V2`, `NATIVE_SMOKE_V2`,
  `PARITY_TVP_772`, `LEGACY_LIVE_MANUAL`).
- Reconstruida la matriz de cobertura leyendo los siete contratos: **194
  obligaciones de fixture especificadas, 0 materializadas.** Ver detalle por
  contrato en `CONTRATO.md` seccion 5.
- Publicados 9 invariantes cruzados con `case_id` estable (`XCUT-*`):
  scope runtime, `READY != AUTHORIZED != ACTIVE`, footprint != visual,
  `CanonicalDomainId` != id legacy, cadena de replicacion neutral,
  coincidencia de `common_domain_version` nativo, `SourceBindingV2` del
  editor, ausencia de secretos, TVP/TFS como oracle no autoridad.
- Representados explicitamente como `BLOCKED`/`CONTRACT_NOT_PUBLISHED`:
  Authentication/Application Session, Map/World Rules, Combat,
  Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
  Monster3D final. Ninguna prueba fue inventada para ellos.
- Declarado explicitamente: `FULL_NATIVE_PLAYABLE` NO es una suite que pase
  hoy; bloqueada como minimo por Authentication/Application Session y
  Map/World Rules. Movimiento por teclado/login/combate/gameplay de
  prototipo NO se certifican como aceptacion V2.
- Publicado el boundary `ParityFixtureV2` (`tvp3d.qa.parity_fixture/2.0.0`)
  para Phase 2, sin materializar el corpus completo, y el principio de que
  la paridad TVP es evidencia (`BUG|DEBT|DELIBERATE_CHANGE`), no
  especificacion V2 automatica.
- Documentada la distincion `QAReportV2.status=PASS` (ejecucion) vs
  veredicto `HECHO` de `revisar-carril` (Definicion de Hecho completa): no
  son identicos.
- QA 1.4.0 preservado integro bajo
  `HISTORICAL / SUPERSEDED — QA 1.4.0 y anteriores`, con cada seccion
  reclasificada explicitamente `LEGACY_PARITY` o `LEGACY_LIVE_MUTATING`.
- No se implemento ninguna prueba ejecutable, no se modifico
  `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni codigo de otro carril, no se
  inicio Docker y no se ejecuto ninguna prueba viva mutante este turno.

## Reclasificacion del bloqueo historico Docker/casas-camas

El bloqueo `Estado: BLOQUEADO` que encabezaba este archivo (retest de
`prueba_casa_cama_vivo.tscn` atascado por perdida de contexto Docker, con
`owner`/`premium` pendientes de confirmar en `0`) es un bloqueo de una
certificacion `LEGACY_LIVE_MUTATING` especifica (casas/camas TVP 7.72), NO
un bloqueo para publicar el contrato QA V2 de Architecture V2. Se reclasifica
aqui explicitamente sin borrar el texto original, que queda integro debajo
como evidencia operativa. La prueba de casas/camas SIGUE sin certificarse;
esta reclasificacion no reporta que paso.

## Verificacion de cierre Phase 1H

- 5 bloques JSON del contrato (`QACaseV2`, referencia de contrato,
  `QAReportV2`, `QAErrorV2`, `ParityFixtureV2`) parsean.
- Los eventos agregados son lineas JSON validas y solo se anexaron al final.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo contrato/estado de `qa` y el diario append-only forman parte del
  cierre; los cambios sucios ajenos detectados al inicio quedan intactos.
- No se modificaron `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni contratos de
  otro carril.
- Ninguna dependencia normativa apunta a un contrato futuro no publicado;
  su ausencia esta representada como `BLOCKED`.
- `FULL_NATIVE_PLAYABLE` queda declarado bloqueado, no aprobado.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Depende de

- `modelo-comun` 2.1.0: contrato publicado.
- `protocolo-red` 2.1.0: contrato publicado.
- `assets` 2.0.0: contrato publicado.
- `servidor` 2.1.0: contrato publicado.
- `cliente` 2.0.0: contrato publicado.
- `editor` 2.0.0: contrato publicado.
- `integracion` 2.0.1: contrato publicado.

## Le toca

Materializar progresivamente las 198 obligaciones especificadas (conteo
corregido en `2.0.1`; ver "Turno cerrado: QA 2.0.1" arriba)
(`SPECIFIED_NOT_MATERIALIZED -> MATERIALIZED`) a medida que exista
implementacion nativa que probar, y mantener `FULL_NATIVE_PLAYABLE` honesto
hasta que Authentication/Application Session y Map/World Rules se publiquen.

Para el corpus Phase 2 `LEGACY_PARITY`: el piloto de 4 fixtures
(muerte/corpse/reentrada/loot, ver "Turno cerrado: Phase 2A" arriba) valido
el flujo completo fixture+harness contra evidencia ya grabada, y
`qa 2.1.0` (ver "Turno cerrado: Phase 2B.0" arriba) publico el boundary
maquina-legible (`OracleObservationV1`/`ParityExpectationV1`) que faltaba
para comparar una observacion fresca sin hardcodear semantica en codigo.

Siguiente tarea exacta (no ejecutada en este turno): **Phase 2B.1** —
implementar captura/replay controlada de TVP contra el boundary recien
publicado, produciendo `OracleObservationV1` reales para
`PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001` y
`PARITY-MONSTER-CORPSE-001` (los tres `SINGLE_OBSERVATION`), y evaluandolas
con el comparador generico de la seccion 16C. `PARITY-LOOT-RANDOMNESS-001`
permanece `EVIDENCE_ONLY` hasta que exista una extension de comparacion
multi-muestra/estocastica. Por separado, investigar el caveat de
desalineamiento de mapa documentado en
`docs/qa/PARITY_PHASE2_PILOT_DEATH_CORPSE_LOOT.md`. Recien despues de
validar ese flujo conviene escalar al resto del corpus de paridad.

Nota de cierre historica (turno anterior): el commit local `31db317`
contiene aquel cierre; `git push` quedo bloqueado por falta de conexion a
`github.com:443`.

## Hecho

- Casas/camas: se inspecciono la casa 6 (Sunset Homes, Flat 01), con camas
  reales en `(32329,32230,7)` y entrada `(32333,32232,7)`. La prueba viva
  `prueba_casa_cama_vivo.tscn` deja el propietario y la cuenta premium
  restaurados, pero TVP responde `You cannot use this object` al usar la cama
  desde el interior. No se certifica dormir/despertar ni persistencia hasta
  resolver la condicion autoritativa de uso (zona PZ/permisos); queda como
  bloqueo reproducible, no como aprobado parcial.

- Cierre versionado en `24c9ab7` y publicado en `origin/main`; `git diff
  --check` pasa y los eventos JSON son validos.
- Correccion preparada en `servidor/src/iomap.cpp`: el cargador TVP ahora usa
  `House::addTile`, que registra camas y marca las casillas de casa como PZ.
  Commit `5dcdabc` publicado. Falta repetir la prueba viva cuando Docker
  Desktop vuelva a exponer su socket.
- Retest parcial tras reiniciar Docker: `/tileinfo 32328,32230,7` devuelve
  `flagPZ=true`, confirmando el efecto del arreglo. La corrida completa se
  atasco en login despues de multiples sesiones previas; owner y premium fueron
  restaurados a `0`. Accion concreta: ejecutar una corrida limpia con el servidor
  recien iniciado y sin sesiones residuales.
- Atención operativa: la última preparación de la prueba dejó pendiente
  confirmar/restaurar `houses.id=6.owner` y `accounts.id=123456.premium_ends_at`
  porque el motor Docker cayó antes de la limpieza. Restaurar ambos a `0` antes
  de cualquier otra prueba.

- Andamiaje creado.
- Publicado el contrato de QA v1.0.0.
- Ejecutada paridad IR vs estado vivo: 81 tiles coincidentes, 0 diferencias,
  1 criatura ignorada.
- Validada escalera real en TVP: z7 -> z6 -> z7, dos posiciones recibidas por
  0x64, personaje restaurado; `EstadoMundo` tambien expone 0xBE/0xBF si el
  servidor usa esos paquetes.
- Integrado inspector conectado en `mundo3d.gd`: seleccion por Shift+click,
  toggle F4, stack vivo y flags/metadatos IR por chunks; escena principal carga
  en headless sin errores.
- Runner local en `pruebas/matriz_qa_local.gd` ejecuta la checklist en procesos
  Godot separados y escribe `generated/reports/qa_matrix_local.json`.
- Matriz local ejecutada 6/6: coordenadas, controles, formas, chunks, modelo
  de proyecto y escena del editor pasan.
- Reporte versionado en `generated/reports/qa_matrix_local.json`.
- Regresion de spells y animaciones ejecutada 0 fallas: catalogo JSON, outfit
  multiframe, efectos/proyectiles importados, eventos `0x83`-`0x85`, cambio de
  outfit `0x8E`, alineacion del siguiente mensaje y lanzamiento por `0x96`.
- Matriz local ampliada y ejecutada 7/7 con `prueba_spells_animaciones.tscn`.
- Magic Wall de 3DTIBIA integrada con sus seis PNG originales, cubo 1x2x1 y
  animacion de tres fases a 5 FPS para los client ids 2128/2129.
- `prueba_magic_wall.tscn` verifica texturas, animacion y reemplazo seguro de
  una instancia dinamica; matriz local ejecutada 8/8.
- El picking de puertas simples usa la proyeccion vertical de la camara para
  uso/mirar; las variantes con llave, nivel, mision o sellado quedan fuera.
- Se agregaron regresiones para puertas simples/parametrizadas; la matriz local
  termina 9/9 y el login real contra TVP responde correctamente.
- El servidor reconstruido conserva la regeneracion otorgada por equipo dentro
  de proteccion: Guuille, con life ring en la ranura 9, paso de 157 a 160 de
  vida y de 1079 a 1082 de mana durante una medicion real de 7 segundos.
- Publicada `docs/qa/PARIDAD_772_2026-08-29.md`: matriz global basada en el
  servidor autoritativo que separa COMPROBADO, PARCIAL y AUSENTE.
- Validado el checkpoint actual en ocho procesos Godot: contenedores/canales,
  controles, eventos/trade, modelos authored, formas, spells, escena principal
  y escaneo de editor terminaron con codigo cero.
- `prueba_muerte_reentrada` adoptada en la matriz local: 10/10 OK y reporte
  regenerado.
- Prueba viva de muerte, corpse y loot ejecutada contra el servidor TVP:
  un demon invocado con `/m` mato al personaje, el servidor dejo el corpse
  `dead human`, el `0x6C` de `mi_id` con vida cero emitio la muerte, el
  logout `0x14` termino la sesion y el reingreso devolvio un personaje vivo
  en su templo.
- Mitad de corpse y loot repetible sola con `--solo-loot`: dos corridas
  independientes abrieron el corpse `dead rat` y leyeron loot distinto
  (`gold coin x3` y `x4`), que es el que decide el servidor.
- Evidencia, etapas, limites y efectos publicados en
  `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`; matriz global actualizada.
- La precondicion del duelo ya no es manual: el god va al campo y trae al
  personaje con `/c`, la talkaction del servidor. El cliente no camina ni
  simula intenciones, y la confirmacion la da la posicion autoritativa de la
  propia sesion del personaje.
- La prueba abre dos sesiones simultaneas (personaje y god) y respeta
  `Ban::acceptConnection`: un solo login por corrida y seis segundos entre
  sesiones nuevas.
- Modo `--solo-campo`: prueba solo la precondicion, retira el verdugo antes de
  que mate a nadie y devuelve el personaje a su templo con `omani`. Cinco
  comprobaciones en verde y codigo cero, repetible sin costo.
- `--solo-loot` sigue en verde y ahora distingue su propia rata por id nuevo y
  su corpse por casilla que no tenia corpse antes de la caza; el campo tiene
  ratas salvajes y restos de corridas viejas.
- `prueba_estado_criatura_ui` adoptada en `matriz_qa_local.gd`, que termina
  11/11 OK.
- La matriz local incorpora los self-tests de estado de criatura y mapa 7.72;
  termina 13/13 OK con codigo cero.
- Dos corridas vivas posteriores a `protocolo-red` 1.2.0 confirmaron muerte,
  logout `0x14`, cierre de sesion, reingreso vivo y corpse `dead rat` abierto
  con loot real (`cheese x1` y `gold coin x3`). La carrera de muerte queda
  cerrada.
- `pila: ?` queda corregido como diagnostico: no falta un nombre de assets. El
  `0x64` vivo deja al jugador fuera de `mi_pos` y reinterpreta bytes siguientes
  como ids imposibles. La prueba conserva el detalle y no acusa al servidor de
  omitir un corpse cuando `mapa_alineado` es falso.
- Prueba viva de VIP y trade ejecutada con dos sesiones reales. El god hizo
  remove/add de Valentino por nombre, recibio GUID 2 offline, online al entrar
  y offline al salir.
- El trade vivo preparo dos server id 2006/client id 2874, recibio oferta
  propia y contraparte en ambos clientes, acepto desde los dos sockets y
  comprobo las actualizaciones de inventario de la transferencia. Corrida
  final: codigo 0, 10 comprobaciones en verde.
- Publicado `docs/qa/PRUEBA_VIVA_TRADE_VIP.md` y contrato QA 1.2.0 con el
  comando, mutaciones, evidencia y limite de produccion encontrado.
- Repetida la certificacion con `Son Goku` (GUID 16) desde su otra cuenta:
  codigo 0, VIP y transferencia completos. La asociacion temporal a la cuenta
  de pruebas se restauro en `finally` y la prueba queda parametrizada sin
  imprimir claves.

- Party viva con dos clientes: `pruebas/prueba_party_viva.tscn` recorrio
  invitar, unirse, pasar liderazgo y salir contra el servidor, y los escudos
  de las dos sesiones contaron la misma party en cada paso. Ocho
  comprobaciones en verde y codigo cero, sin costo para ningun personaje.
- Evidencia y limites en `docs/qa/PRUEBA_VIVA_PARTY.md`; la fila de party de la
  matriz global pasa a COMPROBADO.
- La matriz local adopta `party_ui`, `party_protocolo` y `mapa_captura`, y
  termina 16/16 OK.
- La prueba viva de trade dejo de armar el `0x7D` a mano: usa el metodo que
  publico `protocolo-red` 1.5.0 y volvio a pasar entera contra el servidor.
- Depot probado en vivo: `pruebas/prueba_depot_vivo.tscn` guarda un objeto,
  cierra la sesion, vuelve a entrar y el objeto sigue en el `depot chest`.
  Seis comprobaciones en verde y codigo cero, sin tocar las cosas de nadie.
- Tres reglas de esta rama que no eran obvias quedaron escritas en
  `docs/qa/PRUEBA_VIVA_DEPOT.md`: hay que PISAR la baldosa para que el servidor
  cargue el depot del jugador, las cosas viven en el `depot chest` de adentro
  del locker, y la ventana de contenedor la elige el cliente en el `0x82`.
  Sin pisar la baldosa se abre el mueble del mapa, que acepta objetos y no es
  de nadie: es la trampa mas facil del recorrido.
- La fila de la matriz global se parte en dos: `Depot` pasa a COMPROBADO y
  `Mail/parcels` queda BLOQUEADO por el servidor.
- Correccion: el depot probado es el de **Thais**, no el de Rookgaard. Los
  personajes de prueba salen en el templo de Thais `(32369,32241,7)` y su
  depot esta a quince casillas. Rookgaard no tiene depot ni correo, igual que
  en el Tibia original.
- Prueba viva de parcel y mailbox escrita y corriendo en Thais. Se traba
  siempre en el mismo punto y con la causa localizada: al usar una etiqueta el
  servidor contesta `You cannot use this object` por la guarda de
  `game.cpp:2556-2560`. Evidencia en `docs/qa/PRUEBA_VIVA_PARCEL.md`.
- Correccion compensatoria: el servidor ya deja usar la etiqueta y el usuario
  confirmo que la parcel llega al depot del destinatario. Los archivos vivos
  conservan parcels dirigidas dentro de depot 1; mail/parcels pasa a
  COMPROBADO sin repetir la prueba mutante.
- `prueba_reacquisicion_monstruo.tscn` certifica el cambio compilado de
  `monster.cpp`: un `cave rat` identificado golpeo, el servidor movio al
  personaje 39 SQM fuera de vista y, al devolverlo, el mismo id retomo el
  ataque. Corrida final: vida 133 -> 131 -> salida/regreso -> 128, mismo id y
  limpieza confirmada, codigo 0.
- La prueba descarto una primera corrida donde los golpes eran de un `spider`
  silvestre y endurecio el oracle: solo cuenta dano cuyo mensaje nombra al
  monstruo invocado. Evidencia en
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`.
- La matriz local se repitio despues del cambio y termino 17/17 OK.

## Falta

- Completar matriz de red de todos los recorridos y errores contra un servidor
  legacy disponible.
- Repetir la checklist desde un clon limpio para la prueba de entrega.
- Probar en vivo el camino de produccion que inicia trade desde el menu de la
  criatura y luego selecciona el objeto.
- En la prueba viva de muerte, el unico fallo que queda es la limpieza del
  demon con `/killall`, que solo alcanza el cuadro alrededor de quien lo dice.
- Casas/camas: permisos, dormir/despertar y persistencia real contra la
  autoridad del servidor.
- Las corridas fallidas del depot dejaron dos parcels del god dentro del
  mueble del mapa en `(32354,32231,7)`. No rompen nada pero estan ahi.

## Bloqueos activos

- ATENDIDA el 2026-08-29: el `0x64` desalineado. `protocolo-red` 1.3.0
  encontro la causa con el OTBM como oraculo —una casilla que existe y se
  describe con cero bytes deja dos marcas pegadas— y dejo la captura real como
  regresion. El mapa vivo del campo entrega ahora las 356 casillas que dice el
  OTBM, con el jugador en la suya.
- ATENDIDA el 2026-08-29: el `0x7D` saliente. `protocolo-red` 1.5.0 lo publico
  con el atajo de inventario y la prueba viva ya lo usa en vez de armar los
  bytes. `cliente` 1.4.0 ya lo ofrece; falta la prueba viva que empieza en ese
  menu.
- La prueba manual de puertas y runas sigue pendiente; la prueba automatizada
  del life ring ya pasa contra el servidor reconstruido.
- ATENDIDA el 2026-08-29: reacquisicion de monstruos. El servidor ya estaba
  reconstruido y la prueba viva por salida/regreso de la ventana termino en
  codigo cero con el mismo id de criatura.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Las pruebas de fecha usan reloj fijado | Evita que fallen con el paso de los meses | si |
| La prueba viva no camina al personaje para salir del templo | Caminar a ciegas no sale de la zona de proteccion y un auto-walk inventado seria la intencion de cliente que la prueba no debe simular | si |
| Al personaje lo saca del templo el servidor con `/c`, no el cliente | Es una talkaction del propio servidor: mueve a la criatura a la casilla libre mas cercana al god y el cliente solo mira donde lo dejaron | si |
| La prueba mantiene dos sesiones simultaneas | El `/c` solo alcanza a un personaje conectado, y asi el duelo no necesita relogueos | si |
| El god no se teletransporta encima de un monstruo vivo | El empujon del teleport deja la casilla en un estado que la prueba lee mal; sobre un corpse si puede pararse | si |
| El duelo ocurre siempre en la misma casilla de campo | Es la unica comprobada fuera de zona de proteccion, y asi la corrida no depende de donde quedo nadie | si |
| La mitad de corpse y loot se hace siempre en `32082,32145,6` | Es una casilla comprobada fuera de zona de proteccion, asi la media prueba se repite sin depender de donde quedo nadie | si |
| El monstruo del corpse se remata con `/killall` si el cuerpo a cuerpo tarda | El personaje god es nivel 1 y la prueba mide corpse y loot, no el ritmo de combate | si |
| Una pila solo certifica un corpse si `mapa_alineado` es verdadero | Sin el jugador en `mi_pos`, los indices y objetos locales no representan el paquete del servidor | no |
| La prueba viva de trade normaliza las manos y usa dos server id 2006 | El servidor necesita dos ofertas reales para ejecutar `playerAcceptTrade`; el usuario autorizo alterar los personajes de prueba | si |
| QA usa el `0x7D` publicado, no bytes armados a mano | La prueba viva debe cubrir el mismo transporte que usa produccion | no |
| Un golpe de reacquisicion debe nombrar al monstruo invocado | El campo contiene criaturas silvestres; una bajada de vida sola produjo un falso positivo real con un spider | no |
| El fixture de experiencia compartida NO lleva observacion grabada | `PRUEBA_VIVA_PARTY.md:67-74` prueba que ese dominio nunca se ejercito en vivo antes; inventar la evidencia grabada seria fabricarla | no |
| El monstruo de la medicion se identifica por id NUEVO, no por nombre | El campo tiene fauna del mismo tipo; por nombre una rata silvestre llego a recibir una invitacion de party. Ademas evita tener que matar fauna preexistente | no |
| El god queda fuera de la party y nunca golpea al monstruo | Su parte proporcional del dano saldria del pozo de la party (`creature.cpp:375`) y el reparto dejaria de coincidir con la formula; ademas el grupo 6 no gana experiencia | no |
| El refuerzo de los personajes de QA es deliberadamente moderado | Si uno matara al monstruo de un solo golpe, el otro no registraria participacion y el reparto nunca se habilitaria | si |
| Se sube nivel a los personajes de QA pese a que el nivel da experiencia | Se aplica antes de la foto y la medicion es un delta; ademas cada avance cura y saca la vida baja de resaca. A los dos por igual para no romper la regla de nivel | si |
| `sharedExpEnabled` se prueba por comportamiento, no leyendo estado | No viaja por la red: sin habilitar cada atacante cobra proporcional al dano, asi que ganancias iguales y coincidentes con la formula son la evidencia | no |
| La orden de toggle rechazada en combate se registra como asercion | `game.cpp:5097` la descarta en silencio; aparecio como falso fallo y es una regla real del oracle que el servidor nativo debe reproducir | no |

## Notas para quien retome

- La revision cruzada debe hacerla un agente que no haya implementado el
  carril revisado.
- El runner local no arranca servidores ni toca datos persistentes; las
  pruebas de red siguen siendo explícitas y secuenciales.
- La prueba viva SI toca datos persistentes: una corrida completa le cuesta un
  nivel al personaje normal y deja sus objetos en el corpse. Para restaurarlo
  estan la semilla `servidor/docker/data/02-data.sql` y
  `servidor/gamedata/players/`. El 2026-08-29 se ejecutaron cuatro corridas
  completas, asi que Valentino quedo varios niveles abajo.
- Para probar la precondicion sin costo se usa `--solo-campo`. Solo la corrida
  completa mata al personaje.
- En este turno se ejecutaron dos corridas completas adicionales con permiso
  explicito del usuario; ambas terminaron con dos fallas de alineacion, no de
  muerte ni de loot.
- Si una corrida se cuelga y se la mata a mano, conviene esperar antes de la
  siguiente: el servidor todavia considera conectado al personaje y
  `Ban::acceptConnection` cuenta las conexiones de la IP.
- Si el CLI de Docker en Windows se cuelga, el motor suele seguir vivo: se lo
  mira por el socket de adentro de WSL y se arregla reiniciando Docker
  Desktop. El 2026-08-29 el contenedor `servidor-server-1` estaba caido y los
  puertos 7171/7172 seguian escuchando sin nadie detras.
- `prueba_trade_vip_vivo.tscn` es mutante y no entra a la matriz local. Vaciar
  slots ya vacios puede producir `Sorry, not possible.` antes del trade; esos
  mensajes son precondicion esperada. Cualquier error durante oferta o
  aceptacion si hace fallar la corrida.
- El 2026-08-29 Son Goku estaba offline antes de la prueba. No se cambio su
  clave: solo se cambio su asociacion de cuenta durante la corrida y se
  restauro inmediatamente despues, aun ante fallo.
- La prueba de reacquisicion mueve y dana temporalmente a Valentino. Tras la
  corrida final se restauraron exactamente los timestamps, posicion, vida y
  duracion de condicion que tenian sus archivos al abrir este turno; los
  depots y demas cambios previos del usuario quedaron intactos.
