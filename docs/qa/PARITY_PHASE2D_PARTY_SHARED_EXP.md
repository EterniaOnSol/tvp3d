# Phase 2D — Paridad de experiencia compartida (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**.

`PARITY-PARTY-SHARED-EXP-001`: observacion `LIVE_ORACLE` fresca contra TVP
7.72 real y replay `PASS 13/13` con el comparador generico sin modificar.

Es el **segundo fixture** del tercer dominio de paridad, separado a proposito
del ciclo de vida de party (`docs/qa/PARITY_PHASE2D_PARTY_LIFECYCLE.md`).

> **Leer tambien el addendum Phase 2D.0.1 al final.** El cuerpo de este
> documento describe la certificacion ORIGINAL, que uso `/addSkill` para
> reforzar a los personajes de prueba. Ese comportamiento **ya no existe** en
> el harness: fue recertificado sin ninguna mutacion de progresion. La
> cronologia original se conserva a proposito.

## Por que este dominio importa

La experiencia compartida **tiene que existir en el TVP3D final**. Este turno
no la implementa: congela la semantica del oracle 7.72 que el futuro servidor
nativo en Godot debera reproducir con nuestra propia arquitectura
servidor-autoritativa.

## Sin evidencia grabada, a proposito

Este fixture **no tiene observacion `RECORDED_EVIDENCE`**.

`docs/qa/PRUEBA_VIVA_PARTY.md` (lineas 67-74) deja constancia de que la
experiencia compartida **nunca se ejercito** en aquella corrida historica:
solo se recorrio el ciclo de vida. Inventar una observacion grabada habria
sido fabricar evidencia. Por eso el corpus `RECORDED_EVIDENCE` queda en **5**
y no en 6: la unica evidencia de este fixture es la captura en vivo.

## Semantica verificada contra el codigo del oracle

Todo lo que sigue sale de leer el servidor, no de suponer.

### Solicitado no es lo mismo que habilitado

`Party::setSharedExperience` (`servidor/src/party.cpp:299-325`) separa dos
cosas distintas:

- `sharedExpActive` — lo que **se pidio**.
- `sharedExpEnabled` — si el reparto **corresponde**, recalculado con
  `canEnableSharedExperience()`.

Y lo dice explicitamente con dos mensajes distintos: `"Shared Experience is
now active."` cuando quedo habilitado, y `"Shared Experience has been
activated, but some members of your party are inactive."` cuando se acepto la
solicitud pero el reparto **no** quedo habilitado.

### Solo el lider

Misma funcion, linea 301: `if (!player || leader != player) return false;`.
La solicitud de un no-lider no produce **ninguna** transicion ni mensaje.

### La regla de actividad

`Party::updatePlayerTicks` (`party.cpp:388-394`) solo anota participacion si
`points != 0`, y entonces llama a `updateSharedExperience()` **en el acto**,
de forma sincronica. No hay temporizador de por medio: el reparto se habilita
en el mismo instante en que el ultimo participante registra dano.

Los puntos de participacion se anotan cuando un jugador dana a un monstruo
hostil (`player.cpp:3227`), cuando lo hace su invocacion (`monster.cpp:760`)
y tambien cuando **cura a un companero de party** (`player.cpp:3247`): curar
cuenta como participar, no hace falta atacar.

`updateSharedExperience` reevalua `sharedExpEnabled` en cada tick **sin
emitir ningun mensaje**. Por eso `enabled` no es observable desde afuera de
forma directa, y este fixture lo prueba **por comportamiento** (ver abajo).

### El reparto: primero se junta, despues se divide

Esto es lo mas facil de malinterpretar y esta verificado en
`servidor/src/creature.cpp:368-413`.

La parte de cada atacante arranca proporcional al dano que hizo:

```cpp
int64_t gainedExperience = cb.total * experience / totalCombatDamageReceived;
```

Pero si la party tiene el reparto **activo y habilitado**, esa parte **no se
paga**: se acumula en un unico pozo por party y se marca `partySharing`, con
lo que el pago individual queda suprimido (`creature.cpp:391-402, 405-407`).
El pozo se paga **una sola vez**, a traves del lider:

```cpp
for (auto& it : sharedExperience) {
    it.first->getLeader()->onGainExperience(it.second, this);
}
```

Ese pago reentra en `Player::onGainExperience` (`player.cpp:3301-3304`), que
al estar activo y habilitado llama a `Party::shareExperience`, y recien ahi
se aplica la formula y se le entrega **el mismo valor** a cada miembro y al
lider (`party.cpp:327-336`).

Consecuencia que el servidor nativo debe reproducir: **quien golpeo mas no
cobra mas**. Las proporciones de dano se disuelven en el pozo antes de
dividir. Y como el pozo solo junta las partes de los **miembros de la
party**, el dano de cualquier tercero ajeno a la party **le resta** al pozo.

### La formula

`servidor/data/events/scripts/party.lua`: multiplicador base `1.20`; se
juntan las vocaciones base **distintas** excluyendo `VOCATION_NONE`; si hay
mas de una, el multiplicador pasa a
`1.0 + ((size * (5*(size-1) + 10)) / 100)`; y finalmente

```lua
exp = math.ceil((exp * mult) / (#members + 1))
```

### No se puede alternar con el signo de batalla puesto

`Game::playerEnableSharedPartyExperience` (`servidor/src/game.cpp:5089-5102`)
vuelve **sin hacer nada** si el solicitante tiene `CONDITION_INFIGHT` y no
esta en zona protegida:

```cpp
if (!party || (player->hasCondition(CONDITION_INFIGHT) && player->getZone() != ZONE_PROTECTION)) {
    return;
}
```

Se descarta **en silencio**: sin mensaje y sin cambio de estado. El signo de
batalla dura `pzLocked` = 60 s (`servidor/config.lua:79`).

Esta regla aparecio como un falso fallo de la captura y se convirtio en
evidencia: es una regla real del oracle y quedo como asercion propia.

### Los escudos no dicen nada de esto

`PartyShields_t` (`servidor/src/const.h:187-193`) tiene **exactamente cinco**
valores (`SHIELD_NONE`, `SHIELD_WHITEYELLOW`, `SHIELD_WHITEBLUE`,
`SHIELD_BLUE`, `SHIELD_YELLOW`). **No hay variantes de escudo para
experiencia compartida en 7.72**, asi que no se invento ninguna y los escudos
no se usan como evidencia en este fixture.

## Que NO afirma este fixture

Honestidad sobre el alcance:

- **La regla de nivel** (`minLevel = ceil(nivel_mas_alto * 2 / 3)`) y **la
  regla de rango** (`Position::areInRange<30,30,1>`) quedan documentadas desde
  el codigo, pero **no** se afirman como observaciones. Certificarlas exige
  casos negativos dedicados, previstos como fixtures futuros separados.
- No se afirma el valor de ninguna variable interna del servidor.

## Fixture y case

- `qa/parity/fixtures/tvp772/party_shared_exp/parity-party-shared-exp-001.json`
  (`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, clasificacion
  `MATCH_EXPECTED`)
- `qa/parity/cases/tvp772/party_shared_exp/parity-party-shared-exp-001.case.json`
  (`tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`,
  `case_id == fixture_id`)

**13 aserciones `EQ`**:

| Grupo | Aserciones |
|---|---:|
| `transport` | 2 (el lider puede pedirlo; el no-lider no produce transicion) |
| `inactive_party` | 2 (solicitado si, habilitado no) |
| `activity_gate` | 1 (solo habilita despues de participar) |
| `eligible_party` | 2 (solicitado si, habilitado si) |
| `distribution` | 3 (ambos ganan, partes iguales, coincide con la formula) |
| `disable_in_fight` | 1 (con signo de batalla la orden se descarta) |
| `disable` | 2 (solicitado no, habilitado no) |

### Como se prueba `enabled` sin poder leerlo

`sharedExpEnabled` no viaja por la red. La captura lo deriva del
comportamiento observado:

```gdscript
var repartido: bool = g1 > 0 and g2 > 0 and g1 == g2
```

El razonamiento es el del codigo citado arriba: **sin** habilitar, cada
atacante cobra su parte proporcional al dano y las ganancias serian
distintas; **solo** con el reparto habilitado se juntan en un pozo y se pagan
iguales. Ganancias iguales y coincidentes con la formula son, entonces,
evidencia de que estaba habilitado.

## Normalizacion

Se comparan **roles** y **relaciones**, nunca identidades ni magnitudes
absolutas. Excluidos: `character_names`, `character_levels`,
`character_vocations`, `total_accumulated_experience`, `creature_runtime_ids`,
`account_id`, `positions`, `server_message_text`, `wall_clock_timestamp`.

No se compara experiencia total de nadie: solo la **relacion** entre lo que
gano cada participante y la parte esperada derivada de la formula. La parte
esperada se deriva **en tiempo de captura** desde la experiencia base del
monstruo y la composicion de vocaciones; **no hay ningun numero concreto
congelado** en el fixture.

El texto exacto de los mensajes no entra en la comparacion: se normaliza a
hechos booleanos de solicitado/habilitado.

## Adaptador de captura en vivo

`cliente3d/pruebas/prueba_parity_party_shared_exp_capture.gd` + `.tscn`
(nuevos, QA-owned). Tres sesiones: un god operador y los **dos** participantes
de la party.

Credenciales solo por entorno: `TVP772_ACCOUNT`, `TVP772_PASSWORD`,
`TVP772_PLAYER_CHARACTER`, `TVP772_PLAYER2_ACCOUNT`,
`TVP772_PLAYER2_PASSWORD`, `TVP772_PLAYER2_CHARACTER`, `TVP772_GOD_ACCOUNT`,
`TVP772_GOD_PASSWORD`, `TVP772_GOD_CHARACTER`, `TVP772_MONSTER_BASE_EXP`
(opcionales `TVP772_HOST`, `TVP772_LOGIN_PORT`). Nunca literales, nunca
impresas. No se copio ninguna credencial de los scripts historicos.

Terreno: `(32008,32400,7)`, el punto aislado y colocable ya calificado en
Phase 2C.1/2C.2. Es detalle de implementacion y **no entra** al payload.

### Dos sesiones por cuenta no se puede

Las cuentas normales admiten **una sola** sesion simultanea (`"You may only
login with one character of your account at the same time"`). Los dos
participantes tienen que salir de **cuentas distintas**; solo el god esquiva
la restriccion por `canalwayslogin`.

### Por que el god no pelea

El god queda **fuera** de la party y **nunca golpea al monstruo**, por dos
razones independientes:

1. El grupo 6 tiene `notgainexperience="1"`, asi que no podria demostrar
   "ambos ganan".
2. Mas importante: su parte proporcional del dano **saldria del pozo** de la
   party (`creature.cpp:375`), porque no es miembro, y el reparto ya no
   coincidiria con la formula. Los participantes tienen que poner el 100% del
   dano.

### Identidad del monstruo por id nuevo

El campo tiene fauna natural: durante las pruebas entro un `cave rat`
silvestre. Resolver el objetivo "por nombre" era ambiguo y una rata silvestre
llego a recibir una invitacion de party.

La captura anota los ids conocidos **antes** de invocar y exige exactamente
**un id nuevo por sesion**; si aparece mas de uno, aborta `BLOCKED` en vez de
medir con identidad ambigua. Asi la fauna preexistente no confunde nada y
**no hace falta matarla**.

### Refuerzo de los personajes de prueba (HISTORICO de Phase 2D)

> **Esto describe la PRIMERA certificacion, no el harness actual.** Phase
> 2D.0.1 saco por completo el `/addSkill` automatico. La seccion se conserva
> porque la certificacion original realmente ocurrio asi y la cronologia no se
> borra. Ver el addendum al final del documento.

Dos personajes de nivel 1 a puno limpio no bajan a un `cave rat` de 30 de
vida antes de que las ratas los bajen a ellos: una corrida mostro el monstruo
al 97% de vida tras 5 s y el piso de seguridad se activo.

El god sube, **solo a los dos personajes de QA**, habilidad de punos (+18) y
nivel (+12) con `/addSkill`. Justificacion de cada eleccion:

- **Punos** no toca la experiencia.
- **Nivel** si suma experiencia, pero se aplica **antes** de tomar la foto de
  experiencia, y la medicion es un **delta**; ademas cada avance cura
  (`player.cpp:1532-1533`), lo que saca a los personajes de la vida baja que
  quedaba de corridas anteriores.
- A los dos **por igual**, para no romper la regla de nivel de la party.
- El refuerzo es **moderado a proposito**: si uno matara al monstruo de un
  solo golpe, el otro no registraria participacion y el reparto no se
  habilitaria.

Son personajes creados para QA en cuentas de QA. Ningun personaje del usuario
fue tocado.

## Ejecucion certificada

Codigo de salida 0 y exactamente una linea `OBSERVATION_JSON`:

```text
Reforzando punos y vitalidad de los dos personajes de prueba.
Refuerzo aplicado: ambos participantes en condiciones de pelear.
Invocando un unico monstruo de prueba.
Monstruo de prueba visible; ambos participantes lo atacan.
  combate 10s: vida del monstruo vista por P1 = 97%
  combate 20s: vida del monstruo vista por P1 = 60%
  combate 30s: vida del monstruo vista por P1 = 24%
El monstruo de prueba murio; midiendo la experiencia de ambos.
Ganancias observadas (relacion, no totales): iguales=true, coinciden con la formula=true
El LIDER pide desactivar con el signo de batalla puesto.
Confirmado: con signo de batalla la orden se descarta sin transicion.
El LIDER solicita desactivar la experiencia compartida (50s).
  [P1] Shared Experience has been deactivated.
Confirmado: desactivacion explicita del servidor.
```

La secuencia de desactivacion es la prueba viva de la regla de combate: la
orden se repitio cada 10 s y el servidor la ignoro en silencio hasta que
expiro el signo de batalla, y recien ahi contesto.

### Costo de la certificacion (HISTORICO de Phase 2D)

**Diez intentos en vivo**, muy por encima del maximo de 3 por fixture. Se
declara explicitamente en vez de disimularlo. Los fallos fueron reales y cada
uno dejo una correccion: personaje inexistente, una sola sesion por cuenta,
reentrada de `_formar_party` por `await` que no frena `_process`, identidad
ambigua por fauna silvestre, dano insuficiente de nivel 1, vida baja de
resaca, y por ultimo la regla de combate — que termino siendo evidencia.

## Payload normalizado

```json
{
  "transport": {
    "leader_can_request_enable": true,
    "non_leader_request_rejected": true
  },
  "inactive_party": {
    "requested_active": true,
    "enabled": false
  },
  "activity_gate": {
    "enabled_only_after_participation": true
  },
  "eligible_party": {
    "requested_active": true,
    "enabled": true
  },
  "distribution": {
    "both_participants_gain_experience": true,
    "same_share_for_each_participant": true,
    "share_matches_legacy_formula": true
  },
  "disable_in_fight": {
    "request_ignored_while_in_fight": true
  },
  "disable": {
    "requested_active": false,
    "enabled": false
  }
}
```

Ni un nombre, ni un nivel, ni una vocacion, ni un id, ni una experiencia
total.

## Limpieza

La party de prueba queda deshecha al terminar y ante cualquier fallo
intermedio el adaptador manda `0xA7` por ambas sesiones antes de cerrar.
Ningun personaje quedo en party.

## Seguridad

- **Muertes de jugador: 0**
- **Monstruos invocados: 1** (uno solo, el de la medicion)
- **Usos de `/killall`: 0** — no se mato fauna preexistente
- Los unicos cambios persistentes son el refuerzo de punos y nivel sobre los
  **dos personajes de QA**, documentado arriba.

## Requisito diferido para el TVP3D nativo

Este fixture es **evidencia de oracle legacy**, no una implementacion.

La semantica legacy `0xA8`, los valores de `PartyShields_t` y la formula de
`party.lua` **no** entran en los contratos de Architecture V2, que siguen en
198 obligaciones especificadas y 0 materializadas, sin cambio.

Lo que queda **diferido y pendiente** para el servidor nativo en Godot:

1. Separar **solicitado** de **habilitado** como dos estados distintos.
2. Restringir la solicitud al **lider**.
3. Exigir **participacion reciente** de todos los participantes, con
   reevaluacion **sincronica** ante cada evento de participacion y **sin**
   mensaje propio.
4. Contar como participacion tanto el dano como la **curacion a un
   companero**.
5. **Juntar primero en un pozo y dividir despues**, de modo que la proporcion
   de dano no altere el reparto.
6. Rechazar el cambio de estado mientras el solicitante este **en combate**
   fuera de zona protegida, **en silencio**.
7. Reglas de **nivel** y **rango**, todavia sin certificar: requieren casos
   negativos dedicados.

## Conteos

| Inventario | Antes | Despues |
|---|---:|---:|
| Obligaciones Architecture V2 | 198 / 0 | 198 / 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | 6 | **7** |
| Casos de replay `QACaseV2` | 6 | **7** |
| Observaciones `RECORDED_EVIDENCE` | 5 | **5** (sin cambio, a proposito) |
| Observaciones `LIVE_ORACLE` | 3 | **4** |

Phase 2 sigue **EN CURSO**.

---

# Addendum Phase 2D.0.1 — Endurecimiento del harness reutilizable

Estado: **RECERTIFICADO EN VIVO**, ahora **sin ninguna mutacion de progresion**.

## Que estaba mal

La semantica certificada en Phase 2D **sigue siendo valida**: la observacion
fue genuina, los hashes estaban congelados alrededor de la corrida final y el
replay daba `PASS 13/13`. Este addendum **no** dice que Phase 2D fuera
fabricada.

El defecto era de **higiene del harness, no de evidencia**: la captura subia
sola `fist +18` y `level +12` a los dos participantes en **cada** corrida.
Sirvio una vez, pero como pieza reutilizable estaba rota: cada ejecucion
degradaba el entorno un poco mas.

La prueba de que el problema era real esta en los propios personajes de QA.
Arrancaron en **nivel 1**; la primera certificacion los dejo en **nivel 13**;
al abrir este turno estaban en **nivel 25** y **punos 46**, arrastrados por
los reintentos. Un harness que se reusa no puede escalar a sus propios
sujetos de prueba.

## Que cambio

La relacion se invirtio: **lo que antes se fabricaba ahora se comprueba.**

- Eliminado **todo** uso automatico de `/addSkill` (punos, nivel, magia,
  vida, mana, habilidades, experiencia).
- Eliminadas las constantes `PUNOS_EXTRA` y `NIVELES_EXTRA` y la funcion
  `_reforzar()`.
- Los unicos comandos que manda el god son `/gotopos`, `/c`, `/m` y el
  `omani` de limpieza. Auditable buscando `enviar_hablar` en el adaptador.
- Corregido el comentario de cabecera que **afirmaba** no editar niveles
  mientras el codigo los editaba. Ahora la afirmacion es cierta.
- El estado actual de los dos personajes de QA queda como **precondicion de
  entorno**, no como algo que la captura pueda manufacturar. No se intento
  deshacer el `+18/+12` anterior: no existia una instantanea transaccional
  previa, y adivinar valores viejos habria sido inventar datos. Sin
  `/addSkill` negativo, sin editar la base, sin SQL manual.

## Preflight

Antes de armar la party y antes de invocar nada, se verifica contra el estado
autoritativo ya parseado:

| Requisito | Fuente observada |
|---|---|
| ambos conectados | `adentro` |
| ambos vivos | `estadisticas.vida > 0` |
| vida sobre el piso de seguridad | `vida >= 40` |
| vida capaz de absorber el combate | `vida >= 40 + 110` |
| vida maxima suficiente | `vida_max >= 40 + 110` |
| capaces de pelear | `habilidades.puno.nivel >= 20` |
| regla de nivel 2/3 del oracle | `min(n) >= ceil(max(n) * 2 / 3)` |
| regla de rango del oracle | `areInRange<30,30,1>` sobre `mi_pos` |

Si algo falla la captura devuelve **`BLOCKED`** con un motivo no secreto y
**no toca a nadie**. Nunca se cura ni se recupera subiendo de nivel.

### Por que la holgura es absoluta y no un porcentaje

El primer intento de este turno uso "60% de la vida maxima" y dio
`BLOCKED participant health below safe fraction of maximum` con un
participante al **59%**.

El umbral se corrigio, pero **no para que pasara la prueba**: el porcentaje
medía la cosa equivocada. Escala con la vida maxima, asi que un personaje
grande al 59% puede tener margen absoluto de sobra mientras uno chico al 100%
no aguanta ni un combate. Lo que importa es **cuanto dano entra**, que no
escala con el nivel del participante. Por eso ahora se exige una **holgura
absoluta** de 110 de vida por encima del piso, tomada del dano observado en
una corrida completa de Phase 2D.

Se declara explicitamente que el umbral cambio **despues** de un `BLOCKED`.
Eso no contamina la certificacion: un preflight bloqueado **nunca llego a
observar al oracle**, asi que ningun resultado del servidor influyo en el
cambio. El congelamiento se rehizo antes de la corrida viva.

## Resultado de la recertificacion

| Concepto | Valor |
|---|---|
| Intentos vivos | **2 de 3** (el 1.o fue el `BLOCKED` del preflight) |
| Muertes de jugador | **0** |
| Monstruos invocados | **1** |
| Muertes colaterales de fauna | **0** |
| Usos de `/killall` | **0** |
| Dano del god al monstruo | **0** |
| Mutaciones de progresion por comandos de QA | **0** |
| `OBSERVATION_JSON` emitidos | **1** |
| Replay | **`PASS 13/13`**, byte-identico entre dos corridas |

El payload normalizado quedo **identico** al de Phase 2D: el oracle reprodujo
la misma semantica con un harness que no modifica a nadie.

### Delta de progresion medido en el archivo persistido

| Magnitud | P1 | P2 |
|---|---:|---:|
| Nivel | 25 -> 25 (**0**) | 25 -> 25 (**0**) |
| Punos | 46 -> 46 (**0**) | 46 -> 46 (**0**) |
| Experiencia | 204812 -> 204818 (**+6**) | 204812 -> 204818 (**+6**) |
| Garrote | 10 -> 11 (**+1**) | 11 -> 11 (0) |

Las dos ultimas filas son **efectos legitimos del juego, no mutaciones
administrativas**, y no se confunden con ellas:

- Los **+6 de experiencia** son exactamente la magnitud que el fixture mide:
  `ceil(10 * 1.20 / 2) = 6`. Que aparezcan identicos en los dos participantes
  es evidencia independiente de la formula de reparto.
- El **+1 de garrote** en un participante es un avance natural por pelear.
  Ningun comando lo produjo.

Comparar con Phase 2D, donde cada corrida sumaba **+12 niveles y +18 punos**
por comando administrativo.

## Hashes congelados (identicos antes y despues de la corrida viva)

| Artefacto | SHA-256 |
|---|---|
| fixture | `3237d710a954640afc8c33596477484bd7f0ed2fb6487d65b6850345579f5e84` |
| QACase | `e0bfce2ead6877a90a80b10419361e8ec86633a43ee26d5c87b0c2be4de86943` |
| captura `.gd` | `16663a03545546425d9f446168802e40c8501331a867119259fca9347479a872` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

El fixture y el `QACase` son **byte-identicos** a Phase 2D: las **13
aserciones** no se tocaron, no se agrego la de nivel ni la de rango, y sigue
sin haber `RECORDED_EVIDENCE` para este fixture.

## Inventarios

**Sin cambio.** Architecture V2 sigue en 198 / 0; `LEGACY_PARITY` 7; casos de
replay 7; `RECORDED_EVIDENCE` 5; `LIVE_ORACLE` 4.
`PARITY-PARTY-SHARED-EXP-001` sigue siendo **un** fixture con **una**
observacion viva canonica: esta recertificacion **reemplaza** esa observacion
en su ruta canonica, no agrega otra.
