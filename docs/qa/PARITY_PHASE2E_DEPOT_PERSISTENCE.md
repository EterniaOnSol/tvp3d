# Phase 2E — Paridad de persistencia del deposito (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay grabado **`PASS 10/10`** y replay vivo
**`PASS 10/10`**, los dos con el comparador generico sin modificar.

`PARITY-DEPOT-PERSISTENCE-001` abre el **cuarto dominio de comportamiento** del
corpus de paridad.

## 1. Por que el deposito es un dominio distinto

Los tres dominios ya certificados miden cosas que ocurren **dentro** de una
sesion:

| Dominio | Que mide | Vive dentro de |
|---|---|---|
| Muerte / corpse / contenedores | resultado autoritativo de una muerte | una sesion |
| Reacquisicion de objetivo | memoria de objetivo del monstruo | una sesion |
| Party / experiencia compartida | elegibilidad y reparto | una sesion |
| **Deposito** | **persistencia autoritativa del servidor** | **CRUZA la frontera de sesion** |

Este es el primero que solo puede probarse **saliendo y volviendo a entrar**.
Lo que se certifica no es "un contenedor acepta objetos" sino que **el servidor
guarda estado de jugador y lo devuelve intacto en una sesion nueva**. Es la
propiedad que el TVP3D nativo va a tener que reproducir con su propia
arquitectura de persistencia.

## 2. Evidencia historica

`docs/qa/PRUEBA_VIVA_DEPOT.md` (2026-08-29) es una corrida viva genuina contra
TVP 7.72 y es la fuente **unica** de la observacion `RECORDED_EVIDENCE`.

Su salida literal:

```text
Contenedor 2: 'depot chest' con 2 cosas.
  OK  pisar la baldosa carga el depot del jugador, con su cofre
Contenedor 2: 'depot chest' con 3 cosas.
  OK  el objeto entra al depot
Sesion cerrada. Se vuelve a entrar para ver si el depot guardo.
Contenedor 2: 'depot chest' con 3 cosas.
  OK  el depot vuelve a abrirse en la sesion nueva
  OK  EL OBJETO SIGUE EN EL DEPOT DESPUES DE RECONECTAR
  OK  el objeto sale del depot y vuelve a la mochila
Prueba viva del depot: OK
```

`cliente3d/pruebas/prueba_depot_vivo.gd` es la implementacion historica de ese
recorrido. **No se toco**: no se convirtio en el adaptador de paridad, se creo
uno nuevo.

## 3. La regla, leida del codigo vigente del oracle

### 3.1 La activacion es por ENTRADA a la baldosa

`servidor/data/scripts/movements/other/tiles.lua`, `moveeventStepIn`:

```lua
if Tile(position):hasFlag(TILESTATE_PROTECTIONZONE) then
    for x = -1, 1 do for y = -1, 1 do
        local depotItem = Tile(pos):getItemByType(ITEM_TYPE_DEPOT)
        if depotItem then
            creature:loadDepotLocker(getDepotId(depotItem:getUniqueId()))
            ...
            if position.x ~= fromPosition.x or ... then
                creature:sendTextMessage(MESSAGE_STATUS_DEFAULT,
                    "Your depot contains " .. depotItems .. " item" ...)
```

Puntos verificados, no supuestos:

| Propiedad | Valor |
|---|---|
| Disparador | `onStepIn`: **no** se dispara si el personaje ya estaba parado ahi |
| Requisitos | `creature:isPlayer()`, **no** estar en modo fantasma, baldosa en **zona de proteccion**, item de tipo depot en el **3x3** |
| Efecto | `Player::loadDepotLocker` (`player.cpp:763-777`) deja `currentDepotItem` apuntando al locker **de ese jugador** |
| Aviso | El mensaje `"Your depot contains N item(s)."` sale **solo si la posicion cambio**, es decir solo en una entrada real |
| Salida | `onStepOut` llama `unloadDepotLocker` (`player.cpp:779-789`), que pone `currentDepotItem` en null: **salir desactiva de verdad** |

### 3.2 Deposito PERSONAL contra MUEBLE DEL MAPA

Esta es la trampa del dominio, y es la razon por la que "se abrio un
contenedor" **no se acepta como prueba**. `servidor/src/actions.cpp:221-234`:

```cpp
if (container->getDepotLocker()) {
    if (DepotLocker* myDepotLocker = player->currentDepotItem) {
        openContainer = myDepotLocker;
        if (myDepotLocker->getItemTypeCount(ITEM_DEPOT) == 0) {
            myDepotLocker->addItem(Item::CreateItem(ITEM_DEPOT, 1));
        }
    } else {
        // Open depot as normal container
        openContainer = container;
    }
}
```

Sin activacion, el servidor abre **el mueble del mapa como contenedor comun**.
Se ve igual, **tambien acepta objetos**, y lo que se guarde ahi no es de nadie.
Un fixture que solo comprobara "el contenedor abrio y acepto el objeto" seria
un **falso positivo**.

Por eso esta captura exige **dos** senales independientes, las dos externas:

1. el **aviso autoritativo** `"Your depot contains ..."`, que el servidor manda
   dentro de la **misma rama** que llama a `loadDepotLocker`;
2. que al abrir el mueble aparezca adentro el **cofre de deposito**, que
   `actions.cpp:225-227` crea **solo** sobre el locker personal.

Ninguna de las dos usa estado interno: no se serializa `currentDepotItem`, ni
punteros, ni ids de contenedor.

### 3.3 Lo guardado vive en el cofre interno

El locker solo envuelve. El contenedor real es el `ITEM_DEPOT` de adentro.

### 3.4 Donde persiste

`IOLoginData` serializa el deposito **dentro del archivo del propio jugador**,
una linea por locker (`iologindata.cpp:767-784`):

```
Depot = (<depotId>, { ...items... })
```

y lo vuelve a construir al leer el archivo con `getDepotLocker(depotId, true)`
(`iologindata.cpp:467-495`). Es persistencia **por jugador**, no por mapa.

### 3.5 El god no cambia la semantica — verificado, no supuesto

Lo unico que depende del grupo es la **capacidad**:
`Player::getMaxDepotItems` (`player.cpp:3876-3883`) usa `group->maxDepotItems`
**solo si no es 0**, y en `servidor/data/XML/groups.xml` **todos** los grupos lo
tienen en `0`, asi que todos caen al limite de `config.lua`
(`depotFreeLimit = 1000` / `depotPremiumLimit = 2000`). El camino de guardado y
de carga es identico para un jugador normal.

**Conclusion:** no hace falta un god como sujeto. El `DEPOT_SUBJECT` de esta
captura es un **personaje normal dedicado de QA**; el operador con permisos
solo lo **posiciona** y no toca ningun objeto.

## 4. Sujeto e identidad

| Rol | Quien | Por que |
|---|---|---|
| `DEPOT_SUBJECT` | personaje **normal** dedicado de QA, en una cuenta que contiene solo personajes de QA | es su deposito el que se muta y se restaura |
| operador | personaje con permisos, **solo** `/gotopos` y `/c` | dos criaturas no comparten casilla y el sujeto tiene que caminar por su cuenta |

**0 personajes del usuario como sujeto. 0 cuentas creadas. 0 personajes
creados.** Credenciales **solo por entorno**, a traves del helper
`cliente3d/pruebas/credenciales_qa.gd` publicado en el turno anterior; sin la
variable requerida la captura corta con `BLOCKED` **antes** de conectarse
(verificado: codigo 2 y 0 lineas de conexion).

## 5. Objeto de prueba: se reusa, no se crea

**No se crea ningun objeto.** El sujeto ya posee uno que cumple todo lo que
pide un buen testigo:

| Requisito | Se cumple |
|---|---|
| Propiedad del sujeto | si, viene del estado de creacion normal del perfil |
| Movible | si |
| **No apilable** | si — `servidor/data/items/items.xml` no le declara `plural`, a diferencia por ejemplo de la manzana del mismo equipo inicial, que si es acumulable |
| No es contenedor | si |
| Identificable sin ambiguedad | si, por tipo y por relaciones de cantidad |
| Restituible a su lugar exacto | si, vuelve a su ranura de equipo original |

Se descarto el otro candidato del inventario inicial justamente por ser
**apilable**: el servidor puede partir o juntar pilas y eso mediria otra cosa.

`test_items_created = 0`. La especie concreta es **metadata del harness**
(configurable por `TVP772_DEPOT_TEST_ITEM`) y **no entra** al payload.

## 6. Identidad por cantidades, nunca por nombre suelto

Todas las afirmaciones son **relaciones antes/despues**:

| Momento | Relacion exigida |
|---|---|
| Guardar | cofre `N -> N+1`, y el origen queda vacio |
| Tras la frontera de sesion | cofre **sigue** en `N+1` |
| Recuperar | cofre `N+1 -> N`, mochila `M -> M+1` |

Asi la existencia de copias viejas del mismo tipo de objeto no puede producir
un falso positivo. **Ninguna cantidad absoluta entra al payload.**

## 7. La frontera de sesion tiene que ser real

No se simula nada. **No** se vacia el estado local, **no** se reabre el mismo
contenedor, **no** se reconstruye la interfaz y **no** se arma un segundo
objeto de estado sobre la misma sesion.

La primera sesion manda el **logout legacy `0x14`**, se espera a que el socket
quede efectivamente cerrado, y recien entonces se abre una conexion de login y
de juego **completamente nueva**, con su propio `EstadoMundo`.

Y como el personaje queda parado **sobre la baldosa** al desconectarse, en la
sesion nueva se **sale y se vuelve a entrar**: `onStepIn` no se dispara al
conectarse, asi que sin ese paso la reactivacion no seria real. El `onStepOut`
del paso intermedio ademas **desactiva** el deposito explicitamente, con lo
cual la reactivacion no puede ser una herencia de la sesion anterior.

## 8. Artefactos

| Artefacto | Ruta |
|---|---|
| Fixture | `qa/parity/fixtures/tvp772/depot_persistence/parity-depot-persistence-001.json` |
| `QACase` | `qa/parity/cases/tvp772/depot_persistence/parity-depot-persistence-001.case.json` |
| `RECORDED_EVIDENCE` | `qa/parity/observations/tvp772/depot_persistence/recorded/parity-depot-persistence-001.observation.json` |
| Captura | `cliente3d/pruebas/prueba_parity_depot_persistence_capture.gd` + `.tscn` |
| Observacion viva | `qa/parity/observations/tvp772/depot_persistence/live/parity-depot-persistence-001.observation.json` |
| Reporte grabado | `qa/parity/reports/replay_recorded_depot_persistence_report.json` |
| Reporte vivo | `qa/parity/reports/replay_live_depot_persistence_report.json` |

`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, clasificacion
`MATCH_EXPECTED`. `tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`,
`SINGLE_OBSERVATION`, `case_id == fixture_id`. **Sin cambios de schema.**

### 8.1 Diez aserciones, no once — y por que

La propuesta de partida traia **once** aserciones. Se congelaron **diez**.

La que se saco es
`/store/source_test_item_count_decreased_by_one`. Motivo: la evidencia
historica **no la demuestra**. `PRUEBA_VIVA_DEPOT.md` mide y reporta
unicamente la cuenta del cofre al guardar (`El cofre pasa de N a N+1`, y la
salida real muestra `2 cosas` -> `3 cosas`); **nunca** midio ni publico la
cuenta del origen. Como el `QACase` se replaya contra **las dos**
observaciones con el **mismo** juego congelado de aserciones, incluirla habria
obligado a fabricar un hecho grabado que nadie observo.

La captura viva **si** comprueba que el objeto salio de su origen, y aborta si
no lo hace, pero como **guarda del harness**, no como asercion congelada. La
diferencia importa: una guarda protege la corrida, una asercion afirma algo
sobre el oracle.

Las diez congeladas, todas `EQ` y todas respaldadas linea por linea por la
evidencia historica:

| # | Puntero | Respaldo en `PRUEBA_VIVA_DEPOT.md` |
|---:|---|---|
| 1 | `/initial_session/personal_depot_loaded` | `OK pisar la baldosa carga el depot del jugador, con su cofre` |
| 2 | `/initial_session/depot_chest_opened` | `Contenedor 2: 'depot chest' con 2 cosas.` |
| 3 | `/store/test_item_present_before_store` | fila `Objeto` de la tabla de recorrido |
| 4 | `/store/depot_test_item_count_increased_by_one` | `2 cosas` -> `3 cosas` + `OK el objeto entra al depot` |
| 5 | `/session_boundary/first_session_closed` | `Sesion cerrada.` |
| 6 | `/session_boundary/new_session_established` | `Se vuelve a entrar...` + el depot reabierto en la sesion nueva |
| 7 | `/after_relogin/personal_depot_reloaded` | `OK el depot vuelve a abrirse en la sesion nueva` |
| 8 | `/after_relogin/stored_test_item_still_present` | `OK EL OBJETO SIGUE EN EL DEPOT DESPUES DE RECONECTAR` |
| 9 | `/recovery/depot_test_item_count_decreased_by_one` | fila `Devolver`: `El cofre vuelve a N` |
| 10 | `/recovery/inventory_test_item_count_increased_by_one` | fila `Devolver`: `y la mochila suma uno` |

### 8.2 Replay contra evidencia grabada

`qa/parity/tools/replay.py` **sin modificar**: **`PASS 10/10`**, codigo 0,
reporte **byte-identico** entre dos corridas
(`sha256 08e8672575fa16bc9248907a2a803d58b853e8106fb1dd94b541f9b980387d59`).

El comparador generico acepto un **quinto** dominio de comportamiento sin
ningun cambio.

## 9. Geometria operativa

| Punto | Coordenada | Rol |
|---|---|---|
| Baldosa de activacion | `(32354, 32230, 7)` | hay que **entrar**, no basta con estar |
| Mueble del deposito | `(32354, 32231, 7)` | adyacente a la baldosa |
| Casilla contigua | `(32355, 32230, 7)` | punto de salida para poder entrar |

Es el deposito de Thais, sacado del mapa del propio servidor. Son **metadata
del harness**: no entran al fixture, ni al `QACase`, ni a las observaciones.

## 10. Congelamiento previo a la corrida viva

SHA-256 calculados **antes** del primer intento contra el oracle:

| Artefacto | SHA-256 |
|---|---|
| fixture | `5281d558f1396b6c3f3c377be5672028147e6347b7915f081d4b7b7f6d603a17` |
| `QACase` | `e9f4c8595191fd28a79833dfbf0c920081879d02962664bd2248cf4673fa983f` |
| observacion grabada | `2e275ee8981780e14bcf3128667e85496e12bee9714a2e7e278a336b15aea1cd` |
| captura `.gd` (final, la que produjo la observacion) | `440e15a686d4d0cd8cea6753f674930732673c4028bec4fdf85efda7b37136b2` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en Phase 2D, 2D.1 y
2D.2.

El adaptador se **recongelo dos veces** durante el turno, despues de cada
salida de preflight (`c383910b…` -> `1d58bcb8…` -> `440e15a6…`). Los tres
artefactos de **expectativa** de arriba —fixture, `QACase` y observacion
grabada— quedaron **byte-identicos desde antes del primer lanzamiento hasta
despues del ultimo**: lo que cambio fue como el harness llega al deposito,
nunca lo que se afirma sobre el oracle.

Verificacion previa sin tocar el oracle: el adaptador **compila** en Godot
headless (`--check-only`, codigo 0) y la escena arranca y corta limpio en la
guarda de credenciales (codigo **2**, con **0** lineas de conexion).

## 11. Resultado en vivo — **CERTIFICADO**

Codigo de salida 0 y **exactamente una** linea `OBSERVATION_JSON`.

### 11.1 Los tres lanzamientos, sin maquillaje

Se lanzaron **tres** corridas. Las dos primeras **no llegaron a medir nada**:
murieron en el posicionamiento, antes de tocar el deposito, antes de guardar y
antes de cualquier frontera de sesion. Segun la propia definicion de la tarea
son **salidas de preflight**, no intentos de oracle completados; se reportan
igual, en detalle, porque cada una encontro un defecto real del harness.

| # | Hasta donde llego | Causa | Correccion |
|---:|---|---|---|
| 1 | posicionamiento | El operador seguia parado en la casilla de salida: el sujeto pidio caminar ahi y el servidor contesto `There is not enough room` | Esperar a que el operador **se haya ido de verdad** antes de mover al sujeto, y reintentar la orden de caminata |
| 2 | posicionamiento | **La casilla de salida historica `(32355,32230,7)` no es caminable** para un personaje normal | Descubrir la casilla de salida **empiricamente** entre las vecinas, en vez de fijarla por constante |
| 3 | **completa** | — | **exito** |

El hallazgo del intento 2 merece quedar escrito, porque es el mismo tropiezo
que Phase 2C.1 ya habia documentado con otras palabras: **aislado no es lo
mismo que habitable**. La evidencia historica llegaba a esa casilla con
`/gotopos` de un god, que teletransporta a cualquier lado; un personaje normal
que intenta **caminar** hasta ahi recibe `There is not enough room`. Heredar la
constante sin comprobarla habria sido heredar una suposicion.

**La expectativa NUNCA se modifico.** Verificado por hash: el fixture
(`5281d558…`), el `QACase` (`e9f4c859…`) y la observacion grabada
(`2e275ee8…`) son **byte-identicos** antes del primer lanzamiento y despues del
tercero. Lo unico que cambio entre intentos fue el **adaptador**, y se
recongelo cada vez: `c383910b…` -> `1d58bcb8…` -> `440e15a6…`, siendo este
ultimo el que produjo la observacion certificada.

### 11.2 Cronologia observada (intento 3)

| Etapa | Observacion |
|---|---|
| Posicionamiento | El operador lleva al sujeto al area y **se aparta**; el sujeto queda en una casilla vecina |
| Entrada | El sujeto **camina** hacia la baldosa y entra |
| Activacion | `"Your depot contains 1 item."` — el servidor confirma la carga del deposito **personal** |
| Mueble | `'locker'` con **1** cosa |
| Cofre | `'depot chest'` con **0** cosas |
| Guardado | cofre **0 -> 1**, y la ranura de origen **queda vacia** |
| Cierre | logout legacy; **el socket de juego queda cerrado** |
| Sesion nueva | login y conexion de juego **nuevas**; el sujeto vuelve al mundo |
| Reactivacion | el sujeto aparece **sobre** la baldosa; **sale** y **vuelve a entrar** |
| Activacion 2 | `"Your depot contains 2 items."` — ahora la cuenta es real |
| Persistencia | `'depot chest'` con **1** cosa: **el objeto sobrevivio** |
| Recuperacion | cofre **1 -> 0**, mochila **3 -> 4** |
| Restauracion | el objeto vuelve a su ranura de equipo original: **true** |

Duracion total: **~30 s**.

Detalle que vale la pena anotar: el aviso de la primera activacion dice
`1 item` con el cofre **vacio** porque `tiles.lua` usa
`math.max(1, getItemHoldingCount())`, o sea que **1 es un piso**, no una
cuenta. En la reactivacion dice `2 items`, que si es la cuenta real: el cofre
mas el objeto guardado. El fixture no congela ese texto justamente por esto.

### 11.3 Corroboracion independiente desde el archivo de persistencia

Esto **no** pasa por el camino de observacion del cliente: se leyo
`servidor/gamedata/players/<id>.tvpp` **mientras la primera sesion ya estaba
cerrada y la segunda todavia no existia**.

| Momento | Linea `Depot` del archivo |
|---|---|
| Antes del turno | *(no existia)* |
| Tras el intento 1 (solo activacion) | `Depot = (1, {})` |
| **Con la primera sesion cerrada** | **`Depot = (1, {2594 Content={2382}})`** |
| Al terminar | `Depot = (1, {2594 Content={}})` |

La linea del medio es la prueba directa de que el servidor **escribio la
mutacion a disco** antes de que existiera la sesion nueva: el cofre de
deposito (`2594`, `ITEM_DEPOT`) conteniendo el objeto de prueba (`2382`). En
ese mismo instante la linea del equipo del sujeto **no tenia** el objeto.

Esto es **evidencia de apoyo documental**, no semantica de paridad: no se
agrego ningun campo al fixture por esto, ni se congelo ninguna forma de
archivo. El hecho decisivo sigue siendo el de la observacion: la sesion nueva
recarga el deposito y ve el objeto.

### 11.4 Mutaciones, limpieza y residuo declarado

| Concepto | Valor |
|---|---|
| Objetos de prueba creados | **0** — se reuso uno que el sujeto ya tenia |
| Objetos del usuario tocados | **0** |
| Personajes del usuario usados como sujeto | **0** |
| Cuentas / personajes creados | **0** |
| Credenciales cambiadas | **0** |
| Combate / ataques | **0** |
| Monstruos invocados | **0** |
| Muertes de jugador | **0** |
| Usos de `/killall` | **0** |
| Delta neto de inventario del sujeto | **0** — el objeto volvio a su ranura original, verificado en el archivo persistido |
| `OBSERVATION_JSON` emitidos | **1** |

**Residuo declarado:** el deposito del sujeto queda con un **cofre de deposito
vacio** (`Depot = (1, {2594 Content={}})`) que antes de este turno no existia.
No lo creo QA: lo crea el propio servidor en `actions.cpp:225-227` la primera
vez que se abre un deposito personal cargado. Es el estado normal de cualquier
jugador que haya abierto su deposito una vez, es **solo del sujeto de QA**, y
no se intento borrarlo porque no existe un mecanismo probado para hacerlo y
inventar uno seria peor que declararlo.

Tambien queda declarado que el sujeto termina **parado sobre la baldosa del
deposito**, que es donde lo dejo la medicion.

### 11.5 Replay y congelamiento

- Replay contra **evidencia grabada**: **`PASS 10/10`**, byte-identico entre
  dos corridas
  (`sha256 08e8672575fa16bc9248907a2a803d58b853e8106fb1dd94b541f9b980387d59`).
- Replay contra **observacion viva**: **`PASS 10/10`**, byte-identico entre dos
  corridas
  (`sha256 5a6db82b7950dc30fbb3a87d34092f68205859be43de07ecc46854d987ffa0f2`).
- Los **8 hashes congelados** de la seccion 10 se recalcularon despues de la
  corrida viva, del wrap y de los cuatro replays: **identicos los ocho**.
- `replay.py` y `wrap_live_observation.py` **no se modificaron**: aceptaron un
  **quinto** dominio de comportamiento sin ningun cambio.

### 11.6 Credenciales

Ninguna credencial se imprimio, se guardo ni se versiono. El adaptador las lee
**solo** por entorno a traves del helper publicado en el turno anterior, y sin
la variable requerida corta con `BLOCKED` y codigo **2** antes de abrir ningun
socket (verificado: **0** lineas de conexion).

## 12. Lo que este fixture NO afirma

- **No** certifica el particionado de pilas: el objeto es entero a proposito.
- **No** certifica el tope de capacidad del deposito (`getMaxDepotItems`).
- **No** certifica mas de un pueblo: solo se ejercito un deposito.
- **No** certifica la entrega por correo ni por parcel.
- **No** congela ningun indice de ventana de contenedor del cliente: en que
  ventana se abre cada contenedor es decision del cliente, no del oracle.
- **No** afirma el valor de ninguna variable interna del servidor, en
  particular `currentDepotItem`.
- **No** afirma nada sobre la forma del archivo de persistencia.

## 13. Suciedad historica que NO se toca

`PRUEBA_VIVA_DEPOT.md` (lineas 91-93) deja constancia de que las corridas
fallidas del 2026-08-29, anteriores a entender lo de la baldosa, dejaron **dos
parcels dentro del mueble del mapa**.

Este turno **no las saca**, **no las cuenta** como parte del deposito personal
y **no deja** que confundan la prueba: el deposito personal se identifica por
las dos senales de la seccion 3.2, no por el contenido del mueble. Son deuda
historica de entorno y limpiarlas no es trabajo de este fixture.
