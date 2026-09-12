# Auditoria de evidencia de casa y cama para paridad (TVP 7.72)

Turno de **auditoria**, dentro de **Phase 2 — build parity fixtures against
TVP**. No abre fase ni sub-fase nueva y **no toca**
`docs/tibia3d/MASTER_PLAN.md`.

## Resultado: `NO_VALID_FIXTURE`

**No se materializo ningun fixture, ningun `QACase`, ninguna
`RECORDED_EVIDENCE` y ninguna `LIVE_ORACLE`.** Los inventarios quedan **sin
cambio**.

Dos conclusiones independientes, cada una suficiente por si sola:

1. **`docs/qa/PRUEBA_VIVA_CASA_CAMA.md` no contiene ninguna observacion de
   runtime positiva.** Su unica observacion es un **fallo**, y ese fallo era un
   **defecto del servidor que desde entonces fue corregido**. Convertirlo en
   `RECORDED_EVIDENCE` congelaria un **bug** como comportamiento legacy
   esperado.
2. **La certificacion en vivo exige mutaciones que este turno prohibe**, y que
   ademas dependerian de un residuo de QA sin restaurar.

El hallazgo de mayor valor del turno no es un fixture: es que **el bloqueo
historico estaba mal etiquetado**. Ver seccion 4.

---

## 1. Auditoria linea por linea

`docs/qa/PRUEBA_VIVA_CASA_CAMA.md` tiene **21 lineas**. Clasificacion completa
de cada afirmacion sustantiva:

| Lineas | Afirmacion | Clasificacion |
|---|---|---|
| 1 | Titulo | — |
| 3 | `Estado: BLOQUEADO reproducible (2026-08-29)` | **UNRESOLVED** |
| 5-9 | Comando de ejecucion de la escena | **TEST_SETUP** |
| 11-12 | Casa 6 `Sunset Homes, Flat 01`; entrada y cama server id 1754 en coordenadas concretas | **TEST_SETUP** + **ENVIRONMENTAL_DEPENDENCY** |
| 12-13 | *"La prueba asigna temporalmente la casa al personaje god, concede un dia premium"* | **TEST_SETUP** (mutante) |
| 13 | *"intenta usar la cama"* | **TEST_SETUP** (estimulo) |
| 13-14 | *"deja owner y premium restaurados al finalizar"* | **CLEANUP** (declarado; ver seccion 5.2) |
| 16-17 | *"Resultado observado: el servidor responde `You cannot use this object` y no expulsa al jugador a dormir"* | **RUNTIME_OBSERVATION** |
| 17-18 | *"Por tanto no se puede afirmar todavia el ciclo de despertar ni la persistencia"* | **INFERENCE** (autodeclarada como no afirmable) |
| 18-20 | *"La hipotesis de trabajo es que la baldosa no queda en `ZONE_PROTECTION`... o que falta un permiso de casa"* | **INFERENCE** (el propio texto dice "hipotesis") |
| 20 | *"debe resolverse en servidor/mapa antes de repetir"* | **ENVIRONMENTAL_DEPENDENCY** |

### Conteo

| Clasificacion | Cantidad |
|---|---:|
| `RUNTIME_OBSERVATION` | **1** (y es **negativa**) |
| `SOURCE_OR_API_FACT` | 0 |
| `TEST_SETUP` | 4 |
| `CLEANUP` | 1 |
| `INFERENCE` | 2 |
| `UNRESOLVED` | 1 |
| `ENVIRONMENTAL_DEPENDENCY` | 2 |

### 1.1 La unica observacion de runtime, en detalle

| Campo | Valor |
|---|---|
| Actor | personaje operador, con casa y premium concedidos temporalmente |
| Estimulo | usar la cama |
| Respuesta observable | `You cannot use this object`; el jugador **no** pasa a dormir |
| Precondicion | casa asignada, premium concedido |
| Independientemente testeable | si |
| Depende de propiedad de casa | **si** |
| Depende de una cama | **si** |
| Depende de Docker / MariaDB / persistencia | **si**, para la asignacion de casa y el premium |
| Valores literales incidentales | casa 6, ids y coordenadas: **incidentales** |
| Normalizable sin credenciales ni estado oculto | si |

**El documento no observa dormir, ni despertar, ni regeneracion, ni
persistencia.** Lo dice el propio texto: *"no se puede afirmar todavia el ciclo
de despertar ni la persistencia"*.

---

## 2. Por que NO se creo `RECORDED_EVIDENCE`

La unica observacion de runtime disponible es **el rechazo de la cama**. Podria
parecer congelable como "el servidor rechaza usar la cama bajo estas
condiciones". **Seria un error grave**, por tres razones acumulativas:

1. **Era un defecto, no una regla.** La seccion 4 demuestra que el rechazo lo
   producia una guarda de `game.cpp` que **ya fue corregida**. Congelarlo
   convertiria un bug en paridad esperada y haria que el corpus afirmara algo
   **falso** sobre TVP.
2. **Ya no es reproducible.** Un `RECORDED_EVIDENCE` que el oracle actual
   contradice no es evidencia: es una regresion garantizada.
3. **El propio documento no lo presenta como regla**, sino como sintoma a
   investigar: *"debe resolverse en servidor/mapa antes de repetir"*.

Las dos `INFERENCE` tampoco califican, por definicion. Y la hipotesis de la
linea 18-20 ademas resulto **incorrecta** (seccion 4.2).

**Ninguna afirmacion del documento califica como `RECORDED_EVIDENCE`.**

---

## 3. Descomposicion semantica

La pregunta no es si "casa y cama" es un dominio porque el archivo se llame
asi. Las unidades semanticas **independientes** que el documento *menciona*
son:

| Unidad | Evidencia de runtime en el documento |
|---|---|
| Restriccion de acceso a la casa | **ninguna** |
| Uso de cama / entrar a dormir | solo el **fallo** |
| Ciclo de despertar | **ninguna** (autodeclarado no afirmable) |
| Regeneracion al dormir | **ninguna** |
| Persistencia del durmiente | **ninguna** (autodeclarado no afirmable) |
| Uso de cama dependiente de propiedad | **ninguna** |

**Cero unidades tienen evidencia positiva.** Por eso no se crea ni un fixture
umbrella ni varios: crear fixtures para comportamientos ausentes de la
evidencia esta explicitamente fuera del alcance de este turno.

---

## 4. El bloqueo `CASAS_CAMAS_DOCKER_RETEST_PENDIENTE`

### 4.1 Su origen

Aparece por primera vez en `worklog/EVENTS.jsonl` en el cierre de Phase 1H
(`CIERRE_QA_V2_TAXONOMY`, 2026-09-10), donde se lo reclasifica como *"deuda
operativa de una certificacion `LEGACY_LIVE_MUTATING` especifica"*. Desde
entonces viaja arrastrado en el campo `blockers` de practicamente todos los
cierres de QA, **sin que nadie volviera a evaluar su contenido**.

### 4.2 El bloqueo estaba MAL ETIQUETADO

Su nombre dice **Docker retest**. La causa real **no era Docker**.

El documento historico planteaba dos hipotesis: que la baldosa no quedara en
`ZONE_PROTECTION`, o que faltara un permiso de casa. **Las dos eran
incorrectas.**

La causa real esta hoy documentada **en el propio codigo del servidor**,
`servidor/src/game.cpp`, en el comentario de la guarda de uso:

```cpp
// Beds are the same story: their OTB entry is not marked useable and they
// have no registered Action, but Actions::internalUseItem handles them by
// dispatching on item->getBed() (actions.cpp:198). Without this exception
// every bed use was rejected right here, before BedItem::canUse ever ran.
const ItemType& useItemType = Item::items[item->getID()];
if (!item->isUseable() && !item->getContainer() && !item->getDoor()
        && !useItemType.canReadText && !item->getBed() && !g_actions->hasAction(item)) {
    player->sendCancelMessage(RETURNVALUE_CANNOTUSETHISOBJECT);
    return;
}
```

El comentario describe **exactamente** el sintoma historico: la cama se
rechazaba **antes** de que `BedItem::canUse` llegara a ejecutarse. Es la misma
familia de defecto que bloqueaba el correo en Phase 2F, y la correccion
(`&& !item->getBed()`) **ya esta aplicada**.

Es decir: **la condicion tecnica que origino el bloqueo esta resuelta**, y se
resolvio en el carril `servidor`, no reejecutando Docker.

### 4.3 Por que el bloqueo NO se cierra igualmente

Que la causa original este resuelta **no** habilita la certificacion, porque
aparecio una condicion distinta y mas precisa. **No se cierra un bloqueo porque
su etiqueta haya quedado obsoleta**; se lo reemplaza por su condicion real.

`BedItem::canUse` (`servidor/src/bed.cpp:79-102`) exige, en este orden:

| Requisito | Estado para participantes de QA |
|---|---|
| la cama pertenece a una casa | depende de la casa |
| `player->isPremium()` | **NO se cumple** |
| `getZone() == ZONE_PROTECTION` | alcanzable |
| mitad activa de la cama (`partnerDirection` sur/este) | se cumple (la cama historica es `south`) |
| sin `CONDITION_INFIGHT` | alcanzable |

Con `freePremium = false` en `servidor/config.lua` y `housesOnlyPremium = true`,
un participante normal de QA **no es premium** y **no posee ninguna casa**.

Para certificar en vivo habria que hacer una de estas tres cosas, y **las tres
estan prohibidas por este turno**:

| Via | Por que esta prohibida |
|---|---|
| conceder premium a una cuenta de QA | mutacion de cuenta |
| asignar una casa a un personaje de QA | *"Do not overwrite house ownership"* |
| usar el operador, que si es premium por bandera de grupo y figura como dueno de una casa | ese personaje vive en la **cuenta personal del usuario**, y dormir mutaria la cama, su posicion, su vida/mana via `regeneratePlayer` y lo forzaria a desconectarse: **estado real del usuario** |

### 4.4 Un motivo adicional, y de peso, para no usar el operador

La casa que el operador figura poseyendo es **la casa 6**, exactamente la que
el documento historico dice haberle asignado **temporalmente**, prometiendo
*"deja owner y premium restaurados al finalizar"*.

La base de datos actual muestra que **esa casa sigue asignada al operador**. O
la restauracion no ocurrio, o nunca fue temporal. En cualquier caso:

**construir un fixture de paridad sobre esa casa seria construir evidencia
encima de un residuo de QA sin restaurar.** El fixture pareceria verde mientras
el residuo existiera y se caeria en silencio en cuanto alguien lo limpiara. Es
precisamente el tipo de dependencia oculta que el resto del corpus evita.

### 4.5 Tratamiento del bloqueo

Se aplica la opcion **C**: el bloqueo original era **demasiado amplio y estaba
mal atribuido**. Se lo reemplaza por su condicion real, mas estrecha:

- **`CASAS_CAMAS_DOCKER_RETEST_PENDIENTE`** → se declara **superado en su
  causa tecnica**: el rechazo de cama era un defecto de `game.cpp`, ya
  corregido, y **no** una cuestion de Docker.
- **`CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA`** → bloqueo **nuevo y
  preciso**: no existe un participante dedicado de QA que sea premium y posea
  una casa, y crearlo exige una mutacion prohibida.

**La historia no se reescribe.** Los eventos previos que arrastraban el bloqueo
antiguo quedan intactos; esta reclasificacion se registra como evento
compensatorio append-only.

---

## 5. Dependencias de entorno y datos

### 5.1 Verificado, solo lectura

| Fuente | Hecho relevante |
|---|---|
| `servidor/data/world/map-house.xml` | la casa 6 existe, con su entrada declarada |
| `servidor/data/items/items.xml` | la cama historica es `type=bed` con `partnerDirection=south`, o sea la **mitad activa** que `canUse` exige |
| `servidor/config.lua` | `freePremium = false`, `housesOnlyPremium = true` |
| `servidor/data/XML/groups.xml` | `isalwayspremium` solo en los grupos elevados |
| base de datos | solo **dos** casas tienen dueno, y ninguna pertenece a un participante de QA |

**No se modifico ninguno de estos archivos ni la base de datos.**

### 5.2 Sobre la limpieza declarada en el documento

El documento afirma que restauro propietario y premium. El estado actual **no
lo confirma** para el propietario. Se registra como **observacion**, no como
acusacion: pudo restaurarse y volver a asignarse despues por otra via. Lo que
importa para este turno es que **no se puede depender de ello**.

---

## 6. Analisis de falso positivo, aunque no haya fixture

Se documenta porque condiciona el diseno de cualquier turno futuro. Si alguna
vez se certifica este dominio, cada afirmacion necesita su control:

| Afirmacion futura | Falso positivo trivial | Control obligatorio |
|---|---|---|
| "el jugador durmio" | la cama nunca se uso y el jugador simplemente se desconecto | probar la **transicion**, no el estado final |
| "la cama quedo ocupada" | ya estaba ocupada por otro | **linea base** de la cama antes de usarla |
| "desperto correctamente" | nunca llego a dormir | probar primero el **positivo** de dormir |
| "hubo regeneracion" | la vida ya estaba llena, o no paso tiempo suficiente | vida **por debajo** del maximo y intervalo medido |
| "persiste" | el estado nunca se muto | mutar y **despues** cruzar la frontera |
| "la casa restringe el acceso" | la casilla era inalcanzable por un motivo ajeno | probar que un autorizado **si** entra |

La ultima fila es la misma leccion de Phase 2E y 2C.1: **alcanzable no es lo
mismo que permitido**, igual que aislado no era lo mismo que habitable.

### 6.1 Y la trampa especifica de la persistencia

Si alguna vez se afirma persistencia de cama, hay que nombrar **cual** frontera
se cruzo. Son propiedades distintas y no se implican entre si:

1. sobrevive a la reconexion del jugador;
2. sobrevive al reinicio del proceso del servidor;
3. sobrevive a un reinicio con recarga desde la base;
4. sobrevive a recrear el contenedor.

El documento historico no cruza **ninguna**.

---

## 7. Lo que este turno NO hizo, a proposito

- **No** se creo un fixture vacio para que el conteo subiera.
- **No** se convirtio el rechazo historico en `RECORDED_EVIDENCE`.
- **No** se asigno ninguna casa, ni se concedio premium, ni se toco ninguna
  lista de invitados.
- **No** se durmio en ninguna cama ni se desalojo a ningun durmiente.
- **No** se creo ninguna cuenta ni personaje.
- **No** se toco `servidor/`, ni produccion de cliente, ni Docker, ni la base.
- **No** se reescribio `PRUEBA_VIVA_CASA_CAMA.md`: es evidencia historica.
- **No** se cerro el bloqueo antiguo en silencio.

Mutaciones de este turno: **cero**. Muertes, combate, monstruos, comandos
amplios: **cero**. Contenedores Docker tocados: **cero**.

---

## 8. Inventarios

**Sin cambio**, porque no se materializo ningun artefacto:

| Inventario | Valor |
|---|---:|
| Obligaciones Architecture V2 | 198 especificadas / **0** materializadas |
| Fixtures `LEGACY_PARITY` | **14** |
| Casos de replay | **14** |
| Observaciones `RECORDED_EVIDENCE` | **9** |
| Observaciones `LIVE_ORACLE` | **11** |

Phase 2 sigue **EN CURSO**. Contrato `qa` sigue en **2.1.1**.

---

## 9. Propiedades de casa y cama que siguen sin certificar

**Todas.** El dominio no tiene ninguna cobertura de paridad:

- restriccion de acceso a una casa segun propiedad o invitacion;
- uso de cama y entrada al estado de dormir;
- ciclo de despertar;
- regeneracion asociada a dormir;
- persistencia del durmiente en cualquiera de sus cuatro fronteras;
- dependencia del uso de cama respecto de la propiedad de la casa;
- comportamiento con la cama ya ocupada;
- diferencia entre las dos mitades de la cama.

---

## 10. Recomendacion exacta para el proximo turno de Phase 2

**No** tomar casa/cama todavia. Requiere primero una decision de entorno que
excede al carril `qa`:

> conseguir un participante **dedicado de QA** que sea premium y posea una
> casa, **sin** tocar cuentas ni casas del usuario.

Eso es una peticion para los carriles `integracion` / `servidor`, y **no** debe
resolverla QA por su cuenta mutando estado ajeno. Registrado como bloqueo
preciso en `worklog/qa/STATE.md`.

Mientras tanto, el corpus tiene opciones con evidencia real:

1. **`PARITY-HOUSE-ACCESS-001`** — la restriccion de acceso a una casa se puede
   probar **sin poseer ninguna**: un participante de QA intenta entrar a una
   casa ajena y el servidor lo impide, con el control positivo de que la
   casilla **si** es alcanzable para quien corresponde. **No** tiene evidencia
   historica, asi que seria `LIVE_ORACLE` unicamente, como ya lo son
   `PARITY-TRADE-CANCEL-001` y los negativos de experiencia compartida. Es la
   unica parte del dominio que no exige propiedad ni premium.
2. Cerrar huecos declarados de dominios ya abiertos, todos sin evidencia
   historica y por lo tanto `LIVE_ORACLE` unicamente: borde del alcance de
   comercio, cancelacion implicita por desconexion, baja y duplicado de
   contactos.

La opcion 1 es la de mayor valor: abre un dominio nuevo, no depende de ningun
residuo y no necesita ninguna mutacion prohibida.
