# `PARITY-HOUSE-GUEST-ACCESS-001` — BLOQUEADO por transporte ausente

Turno dentro de **Phase 2 — build parity fixtures against TVP**. No abre fase ni
sub-fase nueva y **no toca** `docs/tibia3d/MASTER_PLAN.md`.

## Resultado: `BLOCKED`

**No se materializo ningun fixture, `QACase`, `RECORDED_EVIDENCE` ni
`LIVE_ORACLE`. Inventarios sin cambio.**

Y, lo que mas importa:

> **No se muto absolutamente nada.** El bloqueo se detecto **verificando el
> codigo ANTES** de tocar ninguna casa, ninguna lista y ningun personaje.

La autorizacion del orquestador para mutar una casa sandbox **existia y era
usable**, pero **no sirve**: el bloqueo no es de permiso, es de **capacidad de
transporte ausente**.

---

## 1. La regla de invitados, verificada en el codigo

`House::getHouseAccessLevel` (`servidor/src/house.cpp:154-183`) devuelve
`HOUSE_GUEST` si `guestList.isInList(player)`, y `House::isInvited`
(`house.cpp:307-310`) es `!= HOUSE_NOT_INVITED`. El control de entrada es el ya
certificado en `PARITY-HOUSE-ACCESS-001`: `Tile::queryAdd`
(`tile.cpp:481-489`).

Hasta aca todo bien: la propiedad **existe** y seria el positivo natural del
fixture anterior.

## 2. El unico camino de produccion para editar la lista

`House::setAccessList` (`house.cpp:207-213`) es lo que realmente modifica la
lista. Su **unico** llamador desde el juego es
`Game::playerUpdateHouseWindow` (`game.cpp:2841-2872`):

```cpp
House* house = player->getEditHouse(internalWindowTextId, internalListId);
if (house && house->canEditAccessList(internalListId, player)
        && internalWindowTextId == windowTextId && listId == 0) {
    ...
    house->setAccessList(internalListId, ss.str());
}
```

Exige que el jugador tenga una **ventana de edicion abierta**. Esa ventana la
abre el hechizo `aleta sio`
(`servidor/data/scripts/spells/houses/invite_guests.lua`), que el dueno lanza
**parado dentro de su casa**:

```lua
creature:setEditHouse(house, GUEST_LIST)
creature:sendHouseWindow(house, GUEST_LIST)
```

El recorrido completo es, entonces:

| Paso | Direccion | Opcode |
|---|---|---|
| 1. el dueno lanza el hechizo, parado dentro | cliente -> servidor | habla normal |
| 2. el servidor abre la ventana de la lista | **servidor -> cliente** | **`0x97`** |
| 3. el cliente responde con la lista nueva | **cliente -> servidor** | **`0x8A`** |
| 4. el servidor aplica `setAccessList` | interno | — |

No hay ningun otro camino: `setEditHouse` solo se invoca desde Lua
(`luascript.cpp:9849`) y no existe ninguna talkaction de casas mas alla de
`/owner`.

## 3. El bloqueo: el cliente de produccion no soporta ninguno de los dos pasos

Verificado sobre `cliente3d/red/`, que es de **solo lectura** para este carril:

| Requisito | Estado en el transporte de produccion |
|---|---|
| Recibir `0x97` (ventana de la lista) | **NO se parsea.** `estado_mundo.gd` lo manda al contador de opcodes desconocidos |
| Enviar `0x8A` (respuesta con la lista) | **NO EXISTE.** `conexion772.gd` no tiene ningun metodo que lo emita |
| Metodos relacionados con casas en el transporte | **cero** |

Sin el paso 3 la lista **nunca puede cambiar** desde un cliente. La propiedad
que este fixture pretendia certificar es, hoy, **inalcanzable por la via de
produccion**.

### 3.1 Una trampa de direccion que conviene dejar escrita

`0x97` **ya se usa en el cliente**, pero en la **direccion contraria y con otro
significado**: `conexion772.gd:317-318` lo emite como *pedir la lista de
canales*.

Es decir que el mismo numero significa **canales** saliendo del cliente y
**ventana de lista de casa** entrando. Es exactamente la misma clase de trampa
ya documentada en comercio (`0x7F` = aceptar / cerrar) y en contactos (`0x D2`
y `0xD3` = apariencia / contactos). Quien implemente esto **no puede** asumir
que un `0x97` es lo mismo en los dos sentidos.

## 4. Por que NO se aplico la autorizacion de mutacion

El orquestador autorizo asignar temporalmente una casa sin dueno a un
participante de QA y editar su lista de invitados.

Esa autorizacion **era usable**: existe `/owner`
(`servidor/data/scripts/talkactions/god/owner.lua`), que actua **solo sobre la
casa donde esta parado el operador** y admite `/owner none` para devolverla a
sin dueno. Es acotado y reversible, justo lo que la Fase 1 pedia. De las 862
casas, 860 no tienen dueno, asi que tambien habia sandbox de sobra.

**Aun asi no se ejecuto ni un solo paso de mutacion**, y la razon es deliberada:

> La Fase 3 es **imposible**. Asignar la casa habria dejado el mundo mutado
> para un fixture que **no puede completarse**, y habria obligado a una
> restauracion que solo existe para deshacer algo que nunca debio empezar.

Verificar el transporte **antes** de mutar es lo que evito ensuciar el entorno.
Es la leccion que dejo el residuo de casa sin restaurar del audit de camas: una
mutacion de setup que sobrevive a un fixture fallido es peor que no haber
empezado.

## 5. Auditoria de mutaciones

| Concepto | Valor |
|---|---:|
| Casas cuyo dueno cambio | **0** |
| Listas de invitados modificadas | **0** |
| Listas de subduenos modificadas | **0** |
| Listas de puertas modificadas | **0** |
| Cuentas modificadas o creadas | **0** |
| Premium modificado | **0** |
| Estado persistente de jugadores modificado | **0** |
| Camas o durmientes tocados | **0** |
| Muertes / combate / monstruos / `/killall` | **0** |
| **Residuo persistente** | **0** |

No hubo nada que restaurar, porque no hubo nada que mutar.

## 6. Sin `RECORDED_EVIDENCE`

Se busco, como en los turnos anteriores. No existe evidencia historica de
runtime de acceso por invitado; las unicas menciones de acceso a casas en
`docs/qa/` son los documentos de auditoria y de paridad producidos por los dos
turnos previos, que no son observaciones historicas.

`RECORDED_EVIDENCE` queda en **9**, sin cambio.

## 7. Solicitud para el carril propietario

**Carril propietario: `protocolo-red`** (`CARRILES.md` le asigna
`cliente3d/red/`).

Para desbloquear este fixture hace falta que ese carril publique, en el
transporte de produccion:

1. **parseo del `0x97` entrante** — ventana de lista de casa: un byte de
   relleno, `u32` de id de ventana y el texto de la lista actual
   (`protocolgame.cpp:2129-2137`);
2. **emision del `0x8A` saliente** — respuesta con la lista editada: id de
   lista, `u32` de id de ventana y el texto nuevo
   (`protocolgame.cpp:1102-1108`);
3. cuidado explicito con la **colision de direccion** de la seccion 3.1: `0x97`
   saliente ya significa *pedir canales* y no debe confundirse.

**QA no lo implementa.** Modificar `cliente3d/red/` desde este carril seria
invadir otro carril, y ademas dejaria el fixture certificando codigo escrito
por el mismo turno que lo mide.

Este hueco de transporte tambien explica, retroactivamente, por que el cliente
no puede hoy administrar casas: no es una decision de producto, es una
capacidad que nunca se publico.

## 8. Estado de los bloqueos

| Bloqueo | Estado |
|---|---|
| **`HOUSE_GUEST_LIST_SIN_TRANSPORTE_DE_PRODUCCION`** | **NUEVO, abierto.** El transporte de produccion no puede recibir `0x97` ni emitir `0x8A`, asi que la lista de invitados no se puede editar desde un cliente |
| `CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA` | **abierto, sin modificar.** Este turno no toco premium ni camas |

Los dos son independientes: uno es de **transporte ausente**, el otro de
**precondicion de estado**. Resolver uno no resuelve el otro.

## 9. Propiedades de casas que siguen sin certificar

Certificado hasta ahora: **solo** la denegacion de entrada a un no autorizado
(`PARITY-HOUSE-ACCESS-001`).

Sin certificar: acceso del **dueno**, del **subdueno** y del **invitado** y su
precedencia; invitar, desinvitar y **expulsar**; listas por **puerta**;
compra, venta, alquiler y transferencia; **deposito** dentro de casas; el
redireccionamiento de `queryDestination`; el borde exacto del limite; y todo el
recorrido de **camas**.

De esos, **todos los que involucran listas de acceso** —invitado, subdueno,
puertas, expulsar— quedan bloqueados por el mismo hueco de transporte.

## 10. Recomendacion exacta para el proximo turno

**No** volver a intentar acceso por invitado hasta que `protocolo-red` publique
el par `0x97` / `0x8A`.

Lo que si esta disponible **sin** ese transporte y **sin** mutar listas:

1. **`PARITY-HOUSE-OWNER-ACCESS-001`** — el positivo del dueno. Solo necesita
   `/owner` como setup reversible sobre una casa sin dueno, y el control de
   entrada ya certificado. Comparacion A/B identica a la que buscaba este
   turno: sin propiedad **denegado**, con propiedad **permitido**, y despues
   `/owner none` restaura. **No** toca ninguna lista de acceso, asi que el hueco
   de transporte **no lo afecta**.
2. Huecos de otros dominios ya abiertos, todos sin evidencia historica: borde
   del alcance de comercio, cancelacion implicita por desconexion, baja y
   duplicado de contactos.

La opcion 1 es la de mayor valor: completa el par negativo/positivo del acceso
a casas, usa un mecanismo de setup acotado y reversible que **ya existe**, y no
depende de ningun carril ajeno.
