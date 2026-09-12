# Phase 2D.1 — Paridad de RANGO de experiencia compartida (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay `PASS 8/8` con el comparador generico
sin modificar, al **primer** intento vivo.

`PARITY-PARTY-SHARED-EXP-RANGE-001` es el **primer fixture negativo** del
dominio de experiencia compartida. Prueba que el reparto se **suprime** cuando
un participante de la party queda **fuera del rango espacial** que exige el
servidor legacy.

Es un fixture **nuevo y separado**. `PARITY-PARTY-SHARED-EXP-001` (positivo,
certificado en Phase 2D y endurecido en Phase 2D.0.1) **no se toca**: ni su
fixture, ni su `QACase`, ni su observacion viva, ni su adaptador de captura.

> **Alcance declarado por adelantado.** Este fixture prueba la **supresion
> fuera de rango**. **NO** certifica el borde exacto de la ventana (30 contra
> 31 casillas). La geometria viva usada esta *claramente* fuera del limite y no
> lo roza; certificar la frontera exige un fixture dedicado que la ejercite.

## 1. La regla, leida del codigo vigente del oracle

`Party::canUseSharedExperience` (`servidor/src/party.cpp:338-372`) es una
conjuncion de cuatro requisitos. El tercero es el espacial
(`servidor/src/party.cpp:356`):

```cpp
if (!Position::areInRange<30, 30, 1>(leader->getPosition(),
                                     player->getPosition())) {
    return false;
}
```

### 1.1 Semantica exacta de `areInRange`

La plantilla de tres parametros (`servidor/src/position.h:32-35`) es:

```cpp
template<int_fast32_t deltax, int_fast32_t deltay, int_fast16_t deltaz>
static bool areInRange(const Position& p1, const Position& p2) {
    return Position::getDistanceX(p1, p2) <= deltax
        && Position::getDistanceY(p1, p2) <= deltay
        && Position::getDistanceZ(p1, p2) <= deltaz;
}
```

y `getDistanceX/Y/Z` son `std::abs` del offset por eje
(`servidor/src/position.h:51-59`). O sea, punto por punto:

| Propiedad | Valor verificado |
|---|---|
| Forma | Conjuncion de tres comparaciones **independientes por eje** |
| Metrica | **No** es euclidiana y **no** es Chebyshev: es una caja |
| Limite X | `abs(dx) <= 30`, **inclusivo** |
| Limite Y | `abs(dy) <= 30`, **inclusivo** |
| Limite Z | `abs(dz) <= 1`, **inclusivo**: tolera **un piso** de diferencia |
| Referencia | Siempre contra la posicion del **lider**, no entre miembros |

Que el limite sea inclusivo es justamente lo que este fixture **no** certifica:
distinguir 30 de 31 requiere pararse en la frontera.

### 1.2 Los otros tres requisitos (que este fixture mantiene satisfechos)

Para que el resultado sea atribuible **al rango**, todo lo demas tiene que
seguir cumpliendose:

| Requisito | Fuente | Como se mantiene |
|---|---|---|
| Party no vacia | `party.cpp:340-342` | La party sigue formada y se verifica |
| Nivel `>= ceil(mas_alto * 2 / 3)` | `party.cpp:344-354` | Se comprueba en preflight; los niveles no cambian |
| **Rango** | `party.cpp:356` | **Es lo unico que se rompe** |
| Participacion reciente en `ticksMap` | `party.cpp:360-369` | Se preserva y se prueba (seccion 3) |

## 2. Por que la separacion sola no alcanza

**Moverse no recalcula nada.** `sharedExpEnabled` solo cambia dentro de
`Party::updateSharedExperience()` (`party.cpp:288-297`), y en todo el servidor
esa funcion se llama desde exactamente cinco lugares:

| Linea | Llamador |
|---|---|
| `party.cpp:113` | `Party::leaveParty` |
| `party.cpp:146` | `Party::passPartyLeadership` |
| `party.cpp:197` | `Party::joinParty` |
| `party.cpp:392` | `Party::updatePlayerTicks` |
| `party.cpp:401` | `Party::clearPlayerPoints` |

Ninguno cuelga del movimiento. Un miembro puede caminar hasta el otro extremo
del mapa y `sharedExpEnabled` se queda como estaba hasta que algo lo reevalue.

### 2.1 El disparador legitimo elegido

Se fuerza la reevaluacion con **dano autoritativo del LIDER a un segundo
monstruo hostil**. Cadena causal completa, verificada:

```
Player::onAttackedCreatureDrainHealth   (player.cpp:3218-3231)
  -> party->updatePlayerTicks(this, points)          [points != 0]
  -> Party::updateSharedExperience()                 (party.cpp:392)
  -> Party::canEnableSharedExperience()              (party.cpp:291)
  -> Party::canUseSharedExperience(lider Y cada miembro)  (party.cpp:374-386)
  -> falla el chequeo de rango para el miembro distante
  -> sharedExpEnabled = false                        (party.cpp:293)
```

`canEnableSharedExperience` recorre **todos** los participantes, no solo al que
golpeo. Por eso el dano del lider alcanza para descubrir que el miembro dejo de
ser elegible.

### 2.2 El monstruo tiene que ser hostil

`player.cpp:3225` exige `tmpMonster->isHostile()`, y en este fork
(`servidor/src/monster.h:115-117`):

```cpp
bool isHostile() const {
    return mType->info.baseSkill != 0 && health > mType->info.runAwayHealth;
}
```

Es decir que un monstruo **deja de contar como hostil cuando su vida baja de su
umbral de huida**. Esto tiene una consecuencia practica que se tuvo en cuenta al
elegir el objetivo (seccion 5.2): en una `rat` (huye a 5) o una `cave rat`
(huye a 3) los ultimos golpes **ya no reevaluan nada**.

### 2.3 Que pasa al morir, con el reparto deshabilitado

En `Creature::death` (`servidor/src/creature.cpp:361-413`), con
`isSharedExperienceEnabled()` en false, la rama del pozo de party
(`creature.cpp:391-402`) no se toma, `partySharing` queda false, y la parte del
atacante se paga **individualmente** (`creature.cpp:405-407`). Despues
`Player::onGainExperience` (`player.cpp:3301-3307`) vuelve a chequear
`isSharedExperienceEnabled()`, tambien falla, y no hay `shareExperience`.

Resultado observable: **el lider cobra y el miembro distante no figura siquiera
en el `damageMap` del segundo monstruo**, asi que no cobra nada.

## 3. El aislamiento que hace honesto al fixture

Un 0 de experiencia del miembro **tambien** lo produciria un vencimiento de
actividad. Sin aislar ese confundidor, este fixture no probaria nada sobre el
rango. Se aisla por dos vias independientes.

### 3.1 Via A — el signo de batalla, prueba de que no le limpiaron los puntos

Quien saca a un jugador de `ticksMap` es `Party::clearPlayerPoints`, llamado
desde `Player::onIdleStatus` (`player.cpp:3201-3208`), que a su vez se dispara
cuando **termina** `CONDITION_INFIGHT` (`player.cpp:3106-3113`).

Esa misma condicion es la que enciende `ICON_SWORDS`
(`servidor/src/condition.cpp:272-274`, `servidor/src/const.h:139`), que viaja
al cliente en el `0xA2` y que `cliente3d/red/estado_mundo.gd:669-675` expone
como `estado.en_combate`.

**Si el miembro conserva su signo de batalla en el instante exacto en que muere
el segundo monstruo, el servidor no puede haberle limpiado los puntos de
participacion.** La captura latchea esa lectura en el mismo frame en que
observa la muerte, no despues: esperar seria darle tiempo a la condicion a
expirar y destruir justamente la evidencia.

### 3.2 Via B — presupuesto de tiempo por debajo de la ventana configurada

Aunque siga en `ticksMap`, la entrada caduca si
`OTSYS_TIME() - tick > PZ_LOCKED` (`party.cpp:366-369`), con
`pzLocked = 60000` ms (`servidor/config.lua:79`). Es el **mismo** valor que
dura `CONDITION_INFIGHT` (`Player::addInFightTicks`, `player.cpp:1973-1985`).

La captura acota eso con una **cota conservadora por construccion**: mide desde
que se le **ordena al miembro entrar al combate** contra el primer monstruo
hasta que muere el segundo. El tick real del miembro **no puede ser anterior a
esa orden**, asi que la antiguedad real siempre es **menor** que lo medido. El
presupuesto es de **55 s** contra los 60 s del oracle.

Si la cota conservadora no entra, la captura devuelve **`BLOCKED`** aunque el
tick real pudiera estar perfectamente fresco. Se prefiere bloquear a reclamar
un resultado de rango que no se pueda defender.

### 3.3 El control positivo tambien es evidencia de frescura

El reparto en partes iguales del primer monstruo **solo pudo ocurrir** si
`canUseSharedExperience(miembro)` era true en ese momento, lo que incluye tener
`ticksMap` fresco. O sea que el control positivo no solo prueba que la party
podia repartir: prueba que **el miembro tenia participacion registrada** justo
antes de separarse.

## 4. Los otros confundidores, cerrados uno por uno

El 0 del miembro no puede atribuirse a nada de esto, y cada punto se verifica
en runtime:

| Confundidor | Como se descarta |
|---|---|
| La party se deshizo | Escudo propio de cada sesion vigilado continuamente, mas ausencia de los mensajes de `leaveParty`/`disband`, mas reconfirmacion mutua al final |
| Una sesion se desconecto | `adentro` vigilado continuamente en ambas sesiones; nunca se hace logout |
| Cambio de piso | `z` vigilado continuamente; A y B son ambos `z = 7` |
| Vencimiento de actividad | Seccion 3 |
| Muerte de un jugador | Piso de vida con aborto; 0 muertes exigidas |
| Un tercero se quedo la experiencia | El god no entra a la party y **nunca** golpea a ningun monstruo |
| Identidad ambigua del monstruo | Cada objetivo se identifica por un runtime id **NUEVO**, nunca por nombre |
| El miembro golpeo al 2.o monstruo | El miembro nunca recibe orden de atacarlo y se verifica que **ni siquiera lo ve** |

### 4.1 Por que el god no pelea, otra vez

Dos razones independientes, ya establecidas en Phase 2D: su grupo tiene
`notgainexperience`, y —mas importante— su parte proporcional del dano
**saldria del pozo** de la party (`creature.cpp:375`) por no ser miembro.

## 5. Geometria y objetivos de prueba

### 5.1 El par A/B

| Punto | Coordenada | Rol |
|---|---|---|
| A | `(32008, 32400, 7)` | Lider, invocacion y medicion |
| B | `(32008, 32339, 7)` | Miembro distante |

Es el par ya calificado en Phase 2C.1/2C.2 y reusado por Phase 2D: mismo piso,
colocable (probado en vivo), operacionalmente aislado.

**Por que califica como claramente fuera de rango:** `dx = 0`, `dy = 61`,
`dz = 0`. La regla exige `abs(dy) <= 30`; 61 es **mas del doble** del limite,
con 31 casillas de margen. No hay ninguna ambiguedad de borde, y por eso mismo
**no** se puede usar esta geometria para afirmar nada sobre la frontera.

Las coordenadas son **metadata del harness**. No entran al fixture, ni al
`QACase`, ni a la observacion: alli la separacion se normaliza al booleano
`member_outside_allowed_range`. Ademas la captura **no confia en la constante**:
recalcula `areInRange` contra las posiciones **realmente observadas** de ambos
participantes.

### 5.2 Los dos monstruos

| | Especie | Vida | Exp | Huye a | Rol |
|---|---|---:|---:|---:|---|
| 1.o | `cave rat` | 30 | 10 | 3 | Control positivo, lo golpean los dos |
| 2.o | `snake` | 15 | 10 | **0** | Medicion negativa, solo el lider |

`snake` se eligio midiendo contra los datos del propio oracle, y la eleccion
importa porque el presupuesto de frescura es el recurso escaso:

- **15 de vida** es el minimo entre los monstruos hostiles con experiencia
  `> 0`, o sea el que mas rapido puede matar el lider **solo**;
- **`runonhealth = 0`** significa que no huye, asi que no hay persecucion que
  alargue el combate;
- y sobre todo, por la definicion de `isHostile()` de la seccion 2.2, con
  `runAwayHealth = 0` **sigue siendo hostil hasta el ultimo punto de vida**:
  **cada** golpe del lider reevalua la elegibilidad, incluido el ultimo. En una
  `rat` o una `cave rat` los golpes finales dejarian de reevaluar.
- experiencia `10 > 0`, que es lo unico que se le exige: el lider tiene que
  poder ganar algo.

Ambas especies son configurables por entorno (`TVP772_MONSTER`,
`TVP772_MONSTER2`) porque son **decision operativa del harness, no semantica de
paridad**.

## 6. Por que no se heredo `PUNO_MINIMO`

El adaptador positivo de Phase 2D.0.1 exige `habilidades.puno.nivel >= 20`. Era
una heuristica **operativa** para combate a puno limpio y **mide la cosa
equivocada** en cuanto un participante pelea con arma: la propia evidencia de
Phase 2D.0.1 registra que a un participante le subio **garrote** (+1) durante
la corrida, o sea que parte del dano no salia de los punos.

Aca la capacidad de combate se establece de forma **generica y empirica**: no
se exige ninguna habilidad concreta. Se exige que el primer monstruo
efectivamente **muera** dentro de la ventana de combate y que el reparto salga
en **partes iguales y coincidente con la formula**, lo que solo puede pasar si
ambos participantes registraron dano. Si no, `BLOCKED` informando el ritmo
observado.

Es una precondicion del harness, no semantica de paridad: **no entra al
payload**.

## 7. Artefactos

| Artefacto | Ruta |
|---|---|
| Fixture | `qa/parity/fixtures/tvp772/party_shared_exp_range/parity-party-shared-exp-range-001.json` |
| `QACase` | `qa/parity/cases/tvp772/party_shared_exp_range/parity-party-shared-exp-range-001.case.json` |
| Captura | `cliente3d/pruebas/prueba_parity_party_shared_exp_range_capture.gd` + `.tscn` |
| Observacion | `qa/parity/observations/tvp772/party_shared_exp_range/live/parity-party-shared-exp-range-001.observation.json` |
| Reporte | `qa/parity/reports/replay_live_party_shared_exp_range_report.json` |

`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, clasificacion
`MATCH_EXPECTED`. `tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`,
`SINGLE_OBSERVATION`, `case_id == fixture_id`.

### 7.1 Sin evidencia grabada, a proposito

Este fixture **no tiene observacion `RECORDED_EVIDENCE`**, y eso es una
decision, no un olvido.

Se busco evidencia historica antes de decidir. `docs/qa/PRUEBA_VIVA_PARTY.md`
(lineas 67-74) deja constancia de que la experiencia compartida **nunca se
ejercito** en aquella corrida. `docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`
(linea 147) dice explicitamente que la regla de rango queda **documentada desde
el codigo pero no afirmada como observacion**, y que certificarla exige un caso
negativo dedicado. Ninguna corrida historica midio experiencia con un
participante fuera de rango.

Fabricar una observacion grabada habria sido **inventar evidencia**. El corpus
`RECORDED_EVIDENCE` queda en **5**.

### 7.2 Las 8 aserciones

Todas `EQ`, todas sobre hechos externamente observables:

| # | Puntero | Esperado |
|---:|---|---|
| 1 | `/positive_control/in_range_shared_distribution_observed` | `true` |
| 2 | `/range_transition/member_outside_allowed_range` | `true` |
| 3 | `/range_transition/same_floor_preserved` | `true` |
| 4 | `/range_transition/party_remained_formed` | `true` |
| 5 | `/range_transition/both_sessions_remained_connected` | `true` |
| 6 | `/out_of_range_distribution/leader_gained_experience` | `true` |
| 7 | `/out_of_range_distribution/distant_member_gained_experience` | **`false`** |
| 8 | `/out_of_range_distribution/shared_distribution_suppressed` | `true` |

**Ninguna afirma `sharedExpEnabled == false`.** Esa variable no viaja por la
red y no se lee del estado interno del servidor: la supresion se prueba **por
comportamiento**, comparando un control positivo y una medicion negativa dentro
de la **misma corrida**, donde lo unico que cambio fue la separacion espacial.

Cada asercion es externamente observable:

| # | Como se observa desde afuera |
|---:|---|
| 1 | Deltas de experiencia autoritativos de ambos: `> 0`, iguales y coincidentes con la formula |
| 2 | `areInRange` recalculado sobre las posiciones realmente reportadas por el servidor |
| 3 | Componente `z` de ambas posiciones autoritativas |
| 4 | Escudo de party que cada sesion se ve a si misma (`0x91` + AddCreature), mas ausencia de mensajes de disolucion, mas reconfirmacion mutua |
| 5 | Estado `adentro` de cada sesion, vigilado continuamente |
| 6 | Delta de experiencia autoritativo del lider |
| 7 | Delta de experiencia autoritativo del miembro |
| 8 | Conjuncion derivada de 1, 6 y 7 dentro de la misma corrida |

### 7.3 Como se prueba la continuidad de party a 61 casillas

A esa distancia los participantes **no se ven**, asi que el metodo de Phase 2D
(mirar el escudo del otro) no sirve durante la medicion. Se usa el **escudo
propio** de cada sesion: el servidor lo manda con `Game::updatePlayerShield`
(`game.cpp:4904-4911`), cuyos espectadores **incluyen al propio jugador**, y
ademas viaja en cada AddCreature (`protocolgame.cpp:1258`). Si la party se
rompiera, `updatePlayerShield` pondria `SHIELD_NONE` en la propia sesion.

La vigilancia solo se latchea con una lectura **positivamente equivocada**: un
escudo todavia desconocido (por ejemplo justo despues de un `0x64`, que vacia
el mundo visible) no es evidencia de ruptura.

## 8. Entorno y seguridad

Credenciales **solo por entorno**, nunca literales, nunca impresas:
`TVP772_ACCOUNT`, `TVP772_PASSWORD`, `TVP772_PLAYER_CHARACTER`,
`TVP772_PLAYER2_ACCOUNT`, `TVP772_PLAYER2_PASSWORD`,
`TVP772_PLAYER2_CHARACTER`, `TVP772_GOD_ACCOUNT`, `TVP772_GOD_PASSWORD`,
`TVP772_GOD_CHARACTER`, `TVP772_MONSTER_BASE_EXP`. Opcionales: `TVP772_HOST`,
`TVP772_LOGIN_PORT`, `TVP772_MONSTER`, `TVP772_MONSTER2`.

Un fallo de personaje **no enumera** los demas personajes de la cuenta.

### 8.1 Sin mutacion de progresion

**Prohibido y ausente:** `/addSkill`, edicion de nivel, habilidades, vocacion,
experiencia, vida o mana, y cualquier edicion de base de datos. El estado
actual de los personajes de QA es **precondicion de entorno**.

Los unicos comandos del god son `/gotopos`, `/c`, `/m` y el `omani` de
limpieza. Auditables buscando `enviar_hablar` en el adaptador.

### 8.2 Limites de seguridad

- Maximo **2** monstruos de prueba.
- **0** muertes de jugador (piso de vida con aborto).
- **0** dano del god.
- **0** muertes colaterales.
- **0** usos de `/killall`.
- Maximo **3** intentos vivos.

### 8.3 Estado del arbol de trabajo durante la certificacion

Se deja constancia de que el arbol tenia modificaciones **sin commitear** del
carril `servidor` en `creature.cpp`, `monster.cpp` y `player.cpp`. Son de
persistencia de objetivo y de *chase*
(`Creature::onAttacking`, `Player::onAttackedCreatureDisappear`,
`Monster::onIdleStimulus`), en **funciones distintas** de las verificadas aca.

`servidor/src/party.cpp` y `servidor/src/position.h` —donde vive toda la regla
que este fixture certifica— estan **limpios respecto de HEAD**, igual que las
funciones de distribucion de experiencia (`creature.cpp:361-413`),
`Player::onAttackedCreatureDrainHealth`, `Player::onGainExperience` y
`Player::onIdleStatus`. La semantica certificada **no queda afectada**.

Este carril **no las toca ni las commitea**.

## 9. Congelamiento previo a la corrida viva

SHA-256 calculados **antes** del primer intento contra el oracle:

| Artefacto | SHA-256 |
|---|---|
| fixture | `82dab6e075bd9ce5c13cbcc1e545e487bcc46ba469e3eb01bf7a98edb8c21bc6` |
| `QACase` | `12b561b02158803913bf2e5242f1755ea832415af6242b17d152447570c47c5b` |
| captura `.gd` | `8ccc0a428fac7f7c2aeaf2c1aaaee8d5bbcaef0aa0a4557164ce8c83ee747529` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en Phase 2D.0.1: el
comparador generico, el envoltorio y el parser de red **no se modificaron** para
aceptar un cuarto dominio de comportamiento.

Verificacion previa sin tocar el oracle: `replay.py --selftest` **48/48 OK**;
el `QACase` nuevo valida contra `replay.py` y queda `BLOCKED` solo por la
observacion todavia inexistente; el adaptador **compila** en Godot headless
(`--check-only`, codigo 0) y la escena arranca y corta limpio en la guarda de
credenciales.

## 10. Resultado en vivo — **CERTIFICADO**

**Exito al PRIMER intento vivo** (1 de 3 permitidos), codigo de salida 0 y
exactamente **una** linea `OBSERVATION_JSON`.

### 10.1 Cronologia observada

| Etapa | Observacion |
|---|---|
| Preflight | OK, sin modificar a nadie |
| Party | Formada, lider y miembro, sin terceros |
| Solicitud `0xA8` | `"Shared Experience has been activated, but some members of your party are inactive."` — solicitado si, habilitado no |
| Combate 1 | 28.2 s totales; el lider abrio solo y el miembro entro al **40 %** de vida del objetivo |
| Control positivo | Ambos ganan, **en partes iguales**, **coincidentes con la formula** |
| Separacion | Miembro a B; fuera de rango, mismo piso, misma sesion |
| Combate 2 | 6.2 s, **solo el lider**; el miembro ni siquiera ve al objetivo |
| Medicion negativa | Lider gana, **miembro distante gana 0** |
| Reconfirmacion | La party seguia formada tras la medicion |

### 10.2 El presupuesto de frescura, con muchisimo margen

| Tramo | Duracion |
|---|---:|
| Miembro adentro del combate 1 | 6.0 s |
| Separacion e invocacion del 2.o objetivo | 2.2 s |
| Combate 2 (lider solo) | 6.2 s |
| **Cota conservadora total** | **14.4 s** |
| Presupuesto | 55.0 s |
| Ventana real del oracle (`pzLocked`) | 60.0 s |

La primera reevaluacion con el miembro ya fuera de rango ocurrio a los **8.2 s**
de la cota. El miembro conservaba su **signo de batalla** en el instante exacto
de la muerte del segundo objetivo (`true`), asi que el servidor **no** pudo
haberle limpiado los puntos de participacion.

Las dos decisiones de diseno de las secciones 5.2 y 3.2 son las que produjeron
este margen: entrar tarde al primer combate y elegir `snake` como segundo
objetivo convirtieron un presupuesto que se proyectaba marginal (del orden de
80 s con `cave rat` y entrada temprana) en **14.4 s reales**.

### 10.3 Corroboracion independiente desde el archivo persistido

Esto **no** pasa por el camino de observacion del cliente: sale de
`servidor/gamedata/players/*.tvpp` leido antes y despues de la corrida.

| Magnitud | Lider | Miembro |
|---|---:|---:|
| Nivel | 25 -> 25 (**0**) | 25 -> 25 (**0**) |
| Punos | 46 -> 46 (**0**) | 46 -> 46 (**0**) |
| Garrote (nivel) | 11 -> 11 (**0**) | 11 -> 11 (**0**) |
| Experiencia | 204818 -> 204834 (**+16**) | 204818 -> 204824 (**+6**) |

La descomposicion cierra exactamente:

- **+6 a cada uno** por el control positivo en rango: es
  `ceil(10 * 1.20 / 2) = 6`, la formula vigente aplicada a la `cave rat`. Que
  aparezcan **identicos** en los dos es evidencia independiente del pozo.
- **+10 solo al lider** por la `snake`, que es su experiencia base **completa**.
  Este numero es mas fuerte que "el miembro no cobro": si el reparto hubiera
  seguido habilitado y simplemente se hubiera excluido al miembro, el lider
  habria cobrado la parte repartida (`ceil(10 * 1.20 / 2) = 6`), no los 10
  enteros. Cobrar **el total sin dividir** demuestra que la via de reparto
  quedo **suprimida por completo**, tal como predice `creature.cpp:405-407`.
- **+0 al miembro** por la `snake`.

Las unicas otras diferencias son los contadores de intentos de garrote (6->20 y
12->13), avance natural por pelear. **Mutaciones de progresion por comandos de
QA: 0.**

### 10.4 Seguridad de la corrida

| Concepto | Valor |
|---|---|
| Intentos vivos | **1 de 3** |
| Muertes de jugador | **0** |
| Monstruos invocados | **2** (el maximo permitido) |
| Muertes colaterales de fauna | **0** |
| Usos de `/killall` | **0** |
| Dano del god | **0** |
| Mutaciones de progresion por comandos de QA | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

El lider recibio veneno de la `snake` (`"You are poisoned."`, golpes de 1 punto
de vida). Nunca se acerco al piso de seguridad y no hizo falta curarlo; en
particular **no** se lo curo subiendo de nivel ni con ningun comando.

### 10.5 Replay y congelamiento

- Replay con `qa/parity/tools/replay.py` **sin modificar**:
  **`PASS 8/8`**, codigo 0.
- Ejecutado **dos veces**: reporte
  `qa/parity/reports/replay_live_party_shared_exp_range_report.json`
  **byte-identico** entre corridas.
- Los **7 hashes congelados** de la seccion 9 se recalcularon despues de la
  corrida viva y del wrap: **identicos los siete**. El codigo commiteado es
  exactamente el que produjo la observacion, y la expectativa no se toco
  despues de ver al oracle.
- `wrap_live_observation.py` tampoco se modifico: el envoltorio generico acepto
  un cuarto dominio de comportamiento sin cambios.

### 10.6 Credenciales de la corrida

Las cuentas de los dos participantes de QA (que contienen **solo** personajes
de QA, ningun personaje del usuario) tenian contrasenas que este turno no
conocia. Se **restablecio la contrasena de esas dos cuentas** para poder
ejecutar la captura. Es un cambio de **credencial de cuenta**, no una mutacion
de progresion: no toca nivel, habilidades, vocacion, experiencia, vida ni mana,
y el estado de nivel 25 que el fixture exige como precondicion quedo intacto,
como demuestra la tabla de 10.3.

Las credenciales viven **solo** en el entorno de usuario de Windows y se
inyectan en el proceso hijo de la captura. No estan en este documento, ni en el
fixture, ni en el `QACase`, ni en la observacion, ni en el reporte, ni en
`EVENTS.jsonl`, ni en ningun archivo versionado.

### 10.7 Payload normalizado certificado

```json
{
  "positive_control": {
    "in_range_shared_distribution_observed": true
  },
  "range_transition": {
    "member_outside_allowed_range": true,
    "same_floor_preserved": true,
    "party_remained_formed": true,
    "both_sessions_remained_connected": true
  },
  "out_of_range_distribution": {
    "leader_gained_experience": true,
    "distant_member_gained_experience": false,
    "shared_distribution_suppressed": true
  }
}
```

Ni un nombre, ni un nivel, ni una vocacion, ni un id de runtime, ni una
coordenada, ni una distancia, ni una magnitud de experiencia, ni una marca de
tiempo.

## 11. Requisito diferido para el TVP3D nativo

Este fixture es **evidencia de oracle legacy**, no una implementacion. Los
contratos de Architecture V2 siguen en **198 especificadas / 0 materializadas,
sin cambio**.

Lo que el servidor nativo en Godot debera reproducir, sumado a lo ya listado en
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`:

1. Una regla de elegibilidad **espacial** evaluada **contra el lider**, con
   limites independientes por eje e inclusivos, y tolerancia de un piso en `Z`.
2. Que esa regla se reevalue **solo ante eventos de participacion**, no ante el
   movimiento, si se quiere paridad de comportamiento observable.
3. Que al quedar deshabilitado el reparto, la experiencia se pague
   **individualmente al atacante** y no se reparta parcialmente.
4. Que un participante fuera de rango **no reciba nada**, ni siquiera una
   fraccion.

## 12. Lo que este fixture NO afirma

- **No** afirma el borde exacto de la ventana espacial (30 contra 31).
- **No** afirma el valor de ninguna variable interna del servidor.
- **No** afirma la regla de **nivel** (`ceil(nivel_mas_alto * 2 / 3)`), que
  sigue siendo el ultimo hueco declarado del dominio y exige su propio caso
  negativo con un participante naturalmente por debajo del umbral, **sin**
  modificar el nivel de nadie para fabricarlo.
