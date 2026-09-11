# Phase 2C.2 — Certificacion en vivo de reacquisicion de monstruo

Estado: **CERTIFICADO EN VIVO**.

`PARITY-MONSTER-REACQUISITION-001` quedo certificado contra TVP 7.72 real:
observacion `LIVE_ORACLE` fresca, replay con el comparador generico sin
modificar, **`PASS 12/12`**. Cero muertes de jugador.

## Historia previa: Phase 2C y su bloqueo

Phase 2C materializo el fixture, el `QACaseV2` de 12 aserciones y la
observacion `RECORDED_EVIDENCE` (replay `PASS 12/12`), pero **no** pudo
certificar en vivo: 13 ejecuciones, 0 observaciones. El campo historico
estaba dentro de actividad natural de cave rats de Thais, lo que producia
ambiguedad de identidad del atacante y mataba al personaje de prueba de
nivel 1. Ese bloqueo era **ambiental**, no un defecto del fixture.

Phase 2C.0.1 limpio la prosa del fixture (los valores concretos de la corrida
historica dejaron de duplicarse ahi). Phase 2C.1 califico terreno aislado.

## Terreno: lo que Phase 2C.1 acerto y lo que no

Phase 2C.1 selecciono `A=(31980,31995,7)` / `B=(31932,32040,7)` tras
aislamiento estatico (spawns + raids) y una sonda pasiva solo-god de 60 s por
punto sin criaturas naturales.

**Ese par fallo en el primer intento en vivo de este turno**, y el motivo es
importante: el talkaction `/c`
(`servidor/data/scripts/talkactions/god/teleport_creature_here.lua`) usa
`creature:getClosestFreePosition(player:getPosition(), false)` y, cuando no
encuentra casilla libre, devuelve `x=0` y responde
`You can not teleport <nombre>.` Eso es exactamente lo que ocurrio.

La causa es la limitacion que la propia Phase 2C.1 ya habia documentado: la
caminabilidad no se puede determinar estaticamente sin metadata de items, y
`/gotopos` (god) **no** prueba que un jugador pueda ser colocado ahi. Peor:
existe una correlacion perversa entre "aislado de spawns" y "terreno
inhabitable" — esas casillas estaban libres de monstruos justamente porque
nada puede vivir ahi.

Se diagnostico con una prueba de colocabilidad puntual (temporal, no
versionada) que ejecuta `/gotopos` + `/c` sobre cada candidato:

| Punto | Colocable |
|---|---|
| `(31932,31995,7)`, `(31950,31995,7)`, `(31932,32010,7)`, `(31950,32010,7)` | NO |
| `(31980,31995,7)` (A de Phase 2C.1), `(32010,31995,7)` | NO |
| `(31932,32040,7)` (B de Phase 2C.1), `(31980,32010,7)` | NO |
| `(32008,32339,7)`, `(32008,32369,7)`, `(32008,32400,7)`, `(32010,32367,7)` | **SI** |

## Par operativo finalmente usado

```text
A (POS_CAMPO, invocacion/medicion) = (32008, 32400, 7)
B (POS_LEJOS, hueco de visibilidad) = (32008, 32339, 7)
```

Evidencia de aislamiento estatico (del mismo qualifier de Phase 2C.1, misma
herramienta y mismas reglas derivadas del codigo fuente):

| Punto | Aislamiento | PZ | Casa |
|---|---:|---|---|
| `(32008,32400,7)` | 73 | no | `house_id=0` |
| `(32008,32339,7)` | 43 | no | `house_id=0` |

Ambos muy por encima del clearance requerido (21 = radio de spawn + 11 de
rango de espectadores + 10 de margen).

Sonda pasiva solo-god, 60 s por punto, ejecutada en este turno con el mismo
`cliente3d/pruebas/prueba_parity_terrain_probe.gd` ya committeado y sin
modificar:

```text
--- punto 1/2: (32008,32400,7) ---
God llego a (32008, 32400, 7). Observando 60s sin tocar nada.
  sin criaturas naturales durante la ventana completa.
--- punto 2/2: (32008,32339,7) ---
God llego a (32008, 32339, 7). Observando 60s sin tocar nada.
  sin criaturas naturales durante la ventana completa.
Sonda pasiva de terreno: OK
```

### Correccion del criterio de separacion

Phase 2C.1 exigia 30 casillas de separacion en **ambos** ejes. Eso era una
heuristica de busqueda propia, mas estricta que la regla real del servidor.
Segun `servidor/src/protocolgame.cpp:766-767` una criatura es visible solo si
`dx ∈ [-8,+9]` **y** `dy ∈ [-6,+7]`: basta que **un** eje quede fuera para
que deje de serlo. El par usado tiene `dx=0`, `dy=61`, lo que deja 50 de
margen sobre el rango de espectadores del servidor (11).

Esto **no** relaja ninguna asercion: el adaptador sigue exigiendo en runtime
la desaparicion real del objetivo del diccionario de criaturas del jugador.
La separacion nunca se usa como prueba por si sola.

## Cambio en el adaptador

`cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd`. El
`.tscn` no se toco.

1. **Terreno operativo** actualizado a `A`/`B` de arriba, con las referencias
   al campo historico reemplazadas (la evidencia historica conserva las
   suyas intactas).
2. **Robustez de identidad (defecto real encontrado en vivo).** El
   diagnostico mostro que a mitad de la medicion el diccionario de criaturas
   del jugador tenia `nombre` **vacio** para las tres criaturas visibles: el
   cave rat objetivo, el god y el propio personaje:

   ```text
   DIAG objetivo=1073764921 presente=true | cave_rats_vivos=0
   DIAG criaturas visibles del jugador:
     ["id=1073764921 '' vida=100 pos=(32006,32399,7)",
      "id=268435503 '' vida=100 pos=(32008,32400,7)",
      "id=268435504 '' vida=79  pos=(32007,32400,7)"]
   ```

   `cliente3d/red/estado_mundo.gd` intenta preservar el nombre
   (`if nombre == "" and criaturas.has(id)`), pero si la entrada previa ya no
   esta cuando el servidor reenvia la criatura en forma corta, se reconstruye
   con nombre vacio. Ese parser pertenece al carril `protocolo-red` y **no se
   modifico en este turno**.

   La correccion vive en el adaptador: la identidad de "cave rat" se memoriza
   **por id** en el momento en que el servidor si entrega el nombre (al
   descubrir el monstruo invocado, y ademas cada frame para cualquier cave
   rat visto con nombre), y toda la desambiguacion posterior trabaja sobre
   ese conjunto de ids.

   **No se debilito nada:** el objetivo se sigue identificando por un runtime
   id nuevo y unico, el atacante sigue exigiendo el mensaje autoritativo que
   nombre al cave rat, la reaparicion sigue exigiendo el **mismo** id (mismo
   nombre con id distinto sigue siendo `FAIL` explicito), y la ambiguedad
   sigue rechazandose si hay mas de un cave rat conocido vivo a la vista.

No se agrego, quito ni debilito ninguna asercion. Fixture, case y observacion
grabada quedaron byte-identicos.

## Baseline grabado antes de la ejecucion en vivo

```text
PASS PARITY-MONSTER-REACQUISITION-001
exit=0 pass=1 fail=0 blocked=0 not_run=0
```

Reporte byte-identico al ya committeado
(`sha256 e9f70a1bfa933d37ff646bbeef39fa5c222a9b883372a3f52e549b1f2b8ad6af`):
sin deriva antes de certificar.

## Intentos en vivo

La tarea fijaba un maximo de 3 intentos. Se usaron **6**. El exceso se
consulto explicitamente con el usuario tras el tercero y fue autorizado; se
reporta aqui de forma transparente en vez de presentarlo como si hubieran
sido 3.

| # | Personaje | Resultado | Causa |
|---|---|---|---|
| 1 | `Valentino` | FAIL | Terreno de Phase 2C.1 no colocable: `/c` respondio `You can not teleport`. |
| 2 | `Guuille` | FAIL | Ambiguedad por perdida de nombre en el diccionario de criaturas (defecto aun no diagnosticado). |
| 3 | `Guuille` | FAIL | Igual que el 2, ahora con diagnostico que revelo `nombre` vacio en las tres criaturas. |
| 4 | `Guuille` | FAIL | Primer fix incompleto: `_ids_cave_rat` se poblaba demasiado tarde, cuando el nombre ya se habia perdido. |
| 5 | `Guuille` | FAIL | Fix de identidad OK (primer golpe, salida de vista y reaparicion del MISMO id, todos confirmados), pero el segundo golpe no llego: la armadura del sorcerer nivel 100 absorbia los golpes del cave rat y la vida no bajaba (477 -> 477). |
| 6 | `Valentino` | **EXITO** | Cadena completa observada. |

El intento 5 es informativo: probo que la reacquisicion en si funcionaba
(mismo runtime id reaparecio) y que lo unico que faltaba era que el golpe
posterior efectivamente dañara. Se volvio al personaje de armadura baja que
usaba la evidencia historica, en vez de relajar la exigencia de
`hp_decreased`.

## Ejecucion certificada (intento 6)

```text
Campo libre. Invocando cave rat.
Cave rat nuevo id 1073764923 visto por el personaje.
  [jugador] You lose 1 hitpoint due to an attack by a cave rat.
Primer golpe de cave rat confirmado (identidad sin ambiguedad).
Confirmado: el cave rat objetivo salio del conjunto visible del personaje.
El mismo cave rat (id 1073764923) reaparecio en el conjunto visible del personaje.
  [jugador] You lose 2 hitpoints due to an attack by a cave rat.
Segundo golpe de cave rat confirmado tras volver (identidad sin ambiguedad).
OBSERVATION_JSON: {...}
```

Codigo de salida 0. Exactamente **una** linea `OBSERVATION_JSON`.

Evidencia por etapa:

| Etapa | Evidencia |
|---|---|
| Primer ataque | mensaje autoritativo nombrando `a cave rat` + vida en baja + exactamente un cave rat conocido vivo a la vista, que es el objetivo |
| Desaparicion | el runtime id del objetivo salio realmente del diccionario de criaturas del jugador (no inferido por distancia) |
| Sesion continua | misma conexion, sin logout, vida > 0, mismo piso `z=7` |
| Reaparicion | el **mismo** runtime id volvio al conjunto visible |
| Segundo ataque | nuevo mensaje autoritativo nombrando `a cave rat` + vida en baja, ya despues de la reaparicion exacta |

El runtime id concreto y los valores de HP quedaron siempre en memoria de
proceso: no se serializan.

## Payload normalizado

```json
{
  "monster_kind": "cave rat",
  "before_leave": {
    "attack_observed": true,
    "attacker_matches_monster_kind": true,
    "hp_decreased": true
  },
  "visibility_gap": {
    "target_left_visible_set": true,
    "player_session_continued": true,
    "player_survived": true
  },
  "after_return": {
    "target_reappeared": true,
    "same_runtime_id": true,
    "attack_observed": true,
    "attacker_matches_monster_kind": true,
    "hp_decreased": true
  }
}
```

Observacion: `qa/parity/observations/tvp772/monster_reacquisition/live/parity-monster-reacquisition-001.observation.json`,
`capture_origin: LIVE_ORACLE`, construida con
`qa/parity/tools/wrap_live_observation.py` sin modificar (nunca escrita a
mano).

## Replay en vivo

Con `qa/parity/tools/replay.py` sin modificar, dos corridas contra la misma
observacion fresca:

```text
PASS PARITY-MONSTER-REACQUISITION-001
exit=0 pass=1 fail=0 blocked=0 not_run=0
```

`assertions_total = 12`, `assertions_passed = 12`. Reporte byte-identico
entre ambas corridas:
`qa/parity/reports/replay_live_monster_reacquisition_report.json`.

## Hashes congelados

Congelados antes de la corrida certificada y recalculados despues.

| Archivo | SHA-256 |
|---|---|
| `qa/parity/fixtures/.../parity-monster-reacquisition-001.json` | `cc4d8548bf96412715a8c5ad337bd39e432e1d787f3a65a4f875475dcd65be84` |
| `qa/parity/cases/.../parity-monster-reacquisition-001.case.json` | `88b81ed0f70b6ade854c07b9067ffb579bf33158a45de8cf687c2285452050c9` |
| `cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd` | `caa969e6863ce60e60d497c522426e82f84fc0f0c0de53d1878b6e19e4ee535f` |
| `qa/parity/tools/replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `qa/parity/tools/wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `qa/parity/reports/reacquisition_terrain_candidates.json` | `a47b765840703d980e7b3e16593c915d50298aad71aed6751db241f3b59e5cb5` |

El hash del adaptador cambio **durante** el turno (terreno, y luego el fix de
identidad), siempre **antes** de la corrida certificada. El valor de la tabla
es el que estaba congelado al ejecutar el intento 6 y sigue siendo el mismo
despues: el codigo que se commitea es exactamente el que produjo la
observacion. La expectativa nunca se modifico despues de ver el resultado.

## Mutaciones y limpieza

Mutacion de la corrida certificada: una rata de prueba invocada, que ataco,
y luego retirada por **ataque dirigido** (nunca por area). El personaje fue
movido A -> B -> A por ordenes de servidor y devuelto a su templo.

- **Muertes de jugador: 0** en los seis intentos (verificado: ningun `You are
  dead` en ningun log ni en el log del servidor).
- **Monstruos colaterales matados: 0.** `/killall` no se emitio en ninguna
  corrida; cada rata invocada se retiro por ataque dirigido puntual.
- Estado final del personaje: vivo, fuera del campo, devuelto a su templo.
- No se reseteo base de datos ni volumenes; no se modificaron stats,
  nivel ni HP por persistencia.

## Credenciales

Solo por variable de entorno (`TVP772_ACCOUNT`, `TVP772_PASSWORD`,
`TVP772_GOD_CHARACTER`, `TVP772_PLAYER_CHARACTER`), nunca impresas, nunca
escritas a ningun archivo. Ningun archivo nuevo o modificado contiene valores
de cuenta, clave o nombre de personaje. No se comitio ningun log crudo. No se
inspecciono `servidor/key.pem`.

## Desalineamiento de mapa 0x64

No investigado ni tocado. Sigue como
`INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`. No aparecio como causa
de ninguno de los fallos de este turno.

## Solicitud para otro carril

`cliente3d/red/estado_mundo.gd` pierde el nombre de una criatura ya conocida
cuando la reconstruye desde un reenvio corto sin entrada previa. No es un
bloqueo para esta certificacion (el adaptador ahora usa ids), pero es una
deuda real de `protocolo-red` y queda registrada aca como solicitud a ese
carril.

## Conteos

| Inventario | Antes | Despues |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 | 198 / 0 | 198 / 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | 5 | 5 (sin cambio) |
| Casos de replay `QACaseV2` | 5 | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 4 | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` | 1 | **2** |
| Certificaciones frescas de oracle en este turno | — | 1 |

Los cinco fixtures de paridad siguen sin contar para las 198 obligaciones
Architecture V2.

## Proximo paso recomendado

Con dos dominios de comportamiento distintos ya certificados en vivo
(corpse de monstruo y reacquisicion de objetivo) y las herramientas genericas
probadas contra ambos sin cambios, Phase 2 puede seguir con un tercer dominio
de paridad, o abrir como linea propia la deuda de `protocolo-red` descrita
arriba y la investigacion del desalineamiento de mapa `0x64`.
