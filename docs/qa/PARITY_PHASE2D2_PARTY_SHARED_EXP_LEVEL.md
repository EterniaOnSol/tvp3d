# Phase 2D.2 — Paridad de NIVEL de experiencia compartida (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay `PASS 8/8` con el comparador generico
sin modificar, al **primer** intento vivo.

`PARITY-PARTY-SHARED-EXP-LEVEL-001` es el **segundo fixture negativo** del
dominio de experiencia compartida y el **ultimo hueco declarado** de
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md` (linea 146-149). Prueba que el
reparto se **suprime** cuando un participante de la party esta por debajo del
nivel minimo que exige el servidor legacy.

Es un fixture **nuevo y separado**. `PARITY-PARTY-SHARED-EXP-001`,
`PARITY-PARTY-SHARED-EXP-RANGE-001` y `PARITY-PARTY-LIFECYCLE-001` **no se
tocan**: ni sus fixtures, ni sus `QACase`, ni sus observaciones, ni sus
reportes, ni sus adaptadores.

> **Alcance declarado por adelantado.** Este fixture prueba la **supresion por
> nivel insuficiente**. **NO** certifica el borde exacto del umbral (un
> participante justo en `minLevel` contra otro justo por debajo). El
> participante bajo esta muy por debajo del minimo y no lo roza; certificar la
> frontera exige un fixture dedicado y, sin manipular progresion, participantes
> cuyos niveles caigan naturalmente ahi.

## 1. La regla, leida del codigo vigente del oracle

`Party::canUseSharedExperience` (`servidor/src/party.cpp:338-372`) es una
conjuncion de cuatro requisitos. El segundo es el de nivel
(`servidor/src/party.cpp:344-354`):

```cpp
uint32_t highestLevel = leader->getLevel();
for (Player* member : memberList) {
    if (member->getLevel() > highestLevel) {
        highestLevel = member->getLevel();
    }
}

uint32_t minLevel = static_cast<uint32_t>(std::ceil((static_cast<float>(highestLevel) * 2) / 3));
if (player->getLevel() < minLevel) {
    return false;
}
```

### 1.1 Semantica exacta, punto por punto

| Propiedad | Valor verificado |
|---|---|
| Referencia | `highestLevel` = **maximo** entre el lider y **todos** los miembros |
| Aritmetica | `float(highestLevel) * 2 / 3` y despues `std::ceil`: **no** es division entera |
| Redondeo | Hacia **arriba**. Con `highestLevel = 25`: `ceil(16.666...) = 17`, **no** 16 |
| Comparacion | **Estricta** (`<`): un participante exactamente en `minLevel` **si** es elegible |
| Alcance | `canEnableSharedExperience` (`party.cpp:374-386`) exige `true` para el lider **y** para cada miembro: basta que **uno** falle |

Que la aritmetica sea de punto flotante con `ceil` y no division entera importa
y se verifico a proposito: con division entera el minimo para 25 seria 16, y un
participante de nivel 16 quedaria mal clasificado.

### 1.2 Los otros tres requisitos (que este fixture mantiene satisfechos)

Para que el resultado sea atribuible **al nivel**, todo lo demas tiene que
seguir cumpliendose:

| Requisito | Fuente | Como se mantiene |
|---|---|---|
| Party no vacia | `party.cpp:340-342` | La party sigue formada y se verifica de forma continua |
| **Nivel** `>= ceil(mas_alto * 2 / 3)` | `party.cpp:344-354` | **Es lo unico que se rompe** |
| Rango `areInRange<30,30,1>` | `party.cpp:356` | Los dos se quedan en el **mismo** punto operativo toda la corrida |
| Participacion reciente en `ticksMap` | `party.cpp:360-369` | Se establece con los **dos** danando al primer monstruo y se prueba (seccion 3) |

## 2. Por que hace falta forzar una reevaluacion

`Party::updateSharedExperience()` (`party.cpp:288-297`) tiene exactamente cinco
llamadores en todo el servidor (`party.cpp` 113, 146, 197, 392, 401) y ninguno
cuelga del movimiento ni de un temporizador. La reevaluacion se fuerza con
**dano autoritativo del participante de nivel ALTO a un segundo monstruo
hostil**:

```
Player::onAttackedCreatureDrainHealth   (player.cpp:3218-3231)
  -> party->updatePlayerTicks(this, points)          [points != 0]
  -> Party::updateSharedExperience()                 (party.cpp:392)
  -> Party::canEnableSharedExperience()              (party.cpp:374)
  -> Party::canUseSharedExperience(lider Y cada miembro)
  -> falla el chequeo de NIVEL para el participante bajo
  -> sharedExpEnabled permanece false                (party.cpp:293)
```

El monstruo tiene que ser **hostil**: `player.cpp:3225` exige
`tmpMonster->isHostile()`, y en este fork (`servidor/src/monster.h:115-117`)
`isHostile()` es `baseSkill != 0 && health > runAwayHealth`.

## 3. El aislamiento que hace honesto al fixture

Un 0 de experiencia del participante bajo tambien lo produciria cualquiera de
los otros tres requisitos. Cada uno se cierra de forma explicita.

### 3.1 Participacion: probada por la ganancia individual, no supuesta

Los **dos** participantes danan al primer monstruo de prueba y se exige que los
**dos** cobren experiencia por el.

Eso es prueba **autoritativa** de participacion registrada, no una inferencia:
solo entra al reparto de `Creature::death` (`creature.cpp:368-407`) quien figura
en el `damageMap` con dano positivo, y **ese mismo evento de dano** es el que
llama a `Party::updatePlayerTicks` (`player.cpp:3227`). Si cobro, daño; si daño,
tiene entrada en `ticksMap`.

### 3.2 El primer monstruo tambien prueba que el pozo NO estaba operando

Con el reparto habilitado los dos cobrarian `ceil(exp * 1.20 / 2)` y la suma
seria `exp * 1.20`, **estrictamente mayor** que la experiencia base del
monstruo. Con pago individual proporcional
(`cb.total * experience / totalCombatDamageReceived`) la suma **nunca** puede
pasar la base. La captura verifica las dos cosas y aborta si el pozo aparece.

### 3.3 Frescura: signo de batalla latcheado + presupuesto de tiempo

Quien saca a un jugador de `ticksMap` es `Party::clearPlayerPoints`, llamado
**unicamente** desde `Player::onIdleStatus` (`player.cpp:3201-3208`) cuando
**termina** `CONDITION_INFIGHT`. Esa misma condicion enciende `ICON_SWORDS`
(`condition.cpp:272-274`, `const.h:139`), que viaja en el `0xA2` y que
`cliente3d/red/estado_mundo.gd` expone como `estado.en_combate`.

La captura **latchea** esa lectura en el mismo frame en que observa la muerte
del segundo objetivo. Ademas acota la antiguedad del tick con una cota
**conservadora por construccion**: mide desde que se ordena a **ambos** atacar
al primer monstruo hasta que muere el segundo. El tick real no puede ser
anterior a esa orden. Presupuesto **55 s** contra los **60 s** de `pzLocked`
(`servidor/config.lua:79`, `party.cpp:366-369`). Si no entra, **`BLOCKED`**.

### 3.4 Rango: control, no variable

Los dos participantes se quedan en el **mismo punto operativo** durante toda la
corrida. `areInRange<30,30,1>` se recalcula sobre las posiciones **realmente
reportadas** y se vigila de forma continua; si alguna vez deja de cumplirse, la
captura aborta en vez de declarar un resultado de nivel. A diferencia de Phase
2D.1, aca la geometria **nunca se estresa**.

### 3.5 Los demas confundidores

| Confundidor | Como se descarta |
|---|---|
| La party se deshizo | Escudo propio de cada sesion vigilado continuamente, ausencia de mensajes de `leaveParty`/`disband`, reconfirmacion mutua al final |
| Una sesion se desconecto | `adentro` vigilado continuamente; nunca se hace logout |
| Cambio de piso | `z` vigilado continuamente |
| Muerte de un jugador | Piso de vida con aborto; 0 muertes exigidas |
| Un tercero se quedo la experiencia | El god no entra a la party y **nunca** golpea a ningun monstruo |
| Identidad ambigua del monstruo | Cada objetivo se identifica por un runtime id **NUEVO**, nunca por nombre, y se exige que el segundo id sea distinto del primero |
| El participante bajo golpeo al 2.o monstruo | Nunca recibe orden de atacarlo |
| El nivel cambio durante la corrida | Los dos niveles se releen del estado autoritativo **al medir** y se exige que sigan siendo los del preflight |

## 4. La corroboracion fuerte: la magnitud del pago

"El participante bajo cobro 0" por si solo es evidencia debil. La evidencia
fuerte es **cuanto** cobro el alto por el segundo monstruo:

- con el reparto **suprimido**, el unico atacante cobra el pago individual
  **completo** (`creature.cpp:405-407`; con un solo atacante,
  `cb.total == totalCombatDamageReceived`, asi que cobra la experiencia base
  entera);
- si el reparto estuviera **habilitado** y simplemente excluyera al bajo, el
  alto cobraria `ceil(exp * 1.20 / 2)` (`servidor/data/events/scripts/party.lua`
  lineas 24-47), es decir una **fraccion**.

Los dos numeros son distintos y se comparan en tiempo de captura contra los
datos del propio oracle. **Ninguno se congela en el fixture.**

Se verifico ademas que el multiplicador de stage no interfiere:
`servidor/data/XML/stages.xml` tiene `<config enabled="0" />` y
`servidor/config.lua:243` tiene `rateExp = 1`, asi que
`Game.getExperienceStage(level)` devuelve 1 para **todos** los niveles y el pago
individual es la experiencia base sin escalar. Esto importa justamente porque
los dos participantes estan en niveles muy distintos.

## 5. Identidades de QA: que se reuso y que NO se provisiono

El usuario autorizo **explicitamente** en este turno crear cuentas y personajes
de QA dedicados si hiciera falta. **No hizo falta.**

| Rol | Que se uso | Origen de su nivel |
|---|---|---|
| `QA_LEVEL_HIGH` (lider) | Participante de QA ya existente, de nivel alto, en una cuenta que contiene **solo** personajes de QA | Progresion natural de las corridas de Phase 2D/2D.0.1/2D.1; **no se toco en este turno** |
| `QA_LEVEL_LOW` (miembro) | Personaje de QA ya existente que **nunca entro al mundo** | **Estado de creacion normal del perfil**, sin ninguna modificacion |
| `QA_GOD_OPERATOR` | God operador, fuera de la party | No participa |

### 5.1 Por que el nivel del participante bajo es genuinamente "de fabrica"

El personaje reusado como `QA_LEVEL_LOW` **no tiene archivo de estado** bajo
`servidor/gamedata/players/`. Cuando un personaje no tiene archivo propio,
`IOLoginData::loadPlayer` (`servidor/src/iologindata.cpp:208-236`) carga la
plantilla `gamedata/players/male.dat` / `female.dat`, que es literalmente el
**estado de creacion** de este perfil TVP:

```
Level = 1
Experience = 0
Health = 150
MaxHealth = 150
Stamina = 2530
Skill = (0..6, 10, 0)
```

No se le subio ni se le bajo nada. **Provisionar un personaje nuevo habria dado
exactamente este mismo estado**, asi que crear uno mas habria agregado basura al
entorno sin cambiar la evidencia.

`Stamina = 2530 > 0` importa y se verifico a proposito: `Player::gainExperience`
(`player.cpp:3292-3298`) devuelve temprano si `staminaMinutes == 0`, asi que un
participante sin stamina no podria ganar experiencia **por un motivo distinto
del nivel** y contaminaria el fixture.

### 5.2 Que NO se hizo

- **0** usos de `/addSkill`.
- **0** mutaciones de nivel, habilidades, magia, vocacion, vida, mana o
  experiencia por comando administrativo.
- **0** ediciones de base de datos (ni de esquema, ni de filas existentes, ni de
  filas nuevas).
- **0** cuentas creadas, **0** personajes creados.
- **0** cambios de credenciales.
- **0** personajes del usuario tocados. Las dos cuentas usadas contienen
  **unicamente** personajes de QA, verificado agrupando `players` por cuenta.

La relacion de nivel es **natural**: el participante bajo esta por debajo del
minimo porque nunca jugo, no porque alguien lo bajara.

## 6. Diseno de dos monstruos

| | Rol | Quien golpea |
|---|---|---|
| 1.o | Establecer participacion legitima de **ambos** | Los **dos** participantes |
| 2.o | Medir la supresion por nivel | **Solo** el participante alto |

La especie elegida para los dos es la misma que Phase 2D.1 califico como segundo
objetivo, y por los mismos motivos medidos contra los datos del oracle, mas uno
nuevo que aca pesa mas:

- **Seguridad del participante de nivel bajo.** Es el monstruo hostil con
  experiencia `> 0` mas debil y mas facil de danar de todo el bestiario
  (15 de vida, ataque 5, habilidad 11, armadura 0, defensa 1). Un personaje de
  nivel 1 puede aportar dano real sin tener que aguantar un combate largo. Se
  reviso el bestiario completo antes de elegir: es el minimo en vida **y** en
  capacidad ofensiva entre los candidatos.
- **Frescura.** `runonhealth = 0`, asi que no huye y, por la definicion de
  `isHostile()`, **sigue siendo hostil hasta el ultimo punto de vida**: cada
  golpe reevalua la elegibilidad, incluido el ultimo.

Las dos especies son configurables por entorno (`TVP772_MONSTER`,
`TVP772_MONSTER2`) porque son **decision operativa del harness, no semantica de
paridad**. La especie **no entra** al payload.

### 6.1 Seguridad del participante de nivel 1

- Piso de vida continuo con aborto (`BLOCKED`/`FAIL`), sin emitir observacion.
- Preflight que exige vida y vida maxima suficientes **con el mismo umbral
  absoluto ya probado** por el adaptador de rango: no se aflojo ningun umbral
  para acomodar a un personaje de nivel 1.
- **Ninguna** curacion por nivel, `/addSkill` ni edicion de base. El combate se
  diseño para que no haga falta.
- El participante bajo solo necesita **dano positivo** contra el primer
  monstruo; no tiene que aguantarlo ni rematarlo.

## 7. Artefactos

| Artefacto | Ruta |
|---|---|
| Fixture | `qa/parity/fixtures/tvp772/party_shared_exp_level/parity-party-shared-exp-level-001.json` |
| `QACase` | `qa/parity/cases/tvp772/party_shared_exp_level/parity-party-shared-exp-level-001.case.json` |
| Captura | `cliente3d/pruebas/prueba_parity_party_shared_exp_level_capture.gd` + `.tscn` |
| Observacion | `qa/parity/observations/tvp772/party_shared_exp_level/live/parity-party-shared-exp-level-001.observation.json` |
| Reporte | `qa/parity/reports/replay_live_party_shared_exp_level_report.json` |

`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, clasificacion
`MATCH_EXPECTED`. `tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`,
`SINGLE_OBSERVATION`, `case_id == fixture_id`. **Sin cambios de schema.**

### 7.1 Sin evidencia grabada, a proposito

Este fixture **no tiene observacion `RECORDED_EVIDENCE`**, y eso es una
decision, no un olvido.

Se busco evidencia historica antes de decidir:

- `docs/qa/PRUEBA_VIVA_PARTY.md` (lineas 67-74) deja constancia de que la
  experiencia compartida **nunca se ejercito** en aquella corrida.
- `docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md` (lineas 146-149) declara
  explicitamente que la regla de **nivel** queda documentada desde el codigo
  pero **no afirmada** como observacion.
- `docs/qa/PARITY_PHASE2D1_PARTY_SHARED_EXP_RANGE.md` (lineas 580-583) repite lo
  mismo y lo deja como el ultimo hueco del dominio.
- Las corridas historicas de Phase 2D mantuvieron a los dos participantes en
  **el mismo nivel** justamente para **no** romper esta regla
  (`PARITY_PHASE2D_PARTY_SHARED_EXP.md:269`).

Ninguna corrida historica midio experiencia con un participante por debajo del
minimo. Fabricar una observacion grabada habria sido **inventar evidencia**. El
corpus `RECORDED_EVIDENCE` queda en **5**.

### 7.2 Las 8 aserciones

Todas `EQ`, todas sobre hechos externamente observables:

| # | Puntero | Esperado |
|---:|---|---|
| 1 | `/level_condition/low_participant_below_required_level` | `true` |
| 2 | `/controls/party_remained_formed` | `true` |
| 3 | `/controls/both_sessions_remained_connected` | `true` |
| 4 | `/controls/within_allowed_range` | `true` |
| 5 | `/controls/both_participants_had_fresh_activity` | `true` |
| 6 | `/level_ineligible_distribution/high_participant_gained_experience` | `true` |
| 7 | `/level_ineligible_distribution/low_participant_gained_experience` | **`false`** |
| 8 | `/level_ineligible_distribution/shared_distribution_suppressed` | `true` |

**Ninguna afirma `sharedExpEnabled == false`.** Esa variable no viaja por la red
y no se lee del estado interno del servidor.

Cada asercion es externamente observable:

| # | Como se observa desde afuera |
|---:|---|
| 1 | Niveles autoritativos de ambos, leidos en el preflight **y** otra vez al medir, contra `ceil(max * 2 / 3)` recalculado |
| 2 | Escudo de party que cada sesion se ve a si misma (`0x91` + AddCreature), ausencia de mensajes de disolucion, reconfirmacion mutua |
| 3 | Estado `adentro` de cada sesion, vigilado continuamente |
| 4 | `areInRange` recalculado sobre las posiciones realmente reportadas, vigilado continuamente |
| 5 | Ganancia individual `> 0` de **ambos** por el primer monstruo + signo de batalla del bajo latcheado + presupuesto de tiempo |
| 6 | Delta de experiencia autoritativo del participante alto |
| 7 | Delta de experiencia autoritativo del participante bajo |
| 8 | Magnitud del pago del alto igual al pago individual **completo**, distinta de la fraccion repartida, junto con el 0 del bajo |

**No se serializa ningun nivel concreto**, ninguna coordenada, ninguna especie
de monstruo y ninguna magnitud de experiencia: solo relaciones.

## 8. Entorno y seguridad

Credenciales **solo por entorno**, nunca literales, nunca impresas:
`TVP772_ACCOUNT`, `TVP772_PASSWORD`, `TVP772_PLAYER_CHARACTER` (rol
`QA_LEVEL_HIGH`), `TVP772_PLAYER2_ACCOUNT`, `TVP772_PLAYER2_PASSWORD`,
`TVP772_PLAYER2_CHARACTER` (rol `QA_LEVEL_LOW`), `TVP772_GOD_ACCOUNT`,
`TVP772_GOD_PASSWORD`, `TVP772_GOD_CHARACTER` (rol `QA_GOD_OPERATOR`),
`TVP772_MONSTER_BASE_EXP`. Opcionales: `TVP772_HOST`, `TVP772_LOGIN_PORT`,
`TVP772_MONSTER`, `TVP772_MONSTER2`, `TVP772_MONSTER2_BASE_EXP`.

Los **nombres** de variable son material permitido; los **valores** no aparecen
en ningun archivo versionado, ni en la observacion, ni en el reporte, ni en
`EVENTS.jsonl`, ni en este documento.

Un fallo de personaje **no enumera** los demas personajes de la cuenta.

### 8.1 Sin mutacion de progresion

**Prohibido y ausente:** `/addSkill`, edicion de nivel, habilidades, vocacion,
experiencia, vida o mana, y cualquier edicion de base de datos. Los unicos
comandos del god son `/gotopos`, `/c`, `/m` y el `omani` de limpieza.
Auditables buscando `enviar_hablar` en el adaptador.

### 8.2 Limites de seguridad

- Maximo **2** monstruos de prueba.
- **0** muertes de jugador (piso de vida con aborto).
- **0** dano del god.
- **0** muertes colaterales.
- **0** usos de `/killall`. Si un monstruo de prueba quedara vivo por un aborto,
  se lo retira por ataque **dirigido a su runtime id**, nunca por area.
- Maximo **3** intentos vivos.

### 8.3 Estado del arbol de trabajo durante la certificacion

Se deja constancia de que el arbol tenia modificaciones **sin commitear** de
otros carriles (`cliente3d/mundo3d.gd`, `cliente3d/propio/monstruos3d/`,
`cliente3d/ui/ranura.gd`, `servidor/src/creature.cpp`,
`servidor/src/monster.cpp`, `servidor/src/player.cpp` y archivos de
`servidor/gamedata/players/`).

`servidor/src/party.cpp` —donde vive toda la regla que este fixture certifica—
esta **limpio respecto de HEAD**. Las modificaciones de `creature.cpp`,
`monster.cpp` y `player.cpp` son las mismas ya declaradas en Phase 2D.1
(persistencia de objetivo y *chase*), en **funciones distintas** de las
verificadas aca. Este carril **no las toca ni las commitea**.

## 9. Congelamiento previo a la corrida viva

SHA-256 calculados **antes** del primer intento contra el oracle:

| Artefacto | SHA-256 |
|---|---|
| fixture | `e56e093c6fcc953ac7067f70de14bab368c815cbf039bf3b68a7f603d07e4df5` |
| `QACase` | `f78995d0ad1647761e4584f8f807c895a88dda77528df6342eeae7d58b325e94` |
| captura `.gd` | `a91b8dd865db12eab0e618cd06a5205876224712c3f0b42912e90e42d21ede04` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en Phase 2D.0.1 y
Phase 2D.1: el comparador generico, el envoltorio y el parser de red **no se
modificaron** para aceptar un quinto dominio de comportamiento.

Verificacion previa sin tocar el oracle: `replay.py --selftest` **48/48 OK, 0
FAIL**; el `QACase` nuevo valida contra `replay.py` y queda `BLOCKED` solo por la
observacion todavia inexistente; el adaptador **compila** en Godot headless
(`--check-only`, codigo 0) y la escena arranca y corta limpio en la guarda de
credenciales (codigo 2, sin contactar al servidor).

### 9.1 Imprecision conocida en un comentario del adaptador congelado

El encabezado del adaptador cita `Party::canEnableSharedExperience` como
`party.cpp:333`. La linea correcta es **374** (`374-386`). Es un **comentario**,
no logica: el codigo verificado es el mismo y ninguna asercion depende de esa
cita.

**No se corrigio**, a proposito. El adaptador se congelo antes de la corrida y
corregirlo ahora romperia la propiedad que da valor al congelamiento: que el
archivo commiteado sea **byte a byte** el que produjo la observacion. Se declara
aca en vez de arreglarlo en silencio, y queda como correccion para el proximo
turno que toque ese archivo por otro motivo.

## 10. Resultado en vivo — **CERTIFICADO**

**Exito al PRIMER intento vivo** (1 de 3 permitidos), codigo de salida 0 y
exactamente **una** linea `OBSERVATION_JSON`.

El unico arranque previo del adaptador fue la verificacion de la guarda de
credenciales, que corta con codigo 2 **sin contactar al servidor**: no es un
intento vivo y se reporta aparte.

### 10.1 Cronologia observada

| Etapa | Observacion |
|---|---|
| Preflight | OK. Relacion de nivel natural verificada contra el estado autoritativo, sin modificar a nadie |
| Party | Formada: lider de nivel alto y miembro de nivel bajo, sin terceros |
| Solicitud `0xA8` | `"Shared Experience has been activated, but some members of your party are inactive."` — solicitado si, habilitado no |
| Combate 1 | **5.2 s**, los **dos** participantes golpean al objetivo |
| Participacion | Los **dos** cobran experiencia individual por el primer monstruo; la suma **no** supera su experiencia base |
| Combate 2 | **6.7 s**, **solo** el participante de nivel alto |
| Medicion negativa | El alto gana; **el participante de nivel bajo gana 0** |
| Corroboracion de magnitud | El alto cobra el **pago individual completo**, no la fraccion repartida |
| Reconfirmacion | La party seguia formada tras la medicion |

El mensaje del servidor habla de participantes **"inactivos"** aunque la causa
real sea el **nivel**: es el unico mensaje que el legacy tiene para
"solicitado pero no habilitado" (`party.cpp:317`), y no distingue cual de
los cuatro requisitos fallo. Por eso **no se congela** y se trata como evidencia
de apoyo: lo decisivo es el comportamiento de la experiencia.

### 10.2 El presupuesto de frescura, con muchisimo margen

| Tramo | Duracion |
|---|---:|
| Combate 1 (los dos adentro) | 5.2 s |
| Medicion e invocacion del 2.o objetivo | 2.0 s |
| Combate 2 (solo el alto) | 6.7 s |
| **Cota conservadora total** | **13.9 s** |
| Presupuesto | 55.0 s |
| Ventana real del oracle (`pzLocked`) | 60.0 s |

El participante de nivel bajo conservaba su **signo de batalla** en el instante
exacto de la muerte del segundo objetivo (`true`), asi que el servidor **no**
pudo haberle limpiado los puntos de participacion.

### 10.3 Corroboracion independiente desde el archivo persistido

Esto **no** pasa por el camino de observacion del cliente: sale de
`servidor/gamedata/players/*.tvpp` leido antes y despues de la corrida.

| Magnitud | `QA_LEVEL_HIGH` | `QA_LEVEL_LOW` |
|---|---:|---:|
| Nivel | 25 -> 25 (**0**) | 1 -> 1 (**0**) |
| Punos | 46 -> 46 (**0**) | 10 -> 10 (**0**) |
| Garrote (nivel) | 11 -> 11 (**0**) | 10 -> 10 (**0**) |
| Magia / vocacion / vida maxima | sin cambio | sin cambio |
| Experiencia | 204824 -> 204841 (**+17**) | 0 -> 2 (**+2**) |
| Vida | 172 -> 156 | 150 -> 150 (**0 de dano recibido**) |

La descomposicion cierra exactamente, con experiencia base 10 en los dos
objetivos:

- **Primer monstruo, pago INDIVIDUAL proporcional al dano**
  (`creature.cpp:375`, `cb.total * experience / totalCombatDamageReceived`):
  **+7 al alto** y **+2 al bajo**. La suma es **9**, que es `<= 10` y refleja el
  truncamiento entero de dos partes proporcionales. Los dos cobraron, o sea que
  los dos estaban en el `damageMap` con dano positivo y, por el mismo evento,
  en `ticksMap`.
- **Ese +2 del participante bajo es la prueba de que el pozo NO estaba
  operando.** Con el reparto habilitado los dos habrian cobrado
  `ceil(10 * 1.20 / 2) = 6`, sumando **12**, estrictamente **mayor** que la
  experiencia base del monstruo. Una suma de 9 es imposible bajo reparto.
- **Segundo monstruo, atacado solo por el alto:** **+10 al alto**, su
  experiencia base **completa y sin dividir**, y **+0 al bajo**. Si el reparto
  hubiera seguido habilitado y simplemente se hubiera excluido al bajo, el alto
  habria cobrado **6**, no 10.

Las unicas otras diferencias son los contadores de intentos de garrote del
participante alto (13 -> 19), avance natural por pelear. **Mutaciones de
progresion por comandos de QA: 0.**

El participante de nivel 1 termino la corrida con **exactamente la misma vida
con la que entro**: el diseño de dos monstruos y la eleccion de especie
lograron que no recibiera **ni un punto** de dano, asi que no hubo que curarlo
de ninguna forma.

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
| Cuentas de QA creadas | **0** |
| Personajes de QA creados | **0** |
| Cambios de credenciales | **0** |
| Ediciones de base de datos | **0** |
| Personajes del usuario tocados | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

El participante alto recibio veneno del segundo objetivo (`"You are poisoned."`,
golpes de 1 punto de vida). Nunca se acerco al piso de seguridad y no hizo falta
curarlo; en particular **no** se lo curo subiendo de nivel ni con ningun
comando.

### 10.5 Limpieza

La party creada por la prueba se deshizo por `0xA7` desde las dos sesiones y el
god devolvio a los dos participantes a su templo con `omani`. Los dos monstruos
de prueba murieron como parte del recorrido, asi que no quedo ninguno vivo y no
hizo falta el retiro dirigido. Las tres sesiones se cerraron. **No se borro la
identidad de QA de nivel bajo**: queda persistida como infraestructura de QA
reutilizable para futuros fixtures de elegibilidad y de borde.

Efecto secundario declarado: el personaje de QA de nivel bajo **ya no esta en
estado de creacion virgen**. Al haber entrado al mundo ahora tiene archivo
propio bajo `servidor/gamedata/players/` con **+2 de experiencia** legitimos por
pelear. Sigue en **nivel 1** (subir a 2 exige 100 de experiencia), asi que sigue
sirviendo como participante bajo; la afirmacion de "estado de creacion normal"
de la seccion 5 corresponde al estado **con el que entro a esta corrida**, y
queda registrada como tal para que nadie la lea como una propiedad permanente.

### 10.6 Replay y congelamiento

- Replay con `qa/parity/tools/replay.py` **sin modificar**: **`PASS 8/8`**,
  codigo 0.
- Ejecutado **dos veces**: reporte
  `qa/parity/reports/replay_live_party_shared_exp_level_report.json`
  **byte-identico** entre corridas
  (`sha256 0263ccd1efc4c1eba1d76d3e5a2d25022c59e3b0a37894fb2b34c4f967e66a60`).
- Los **7 hashes congelados** de la seccion 9 se recalcularon despues de la
  corrida viva, del wrap y de los dos replays: **identicos los siete**. El
  codigo commiteado es exactamente el que produjo la observacion, y la
  expectativa no se toco despues de ver al oracle.
- `wrap_live_observation.py` tampoco se modifico: el envoltorio generico acepto
  un **quinto** dominio de comportamiento sin cambios.

### 10.7 Payload normalizado certificado

```json
{
  "level_condition": {
    "low_participant_below_required_level": true
  },
  "controls": {
    "party_remained_formed": true,
    "both_sessions_remained_connected": true,
    "within_allowed_range": true,
    "both_participants_had_fresh_activity": true
  },
  "level_ineligible_distribution": {
    "high_participant_gained_experience": true,
    "low_participant_gained_experience": false,
    "shared_distribution_suppressed": true
  }
}
```

Ni un nombre, ni un nivel, ni una vocacion, ni un id de runtime, ni una
coordenada, ni una especie de monstruo, ni una magnitud de experiencia, ni una
marca de tiempo.

## 11. Requisito diferido para el TVP3D nativo

Este fixture es **evidencia de oracle legacy**, no una implementacion. Los
contratos de Architecture V2 siguen en **198 especificadas / 0 materializadas,
sin cambio**.

Lo que el servidor nativo en Godot debera reproducir, sumado a lo ya listado en
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md` y
`docs/qa/PARITY_PHASE2D1_PARTY_SHARED_EXP_RANGE.md`:

1. Una regla de elegibilidad **por nivel** relativa al **participante de nivel
   mas alto** de la party, no a un umbral absoluto.
2. Redondeo **hacia arriba** sobre aritmetica no entera (`ceil(mas_alto*2/3)`) y
   comparacion **estricta**, de modo que un participante exactamente en el
   minimo siga siendo elegible.
3. Que baste **un** participante inelegible para que el reparto entero no se
   habilite.
4. Que la evaluacion se dispare **solo ante eventos de participacion**.
5. Que con el reparto deshabilitado la experiencia se pague
   **individualmente y proporcional al dano**, y que el unico atacante cobre el
   total sin dividir.
6. Que un participante por debajo del minimo **no reciba nada**, ni siquiera una
   fraccion, aunque este en rango, conectado y activo.

## 12. Lo que este fixture NO afirma

- **No** afirma el borde exacto del umbral de nivel (un participante justo en
  `minLevel` contra otro justo por debajo).
- **No** afirma el valor de ninguna variable interna del servidor, en particular
  `sharedExpEnabled`.
- **No** afirma nada sobre el texto de los mensajes del servidor.
- **No** afirma que el mensaje generico de "participantes inactivos" distinga la
  causa: se observo que **no** la distingue.

## 13. Estado del dominio despues de este turno

Con este fixture, los tres requisitos observables de
`Party::canUseSharedExperience` quedan certificados en vivo por separado:

| Requisito | Fixture | Estado |
|---|---|---|
| Participacion reciente (`ticksMap`) | `PARITY-PARTY-SHARED-EXP-001` | Certificado (positivo + compuerta de actividad) |
| Rango espacial | `PARITY-PARTY-SHARED-EXP-RANGE-001` | Certificado (negativo) |
| **Nivel** | **`PARITY-PARTY-SHARED-EXP-LEVEL-001`** | **Certificado (negativo)** |

Quedan sin certificar, y declarados: los dos **bordes** (30 contra 31 casillas;
`minLevel` exacto contra `minLevel - 1`) y la participacion por **curacion a un
companero** (`player.cpp:3247`), que el codigo documenta y ninguna corrida
ejercito.
