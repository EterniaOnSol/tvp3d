# `PARITY-HOUSE-OWNER-ACCESS-001` — Acceso del dueno a una casa (TVP 7.72)

**CERTIFICADO EN VIVO.** Replay vivo **`PASS 5/5`**, byte-identico entre dos
corridas. Un solo intento completo, sin fallos.

Fixture `LEGACY_PARITY` **dentro de Phase 2**. No abre fase ni sub-fase nueva y
**no toca** `docs/tibia3d/MASTER_PLAN.md`.

---

## 1. Que se certifica

> Sobre el **mismo jugador normal** y la **misma casilla limite** de la misma
> casa: **sin ser dueno** el servidor le niega la entrada y se queda afuera;
> **siendo dueno**, el mismo desplazamiento ordinario hacia la misma casilla es
> aceptado.

**La comparacion ES el fixture.** Ninguna mitad prueba nada sola: "no entro" lo
produce igual una pared, y "entro" lo produce cualquier casilla que no sea de
una casa. Lo que se afirma es que, manteniendo fijos el jugador, la casilla, el
camino y el estado de los objetos de esa casilla, **lo unico que cambio entre
el rechazo y la aceptacion fue la relacion de propiedad**.

Es el **positivo** que le faltaba a `PARITY-HOUSE-ACCESS-001`, que solo habia
certificado la denegacion.

### Lo que NO se afirma

**No se certifica exclusividad**, es decir que *solo* el dueno pueda entrar:
eso exigiria un segundo participante normal midiendose contra la misma casilla
y **no se midio**. Ver seccion 9.

Tampoco: compra, venta, alquiler, subasta ni transferencia de casas;
persistencia de la propiedad entre reinicios o ciclos de Docker; semantica de
invitado, subdueno o puertas; precedencia entre esos niveles; expulsar;
requisito de premium; camas, dormir o regeneracion.

**`/owner` es montaje, no es el comportamiento certificado.**

---

## 2. La regla, verificada en el codigo

`Tile::queryAdd` (`servidor/src/tile.cpp:481-489`):

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

`House::isInvited` (`house.cpp:307-310`) es
`getHouseAccessLevel(player) != HOUSE_NOT_INVITED`, y el nivel
(`house.cpp:154-183`) devuelve `HOUSE_OWNER` cuando
`player->getGUID() == owner`.

| Hecho verificado | Donde | Por que importa |
|---|---|---|
| La propiedad se resuelve por **GUID del personaje** | `houseOwnedByAccount = false` (`config.lua:109`) desactiva la rama por cuenta | el dueno es el personaje exacto, no "alguien de esa cuenta" |
| `isPremium()` **no aparece** en ninguna rama del control de entrada | `house.cpp:154-183` | este fixture no toca premium y no lo necesita |
| `PlayerFlag_CanEditHouses` devuelve `HOUSE_OWNER` | `house.cpp:166-168` | por eso el **operador no puede ser el participante**; el adaptador lo rechaza explicitamente |

### 2.1 El dato que decidio todo el diseno

**El control de casa esta arriba de todo en `queryAdd`**: justo despues de
comprobar que la casilla tiene suelo y **antes de cualquier chequeo de objeto
que bloquee**.

De ahi sale una asimetria que, ignorada, habria arruinado el A/B:

- al **no invitado** lo frena el control de casa, que corre primero — y lo hace
  **aunque la casilla ademas este tapada**;
- al **dueno** lo frenaria la **puerta cerrada**, que es un bloqueo de objeto y
  no tiene nada que ver con la propiedad.

Es decir: con la puerta cerrada, el resultado habria sido "el dueno tampoco
entra", que es **falso** como afirmacion sobre la regla de propiedad. Ver
seccion 4.

---

## 3. Sin `RECORDED_EVIDENCE`, verificado antes de congelar

Se busco en todo `docs/qa/`. `PRUEBA_VIVA_CASA_CAMA.md` menciona una casa y una
entrada, pero **no observa ninguna entrada**: su unica observacion de runtime es
un `You cannot use this object` al usar una **cama**.
`PARIDAD_772_2026-08-29.md:43` repite ese mismo hecho.

**Ninguna corrida historica observo a un jugador entrando a una casa por ser su
dueno.** Fabricar esa observacion habria sido inventar evidencia.

`LIVE_ORACLE` unicamente; el corpus grabado queda en **9**, sin cambio.

---

## 4. Por que hubo que abrir la puerta, y por que no contamina

Antes de disenar la medicion se reconocieron **734 casillas** del mundo con
`/tileinfo`, en cuatro zonas distintas (Thais, dos aldeas y la muralla).

**Resultado: en este mapa no existe ninguna casa con un limite abierto.** Todas
estan cerradas por pared, ventana o puerta. Cada casilla de casa que toca el
exterior tiene encima una pared o una puerta; las casillas de casa despejadas
son interiores y no tocan el exterior.

Por eso el operador **abre la puerta una sola vez, antes de la medicion
negativa, y la deja abierta durante las dos**.

> El estado de la puerta es **identico en ambas mitades**, asi que no puede
> explicar la diferencia. Lo unico que cambia entre una y otra es la propiedad.

Abrir la puerta **no es medir la puerta**. La semantica de puertas
(`Door::canUse`, `house.cpp:578`, que exige nivel `>= HOUSE_SUBOWNER` o estar
en la lista propia de la puerta) queda **expresamente fuera** de lo que este
fixture afirma.

El estado de la puerta se verifico con `/tileinfo` en **tres** momentos, y los
tres quedaron en el log: `1221 closed door` al empezar, `1222 open door`
durante las dos mediciones, y `1221 closed door` al terminar.

---

## 5. La casa de sandbox, y por que esta limpia

Elegida entre las **860 sin dueno** de las 862 del mundo.

| Requisito | Estado verificado |
|---|---|
| Sin dueno al empezar | **si**, `owner = 0` en la DB |
| No es la casa contaminada del audit de camas | **no lo es**: esa tiene dueno y es otra |
| No tiene relacion con ninguna cuenta del usuario | **ninguna**; las dos casas con dueno no se tocaron |
| Lista de invitados vacia | **si**: `house_lists` tiene **0 filas** en todo el mundo |
| Lista de subduenos vacia | **si**, por lo mismo |
| Pujas en cero | **si**, y en las 862 casas, asi que ponerlas en cero no cambia nada |
| Zona de proteccion | **si** dentro de la casa: 0 combate posible |
| Objetos sueltos adentro | **ninguno** |

El ultimo punto no es un detalle. Se recorrio la casa **entera** con
`/tileinfo`: solo tiene paredes, ventanas, lamparas de pared, cesped, dos
puertas, cuatro camas, un horno y una escalera. **Ninguno es recogible y
ninguno es contenedor.** Importa porque al devolver la casa a sin dueno el
servidor llama `House::transferToDepot` (`house.cpp:257`), que manda al
deposito del dueno saliente los objetos recogibles que haya sobre las casillas
de la casa — y aca **no habia nada que mover**.

La casa tiene **camas**, pero `houseCleanBeds` es `false`, no habia ningun
durmiente y **no se uso ninguna**.

---

## 6. Que hace exactamente `/owner`, verificado antes de usarlo

`/owner` (`data/scripts/talkactions/god/owner.lua`) exige grupo con acceso y
tipo de cuenta god, actua **solo sobre la casa donde el operador esta parado**,
y llama `house:setOwnerGuid(guid)`, que entra a `House::setOwner`
(`house.cpp:28-137`) con `updateDatabase = true`.

| Efecto de `setOwner` | Que paso en esta corrida |
|---|---|
| `UPDATE houses SET owner, bid, bid_end, last_bid, highest_bidder` | unica escritura persistente; los cuatro campos de puja ya eran 0 |
| expulsa a los parados en la casa | el operador es **inmune** por `CanEditHouses` (`house.cpp:196`); el participante estaba afuera |
| limpia listas de invitados y subduenos | ya estaban vacias: **no cambio nada** |
| `houseTransferItems` al asignar | **`false`** por defecto y ausente de `config.lua`: no movio nada |
| `houseCleanBeds` | **`false`**: no toco ninguna cama |
| `houseClearDoors` | **`false`**: no limpio ninguna lista de puerta |
| `paidUntil` y `rentWarnings` | **solo en memoria**: no existe ninguna escritura de `paid_until` en el codigo ni columna equivalente en `houses` |
| **carta de bienvenida al deposito del nuevo dueno** | **ocurrio**, y es inevitable por esta via. Ver seccion 8 |
| al devolver, `transferToDepot` | corrio y **no movio nada**, porque la casa no tiene objetos recogibles |

`/owner none` devuelve la casa a sin dueno por el mismo camino.

---

## 7. El recorrido medido

| Paso | Quien | Que |
|---|---|---|
| linea base | operador | `/tileinfo` confirma que la casilla del limite es de la **casa de sandbox esperada** y que su puerta esta **cerrada** |
| montaje | operador | abre la puerta con el transporte de **produccion** (`enviar_usar_item`, 0x82) y verifica que quedo abierta |
| posicionamiento | operador | convoca al participante a la casilla exterior y **se aparta** 6 casillas |
| control positivo | participante | un desplazamiento ordinario **confirmado por el servidor**, en direccion contraria a la casa |
| **medicion A** | participante | un paso hacia la casilla de la casa -> **`You are not invited.`**, posicion autoritativa **sin cambio** |
| montaje | operador | entra a la casa, `/tileinfo` **verifica el id de la casa** antes de mutar, `/owner <participante>`, y se corre al fondo |
| **medicion B** | participante | **el mismo paso, hacia la misma casilla** -> **entra**; posicion autoritativa = la casilla de la casa, y **sin** respuesta de falta de autorizacion |
| restauracion | los dos | el participante sale caminando, `/owner none`, y el operador vuelve a cerrar la puerta |

Duracion total: **31 segundos**. Codigo de salida 0 y exactamente una linea
`OBSERVATION_JSON`.

La posicion se lee siempre del **estado autoritativo** (`mi_pos`, que en
`estado_mundo.gd` solo se escribe desde paquetes del servidor: mapa completo
0x64, movimiento 0x6D y cambio de piso), **nunca** de la prediccion local.

---

## 8. Auditoria de mutacion y residuo

### Restaurado exactamente

La fila de la casa quedo **identica byte a byte** a la de la linea base:
`83|0|0|1400|1|0|0|0|0|35|2` (id, dueno, pagado, renta, pueblo, las cuatro
pujas, tamano, camas). Y en el mundo: **862** casas, **860** sin dueno, **2**
con dueno, **los mismos dos duenos que antes**, y `house_lists` con **0 filas**.

| Concepto | Valor |
|---|---:|
| Casas mutadas temporalmente | **1** |
| Casas mutadas de forma permanente | **0** |
| Listas de invitados / subduenos / puertas modificadas | **0** |
| Entradas comodin aparecidas | **0** |
| Segunda casa tocada | **0** |
| Premium modificado | **0** |
| Cuentas o personajes creados | **0** |
| Progresion modificada | **0** |
| Camas usadas | **0** |
| Muertes / combate / monstruos / comandos amplios | **0** |
| Objetos creados por QA | **0** |

### Residuo declarado: la carta de bienvenida

`House::setOwner` crea un `ITEM_LETTER_STAMPED` y lo pone **al frente del
deposito del nuevo dueno** (`house.cpp:104-131`). Ocurre dentro de
`if (updateDatabase)`, y `/owner` **no expone** forma de pasar `false`: es la
unica via autorizada de montaje y el efecto es **inevitable** por ella.

Se confirmo en el archivo persistido del participante. El delta de su deposito
es **exactamente uno**, y no hay ningun otro:

```text
antes:    Depot = (1, {2594 Content={}})
despues:  Depot = (1, {2594 Content={}, 2598 Text="Welcome!..."})
```

**Esto no es un artefacto fabricado por QA**: es una consecuencia intrinseca
del mecanismo de montaje que este turno tenia autorizado usar, y no habia forma
de evitarla — `/owner` no expone el parametro que la desactivaria.

**No se intento borrarla, y la razon es deliberada.** La unica via disponible
sin tocar `servidor/` seria: el participante abre el deposito, saca la carta,
la deja en el suelo, y el operador la elimina con `/r`, que actua sobre la
casilla **que el operador tiene enfrente** segun su direccion. Si ese ultimo
paso falla, el residuo pasa de ser una carta inerte dentro del deposito de un
personaje de QA a ser **un objeto tirado en la via publica del mundo**, que es
estrictamente peor. Cambiar un residuo acotado por uno mayor no es limpiar.

Queda **declarado**, no disimulado: **la restauracion de la CASA es exacta; el
turno no cierra con residuo cero.** Un turno futuro puede quitarla con la
secuencia de arriba si se considera necesario.

No hay otro residuo. El archivo del participante ademas cambio en posicion,
vida y marcas de condicion, que es estado de sesion normal. Los archivos de
jugador no estan versionados (`.gitignore:25`), asi que nada de esto entra al
repositorio.

### Cambios de sesion del participante

Su posicion quedo en la casilla exterior, y la vida subio 3 puntos por
regeneracion natural. Es estado de sesion del propio personaje de QA, del mismo
tipo que ya declararon los fixtures anteriores.

---

## 9. Controles de falso positivo

| Falso positivo | Como se cierra |
|---|---|
| la via de movimiento estaba rota | **control positivo**: un paso ordinario confirmado por el servidor, justo antes de medir |
| colision generica en vez de regla de casa | se exige la respuesta **especifica** de falta de autorizacion, que en este oracle solo emiten los controles de acceso a casas; para una accion de **movimiento** el unico origen es `tile.cpp:484` |
| la casilla no era de ninguna casa | `/tileinfo` confirma `house=<id>` **antes** de medir |
| se muto la casa equivocada | `/tileinfo` confirma el id de la casa **bajo los pies del operador** antes de `/owner`; si no coincide, `BLOCKED` sin mutar |
| el participante ya podia entrar antes | la medicion A exige denegacion **y** posicion sin cambio |
| se uso otra entrada en la segunda mitad | la casilla limite es **una constante** del adaptador: las dos mediciones usan la misma, y el paso se calcula de la misma resta |
| la casa cambio entre A y B | el estado de la puerta se verifica antes y despues; las listas siguen vacias; nada mas se toco |
| el participante quedo como invitado o subdueno | **ninguna lista se modifico**: `house_lists` tiene 0 filas antes y despues |
| aparecio una entrada comodin | idem: 0 filas |
| privilegio del operador causo el positivo | el operador **no es** el participante (el adaptador lo rechaza), y durante las mediciones esta apartado; su unica intervencion es montaje |
| se entro por teletransporte | la entrada medida se produce con una orden de **movimiento ordinaria**; en esa fase no se emite ningun teletransporte sobre el participante |
| el cliente dibujo un paso que el servidor rechazo | las dos posiciones se leen del estado **autoritativo** |
| la puerta explica la diferencia | **esta abierta en las dos mitades**, verificado por `/tileinfo` |
| el operador bloqueaba la casilla | se aparta al fondo de la casa antes de la medicion B |

---

## 10. Cinco aserciones, y por que no mas

| # | Asercion | Falso positivo que cierra |
|---|---|---|
| 1 | `/precondition/ordinary_movement_confirmed` | via de movimiento rota |
| 2 | `/precondition/session_remained_connected` | lecturas de posicion sobre una sesion caida |
| 3 | `/without_ownership/house_access_denial_observed` | colision generica o casilla que no es de casa |
| 4 | `/without_ownership/participant_remained_outside` | el servidor aviso pero lo dejo pasar igual |
| 5 | `/with_ownership/entry_allowed` | la propiedad no cambio nada |

Se preserva a proposito la granularidad de `PARITY-HOUSE-ACCESS-001`, que ya
separaba **3** y **4**: una es un **mensaje** y la otra es una **posicion**, y
son hechos distintos.

**No** se agrego `authoritative_inside_transition_observed` junto a la 5: se
calcularia **de la misma lectura** que `entry_allowed`, asi que seria restatear
una observacion como dos. Es el mismo criterio que llevo a congelar 10 y no 11
en el deposito, 7 y no 8 en el comercio, y 4 y no 5 en el acceso a casas.

**No** se agrego `ownership_relationship_established`: el cliente **no puede
observarlo**. Se verifico fuera del camino del cliente, en la DB, y se usa como
**guarda del turno**, no como asercion congelada — igual que las
corroboraciones de persistencia de Phase 2E, 2F y 2G.

---

## 11. Intentos

| # | Clasificacion | Resultado |
|---|---|---|
| 1 | intento completo | **EXITO** |

**1 intento completo de 3. 0 salidas de preflight. 0 fallos del harness.**

Que saliera a la primera no es suerte: el reconocimiento previo con `/tileinfo`
—una herramienta de calificacion de **solo lectura** que se agrego en este
turno— convirtio en datos lo que en los dos turnos anteriores se habia buscado
a ciegas. `PARITY-DEPOT-PERSISTENCE-001` gasto dos lanzamientos aprendiendo que
una casilla historica no era caminable, y `PARITY-HOUSE-ACCESS-001` gasto uno
buscando el limite vecina por vecina. Aca la geometria se pregunto **antes** de
conectar a nadie.

---

## 12. Hashes congelados

Se congelaron **16** antes del primer intento y se recalcularon despues de la
corrida, del wrap y de los dos replays. **Quince quedaron identicos**; el unico
que cambio es el archivo persistido del participante, que es justamente donde
vive el residuo declarado de la seccion 8.

Incluyen a proposito los archivos de origen que establecen la semantica
(`tile.cpp`, `house.cpp`, `owner.lua`, `tile_info.lua`, `doors.lua`), el
transporte y el parser de produccion (`conexion772.gd`, `estado_mundo.gd`) y
las dos herramientas genericas (`replay.py`, `wrap_live_observation.py`), que
**no se modificaron**.

---

## 13. Limitaciones

1. **No hay exclusividad.** Se probo que el dueno entra donde antes no podia;
   **no** que un tercero siga sin poder. Para afirmarlo haria falta un segundo
   participante normal medido contra la misma casilla.
2. **Una sola casilla y una sola direccion.** No se barrieron todos los tipos
   de casilla de una casa ni todas las direcciones de entrada.
3. **Una sola casa.** La regla es global en el codigo, pero lo observado es una
   casa.
4. **Nada sobre persistencia de la propiedad.** La casa se devolvio a sin dueno
   en la misma sesion; no se reinicio el servidor con la propiedad puesta.
5. **Nada sobre puertas.** La puerta se abrio como montaje y su estado se
   mantuvo constante; `Door::canUse` no se midio.

---

## 14. Bloqueos que este turno NO resuelve

| Bloqueo | Estado |
|---|---|
| `HOUSE_GUEST_LIST_SIN_TRANSPORTE_DE_PRODUCCION` | **abierto, sin cambio.** Certificar al dueno no acerca la lista de invitados: el hueco es el par `0x97` / `0x8A` del transporte, y sigue ahi. Este fixture pudo hacerse **justamente porque no necesita ninguna lista de acceso** |
| `CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA` | **abierto, sin cambio.** No se concedio premium y no se uso ninguna cama. El acceso no consulta `isPremium()`, pero `BedItem::canUse` si |

Son independientes entre si y de este resultado.

---

## 15. Reproducir

```text
TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER   participante normal
TVP772_GOD_ACCOUNT / _PASSWORD / _GOD_CHARACTER  operador (solo montaje)
TVP772_HOUSE_ID        id de la casa de sandbox
TVP772_HOUSE_OUTSIDE   "x,y,z" casilla exterior de partida
TVP772_HOUSE_BOUNDARY  "x,y,z" casilla de la casa que se intenta pisar
TVP772_HOUSE_INSIDE    "x,y,z" casilla interior donde se aparta el operador

Godot --headless --path cliente3d \
    pruebas/prueba_parity_house_owner_access_capture.tscn
```

Calificar una casa nueva primero, con la herramienta de solo lectura:

```text
TVP772_RECON_CENTROS "x,y,z;x,y,z;..."   TVP772_RECON_RADIO  (def. 2)

Godot --headless --path cliente3d \
    pruebas/prueba_casa_reconocer_limite.tscn
```

Ningun valor de credencial aparece en el codigo, en el log, en la observacion
ni en este documento.
