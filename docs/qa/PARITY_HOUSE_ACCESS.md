# `PARITY-HOUSE-ACCESS-001` — Restriccion de acceso a una casa (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay vivo **`PASS 4/4`**, byte-identico
entre dos corridas, con el comparador generico sin modificar.

Fixture `LEGACY_PARITY` dentro de **Phase 2 — build parity fixtures against
TVP**. No abre fase ni sub-fase nueva y **no toca**
`docs/tibia3d/MASTER_PLAN.md`.

## 1. Que se certifica, y con que limite

> A un jugador normal **sin autorizacion** sobre una casa el servidor legacy le
> **impide entrar** por la via de movimiento ordinaria ejercitada, y el jugador
> **permanece afuera**.

Nada mas. La seccion 9 enumera lo que queda sin certificar.

## 2. Por que este fixture es independiente de camas y de premium

El turno anterior cerro con `NO_VALID_FIXTURE` y dejo abierto el bloqueo
**`CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA`**, porque
`BedItem::canUse` (`servidor/src/bed.cpp:79-102`) exige `isPremium()` y que la
cama pertenezca a una casa, y QA no puede fabricar esas condiciones.

**El control que mide este fixture vive en otro lugar del codigo y no consulta
premium en ningun momento.** `Tile::queryAdd` (`servidor/src/tile.cpp:481-489`):

```cpp
if (house) {
    if (const Player* player = creature->getPlayer()) {
        if (!house->isInvited(player)) {
            return RETURNVALUE_PLAYERISNOTINVITED;
        }
    } else {
        return RETURNVALUE_NOTPOSSIBLE;
    }
}
```

Y `House::isInvited` (`house.cpp:307-310`) es simplemente
`getHouseAccessLevel(player) != HOUSE_NOT_INVITED`, donde el nivel
(`house.cpp:154-183`) se resuelve por **dueno**, **subdueno** o **invitado**.
**Ninguna de esas ramas mira `isPremium()`.**

> **Esta certificacion NO resuelve el bloqueo de camas.**
> `CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA` **sigue abierto, sin
> cambios**. Son propiedades distintas, en ramas distintas del servidor, y una
> no implica la otra.

### 2.1 Semantica de origen verificada

| Pregunta | Respuesta verificada |
|---|---|
| Que hace que una casilla sea de una casa | la casilla tiene `house` asignada; la pertenencia **no viaja al cliente** |
| Que regla se consulta al entrar | `House::isInvited`, via `Tile::queryAdd` |
| Donde se controla | en el **movimiento a la casilla**, no en una puerta |
| Niveles de acceso | `HOUSE_OWNER`, `HOUSE_SUBOWNER`, `HOUSE_GUEST`, `HOUSE_NOT_INVITED` (`house.h:84-87`) |
| Premium afecta la ENTRADA | **no** |
| Respuesta al denegar | `RETURNVALUE_PLAYERISNOTINVITED`, que el cliente recibe como mensaje |
| El jugador queda donde estaba | **si** |
| Bypass de privilegio | `PlayerFlag_CanEditHouses` devuelve `HOUSE_OWNER` (`house.cpp:166-168`) |

Ese ultimo punto es la razon por la que **el operador no puede ser el
participante**: su bandera lo eximiria del control y el fixture mediria nada.

Nota adicional: `Tile::queryDestination` (`tile.cpp:788-812`) **redirige** a un
no invitado hacia la posicion de entrada de la casa si llegara a terminar
dentro. Eso implica que la posicion de entrada es, por construccion, una
casilla **fuera** de la casa; si fuera parte de ella el redireccionamiento
seria un bucle. Ese hecho se usa para elegir el punto de partida.

## 3. Sin `RECORDED_EVIDENCE`, y se verifico antes de decidir

Se busco evidencia historica de rechazo de entrada por falta de autorizacion en
todo `docs/qa/`. La **unica** coincidencia es
`docs/qa/AUDITORIA_CASA_CAMA_PARIDAD.md`, que es **el documento de auditoria
del turno anterior**, no una observacion historica de runtime.

`docs/qa/PRUEBA_VIVA_CASA_CAMA.md` **no observa** este comportamiento: su unica
observacion de runtime es el rechazo de una **cama**, que ademas era un defecto
ya corregido.

**`RECORDED_EVIDENCE`: NO.** Este fixture es **`LIVE_ORACLE` unicamente**, como
ya lo son `PARITY-TRADE-CANCEL-001` y los negativos de experiencia compartida.
El corpus grabado queda en **9**, sin cambio.

## 4. El problema real: distinguir el rechazo, no provocarlo

Que un jugador no se mueva es un resultado **trivial**. Lo produciria igual una
pared, un borde de mapa, una casilla ocupada, una coordenada mal elegida, una
peticion de movimiento perdida o una sesion caida.

Por eso el fixture no se conforma con "no me movi" y exige **dos** cosas
independientes.

### 4.1 Control positivo

Inmediatamente antes de medir, el participante realiza un desplazamiento
ordinario que el **servidor confirma**. Eso descarta que la via de movimiento
estuviera rota.

### 4.2 El discriminador: una respuesta que solo puede venir de casas

Se verifico en el codigo que `RETURNVALUE_PLAYERISNOTINVITED` tiene exactamente
**nueve** productores en todo el servidor, y **todos** son controles de acceso
a casas:

| Productor | Contexto |
|---|---|
| `actions.cpp:280`, `actions.cpp:341` | uso de item dentro de una casa |
| `container.cpp:329`, `container.cpp:465` | contenedor dentro de una casa |
| `game.cpp:2913` | comercio de un item de casa |
| `game.cpp:960-961` | manejo de ese valor en el camino de movimiento |
| `tile.cpp:484` | **movimiento de criatura** hacia casilla de casa |
| `tile.cpp:781` | movimiento de item |

Para una accion de **movimiento**, el unico origen posible es `tile.cpp:484`.

Por lo tanto observar esa respuesta al intentar caminar prueba **de una sola
vez** que la casilla de destino pertenece de verdad a una casa **y** que el
participante no estaba autorizado — sin publicar el identificador de la casa ni
sus listas de acceso. Es el mismo patron que el aviso de deposito en Phase 2E:
un mensaje que solo puede salir de la rama que interesa.

### 4.3 Tabla de falsos positivos cerrados

| Falso positivo | Como se cierra |
|---|---|
| la via de movimiento estaba rota | control positivo confirmado por el servidor |
| era una pared o colision generica | la respuesta **especifica** de acceso, imposible en una colision |
| la casilla no era de ninguna casa | misma respuesta: solo la emite el control de casas |
| el participante si estaba autorizado | misma respuesta: solo se emite a no invitados |
| el cliente dibujo un paso que el servidor rechazo | la posicion final se lee del **estado autoritativo**, no de la prediccion local |
| la sesion se habia caido | se exige sesion conectada al medir |
| un mensaje de otra fase se colo | la respuesta **solo se cuenta durante la fase de medicion** |
| el operador influyo | se aparta antes de medir y su bandera lo excluye como participante |

El anteultimo punto no es teorico: en la corrida real el mensaje **aparecio
durante el control positivo**, y la guarda de fase correctamente **no lo
conto**.

## 5. Casa elegida, y por que no esta contaminada

Se eligio una casa **sin dueno**.

| Criterio | Verificacion |
|---|---|
| Existe en el mundo legacy | si, declarada en los datos del mundo |
| Tiene dueno | **no**: `owner = 0` |
| Alguien en su lista de invitados o subduenos | **no**: la tabla de listas de casas esta **vacia** para todas las casas |
| Depende del residuo del audit de camas | **no**: la casa contaminada tiene dueno y **no** es esta |
| Relacion con cuentas del usuario | **ninguna** |

De las 862 casas del mundo, **860 no tienen dueno**; solo dos lo tienen, y
ninguna de esas dos se uso. La casa contaminada por el residuo historico de QA
quedo **explicitamente descartada**.

Que la casa no tenga dueno **no debilita** el fixture: `getHouseAccessLevel`
devuelve `HOUSE_NOT_INVITED` igual, porque el participante no es dueno (el
dueno es 0), no es subdueno y no es invitado. El rechazo es el mismo camino de
codigo.

## 6. Participante y roles

| Rol | Quien | Que hace |
|---|---|---|
| Participante | jugador **normal** dedicado de QA | intenta entrar; **unica** fuente de las aserciones |
| Operador | personaje con permisos | **solo** lo posiciona en la casilla **exterior**; se aparta antes de medir |

El operador **no** es participante, **no** cruza el limite y **no** aparece en
ninguna asercion. Su bandera `CanEditHouses` lo haria pasar por dueno, asi que
usarlo como entrante habria invalidado el fixture; el adaptador lo **rechaza
explicitamente** si se lo configura como participante.

El operador lleva al participante **a la casilla exterior**, nunca al otro lado
del limite: no hay teletransporte a traves de la frontera medida.

## 7. Como se localiza el limite de la casa

El cliente **no sabe** que casillas pertenecen a una casa: esa informacion no
viaja por el protocolo. Y la posicion de entrada de los datos del mundo es, por
la razon de la seccion 2.1, una casilla **fuera** de la casa.

Entonces el adaptador parte de esa casilla exterior y prueba sus vecinas de a
una con movimiento ordinario. La vecina que devuelve la respuesta especifica de
acceso **es** el limite.

Probar vecinas es **mecanica del harness**; lo que se afirma es la respuesta
autoritativa, no el metodo de busqueda. Las coordenadas son **metadata
operativa** y **no entran** al payload.

## 8. Resultado en vivo — **CERTIFICADO**

Codigo de salida 0 y exactamente **una** linea `OBSERVATION_JSON`.
**2 intentos completos de 3, 0 salidas de preflight.**

### 8.1 Historial de intentos, sin maquillaje

| # | Naturaleza | Que paso |
|---:|---|---|
| 1 | **fallo del harness (mio)** | el indice de vecinas se reiniciaba en **cada** regreso a la casilla de partida, asi que la busqueda repetia la primera vecina indefinidamente. No llego a medir |
| 2 | **exito** | — |

El defecto era de recorrido, no de semantica: el reinicio del indice estaba en
la fase equivocada. Se lo movio al unico punto que corresponde, la salida del
control positivo. **La expectativa nunca se modifico**, verificado por hash: el
fixture y el `QACase` quedaron **byte-identicos** en los dos intentos; lo unico
que cambio fue el adaptador.

### 8.2 Cronologia observada (intento 2)

| Etapa | Observacion |
|---|---|
| Posicionamiento | el operador deja al participante en la casilla **exterior** y **se aparta** |
| Control positivo | el servidor **confirma** un desplazamiento ordinario |
| *(ruido informativo)* | durante esa fase llego la respuesta de acceso; la guarda de fase **no la conto** |
| Regreso | el participante vuelve a la casilla de partida |
| Intento 1 de 8 | sin respuesta de acceso: esa vecina no es limite |
| **Intento 2 de 8** | **respuesta especifica de acceso observada** |
| Posicion | autoritativamente **igual** a la de partida: quedo afuera |
| Sesion | conectada |

Duracion total: **~19 s**.

### 8.3 Las cuatro aserciones, y por que no hay mas

| # | Puntero | Falso positivo que cierra |
|---:|---|---|
| 1 | `/precondition/ordinary_movement_confirmed` | via de movimiento rota |
| 2 | `/access_attempt/house_access_denial_observed` | colision generica / casilla que no es de casa / participante autorizado |
| 3 | `/access_attempt/participant_remained_outside` | entro igual pese al rechazo |
| 4 | `/access_attempt/session_remained_connected` | "no se movio" por desconexion |

**No** se agrego una asercion separada de "se intento entrar": no se puede
recibir un rechazo sin haber intentado, asi que seria **restatear** la misma
observacion. Es el mismo criterio que llevo a congelar siete y no ocho
aserciones en `PARITY-TRADE-EXCHANGE-001`.

**No** se agrego "el participante no estaba autorizado": la respuesta del
servidor **solo** se emite a no invitados, asi que tambien seria restatear. Se
verifico igual como guarda, leyendo que la tabla de listas de acceso esta
vacia.

### 8.4 Mutaciones

| Concepto | Valor |
|---|---|
| Propiedad de casas modificada | **0** |
| Listas de invitados o subduenos modificadas | **0** |
| Premium concedido | **0** |
| Camas usadas o durmientes tocados | **0** |
| Items creados o movidos | **0** |
| Cuentas o personajes creados | **0** |
| Progresion modificada | **0** |
| Muertes / combate / monstruos / `/killall` | **0** |
| Estado de otros jugadores | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

Lo unico que cambio en todo el turno fue **la posicion del propio participante
de QA**, que es estado de sesion y no persiste como configuracion. **Residuo
persistente: ninguno.**

### 8.5 Replay y congelamiento

- Replay contra la observacion viva con `replay.py` **sin modificar**:
  **`PASS 4/4`**, byte-identico entre dos corridas.
- **Sin replay grabado**, porque no hay `RECORDED_EVIDENCE` (seccion 3).
- Los hashes congelados antes de la corrida —fixture, `QACase`, adaptador
  final, helper, `replay.py`, `wrap_live_observation.py`, los dos archivos de
  red de produccion y los dos archivos de origen que establecen la semantica
  (`tile.cpp`, `house.cpp`)— se recalcularon despues: **identicos**.
- `replay.py` y `wrap_live_observation.py` **no se modificaron**: aceptaron un
  **decimo** dominio de comportamiento sin ningun cambio.

## 9. Propiedades de casas que NO se certifican

- acceso del **dueno**, del **subdueno** y del **invitado**, y la precedencia
  entre esas listas;
- semantica de **invitar**, **desinvitar** y **expulsar**;
- comportamiento de las **puertas** y de las listas por puerta;
- **compra**, **venta**, **alquiler** y transferencia de casas;
- cualquier requisito de **cuenta premium**;
- **uso de camas**, dormir, despertar, regeneracion y su persistencia — sigue
  bloqueado por `CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA`;
- comportamiento del **deposito** dentro de casas;
- todos los **tipos de casilla** de una casa;
- todas las **direcciones** de entrada posibles;
- el **redireccionamiento** de `queryDestination` hacia la entrada;
- el borde exacto del limite de la casa.

## 10. Relacion con el bloqueo de camas

`CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA` **sigue abierto y sin
modificar**. Su condicion de salida no cambio: conseguir un participante
dedicado de QA que sea premium y posea una casa, sin tocar cuentas ni casas del
usuario, lo que es una peticion para los carriles `integracion` / `servidor`.

Esta certificacion **no lo toca ni lo debilita**: demuestra justamente que la
parte del dominio que **no** depende de premium ni de propiedad **si** se podia
certificar sin mutar nada.
