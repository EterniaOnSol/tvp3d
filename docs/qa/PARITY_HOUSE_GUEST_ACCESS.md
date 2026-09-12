# `PARITY-HOUSE-GUEST-ACCESS-001` — Acceso por lista de invitados (TVP 7.72)

**CERTIFICADO EN VIVO.** Replay vivo **`PASS 6/6`**, byte-identico entre dos
corridas. **Tres intentos**: los dos primeros fallaron por defectos **mios** del
arnes, nunca del oracle.

Fixture `LEGACY_PARITY` **dentro de Phase 2**. No abre fase ni sub-fase nueva y
**no toca** `docs/tibia3d/MASTER_PLAN.md`.

---

## 1. Que se certifica

> Sobre el **mismo jugador B** y la **misma casilla limite**, mientras el
> jugador A es dueno de la casa: **fuera de la lista de invitados** el servidor
> le niega la entrada y B se queda afuera; **despues de que A lo agrega a la
> lista** por el flujo normal del juego, el mismo desplazamiento ordinario hacia
> la misma casilla es aceptado.

**La comparacion ES el fixture.** Lo unico que cambia entre las dos mediciones
es la pertenencia de B a la lista; el jugador, la casilla, el camino, el dueno y
el estado de la puerta quedan fijos.

### Cierra la limitacion de exclusividad, sin un segundo fixture

La mitad negativa se midio **con A ya dueno**. Es decir que tambien se observo:

> mientras otro jugador normal es dueno de la casa, un segundo jugador normal
> que no figura en ninguna lista **no puede entrar**.

Eso es exactamente la limitacion que `PARITY-HOUSE-OWNER-ACCESS-001` habia
declarado sin certificar. **No se creo un fixture aparte para ese hecho**: es la
misma secuencia viva, y partirla en dos habria inflado el corpus con dos
fixtures para una sola observacion.

---

## 2. Dependencia: `protocolo-red 2.2.0`

Este turno **consume** el transporte que el carril `protocolo-red` publico, y
**no lo reimplementa**. Verificado en HEAD antes de disenar nada:

| Direccion | Opcode | API de produccion usada |
|---|---:|---|
| servidor -> cliente | `0x97` | `EstadoMundo.ventana_casa` / `ultima_ventana_casa` |
| cliente -> servidor | `0x8A` | `Conexion772.enviar_lista_acceso_casa(id, texto)` |

**QA no armo ni un byte.** El bloqueo
`HOUSE_GUEST_LIST_SIN_TRANSPORTE_DE_PRODUCCION` figura **RESUELTO** en
`worklog/protocolo-red/STATE.md` y se consumio como dependencia publicada.

**El `u8` de id de lista no es parametro**: el servidor exige 0 con una guarda
estricta y **silenciosa** (`game.cpp:2852`), y el transporte de produccion ya lo
fija. Ofrecerlo seria ofrecer una eleccion que no existe.

---

## 3. El flujo de edicion, verificado en el codigo

| Paso | Donde | Que exige |
|---|---|---|
| abrir la ventana | `invite_guests.lua`, palabras **`aleta sio`** | estar parado **dentro** de la casa y pasar `canEditAccessList(GUEST_LIST, ...)` |
| emitir la ventana | `Player::sendHouseWindow` (`player.cpp:875-892`) | antepone un encabezado `# Guests of <casa>` al texto |
| recibirla | `ProtocolGame::sendHouseWindow` (`protocolgame.cpp:2129-2137`) | `u8` relleno, `u32` id, `string` |
| devolverla | `parseHouseWindow` (`protocolgame.cpp:1102-1108`) | `u8` lista, `u32` id, `string` |
| aplicarla | `Game::playerUpdateHouseWindow` (`game.cpp:2841-2872`) | `listId == 0`, id **igual al emitido**, texto ASCII |

### 3.1 La ventana es de UN SOLO USO

`playerUpdateHouseWindow` termina **siempre** con `setEditHouse(nullptr)`, haya
aplicado el cambio o no. Y `Player::setEditHouse` (`player.cpp:868-873`)
**incrementa** `windowTextId` en cada apertura, que es justo el valor que el
servidor exige que se le devuelva.

Por eso **cada edicion abrio su propia ventana**. En la corrida se abrieron
**cuatro**, cada una con su id, ninguna reutilizada:

| # | Para que | Largo del texto devuelto |
|---:|---|---:|
| 1 | leer la lista base y agregar a B | 26 |
| 2 | **lectura de control**: el servidor confirma a B | 40 |
| 3 | restaurar el texto base | 40 |
| 4 | **lectura de control**: el servidor ya no trae a B | 27 |

Los hechizos no agresivos dejan 1 s de exhaustion
(`Spell::postCastSpell`, `spells.cpp:665-677`); el arnes espera 3 s entre casts.

### 3.2 Que lista se edita lo decide el servidor

`setEditHouse` guarda su propio `editListId` y `playerUpdateHouseWindow` usa
**ese**, no el del mensaje. La misma ventana sirve para invitados, subduenos
(`aleta grav`) y puertas. Este fixture **solo** ejercito la de invitados y
**no afirma nada** de las otras dos.

---

## 4. Sin `RECORDED_EVIDENCE`

Se busco en todo `docs/qa/` antes de congelar. La unica evidencia historica del
dominio, `PRUEBA_VIVA_CASA_CAMA.md`, **no observa ninguna entrada**: su unica
observacion de runtime es un fallo al usar una cama.

No cuentan como evidencia grabada ni el codigo fuente, ni el self-test de
protocolo, ni el turno bloqueado anterior. **`LIVE_ORACLE` unicamente**; el
corpus grabado queda en **9**.

---

## 5. Participantes y casa

| Rol | Quien | Que hace |
|---|---|---|
| **A** | jugador normal de QA | dueno temporal, edita la lista. **No se mide su acceso** |
| **B** | otro jugador normal de QA, **otra cuenta** | el unico medido |
| Operador | personaje con permisos | **solo montaje**; apartado en todas las mediciones |

El operador **no puede** ser participante: su bandera `CanEditHouses` lo hace
pasar por dueno de cualquier casa (`house.cpp:166-168`), y el adaptador lo
rechaza explicitamente. Tampoco A y B pueden compartir cuenta: una cuenta normal
no admite dos sesiones.

**Casa de sandbox:** la misma ya calificada por
`PARITY-HOUSE-OWNER-ACCESS-001`, **revalidada** y no asumida: sin dueno, listas
vacias, pujas en cero, zona de proteccion, sin objetos recogibles adentro, y
**no** es la casa contaminada del audit de camas ni ninguna del usuario.

---

## 6. El presupuesto de UNA sola asignacion

`/owner` crea una carta de bienvenida en el deposito del nuevo dueno
(`house.cpp:104-131`) y no hay forma de desactivarlo por esa via. El turno tenia
autorizada **exactamente una** asignacion.

### Como se protegio

El adaptador valida **todo lo que puede antes de mutar**, incluido un **ensayo
completo de la medicion** con la casa todavia sin dueno. Si el arnes esta roto,
se descubre con **cero mutaciones** y sin gastar el presupuesto.

### Como se respeto pese a los dos fallos

La asignacion se ejecuto **una sola vez**, en el intento 1. Cuando ese intento
fallo, la casa **quedo asignada a proposito**: devolverla y reasignarla en el
intento siguiente habria creado una **segunda** carta. Los intentos 2 y 3
corrieron con una bandera explicita que **salta** la asignacion, y el adaptador
aborta si detecta un segundo intento de asignar.

Que A siguiera siendo dueno no se dio por sentado: lo **prueba el servidor** al
abrirle la ventana, porque `canEditAccessList` exige dueno o subdueno y la lista
de subduenos estaba vacia.

**Asignaciones totales del turno: 1. En la corrida certificada: 0.**

---

## 7. La puerta, fija en las dos mitades

`PARITY-HOUSE-OWNER-ACCESS-001` dejo establecido que el control de casa corre
**antes** de cualquier bloqueo por objeto, asi que una puerta cerrada produce un
resultado asimetrico. La puerta se mantuvo **abierta e igual** en las dos
mediciones, verificado por `/tileinfo`, y se devolvio a **cerrada** al final.

La semantica de puertas (`Door::canUse`) queda **fuera** de lo afirmado.

---

## 8. El recorrido medido

| Paso | Que |
|---|---|
| control positivo | el servidor **confirma** un paso ordinario de B, lejos de la casa |
| ensayo | B intenta entrar con la casa **sin dueno** -> denegado (valida el arnes sin mutar) |
| montaje | A entra a la casa **por convocatoria**, no caminando (ver 8.1) |
| **medicion A** | B intenta entrar, **fuera de la lista**, con A dueno -> `You are not invited.`, posicion **sin cambio** |
| alta | A abre la ventana 1, y sobre el **texto exacto recibido** agrega **una linea** con el nombre de B |
| **control de lectura** | ventana 2: el **servidor** devuelve una lista que **incluye** a B |
| **medicion B** | **el mismo paso, hacia la misma casilla** -> **entra**; posicion autoritativa = casilla de la casa |

### 8.1 A entra por montaje, y es deliberado

Lo que este fixture mide es la entrada de **B**. La de A ya quedo certificada en
`PARITY-HOUSE-OWNER-ACCESS-001` y aca no se vuelve a afirmar, asi que hacerlo
caminar solo agregaba una forma de fallar — y de hecho fallo, ver seccion 10.

Las posiciones se leen siempre del **estado autoritativo**, nunca de la
prediccion local, y la entrada medida se produjo con una **orden de movimiento
ordinaria**: en esa fase no se emitio ningun teletransporte sobre B.

---

## 9. Controles de falso positivo

| Falso positivo | Como se cierra |
|---|---|
| B ya podia entrar antes | medicion A exige denegacion **y** posicion sin cambio |
| la via de movimiento estaba rota | **control positivo** confirmado por el servidor antes de medir |
| colision generica en vez de regla de casa | se exige la respuesta **especifica** de falta de autorizacion, que solo emiten los controles de acceso a casas |
| B quedo como dueno o subdueno | **ninguna** de esas listas se toco; `house_lists` con 0 filas antes y despues |
| se agrego un comodin | el adaptador **aborta** si el texto a enviar contiene `*`, `@`, `?` o `!`, que `AccessList::parseList` trata como comodin, gremio o patron |
| se edito la lista equivocada | la ventana la abre `aleta sio`, que fija `GUEST_LIST` del lado del servidor |
| se reutilizo una ventana vieja | **cuatro** ventanas, una por edicion; el id se descarta despues de usarlo |
| se adivino un id de ventana | el id sale **solo** del `0x97` entrante; el adaptador aborta si llega en cero |
| el texto local cambio pero el servidor no | **control de lectura**: se reabre la ventana y se comprueba lo que devuelve **el servidor**, no una variable del arnes |
| se probo otra casa o entrada | `/tileinfo` confirma el id de la casa; la casilla limite es una constante usada en las dos mediciones |
| la puerta difirio entre mitades | abierta e igual en ambas, verificado antes y despues |
| B entro por teletransporte | la entrada medida es una orden de movimiento ordinaria |
| privilegio del operador ayudo | el operador **no es** participante y esta apartado durante las mediciones |
| fallo de transporte leido como denegacion | la denegacion es un **mensaje especifico**, no la ausencia de movimiento |

---

## 10. Tres intentos, dos fallos **mios**

Se declara con precision porque en los dos casos el oracle hizo lo correcto.

| # | Clasificacion | Que paso |
|---:|---|---|
| 1 | **defecto del arnes (mio)** | A no podia caminar a su propia casa: recibia `Sorry, not possible.` |
| 2 | **defecto del arnes (mio)** | maquina de fases colgada en un estado sin manejador |
| 3 | **EXITO** | 56 s, codigo 0, una sola linea `OBSERVATION_JSON` |

### Intento 1: no era la casa, era una criatura

`Tile::queryAdd` (`tile.cpp:581-588`) devuelve `RETURNVALUE_NOTPOSSIBLE` —
literalmente *"Sorry, not possible."* — cuando hay **una criatura** en la
casilla destino. El camino de A pasaba por la casilla donde estaba parado **B**.

Era un rechazo por **ocupacion**, sin ninguna relacion con el acceso a la casa.
Se corrigio **sacando a A del camino de medicion**: entra por convocatoria,
porque su acceso no es lo que se mide.

Ese intento dejo ademas dos defectos visibles que tambien se corrigieron: los
reintentos reiniciaban el mismo contador que servia de limite, asi que el limite
**nunca** llegaba; y la orden de devolver la casa se habria emitido **una vez
por cuadro** durante medio segundo.

### Intento 2: una fase huerfana

Al sacar el paso "A camina a su casa" quedo la **transicion** hacia el, sin
manejador. La maquina entraba a un estado que nadie atendia.

Se corrigio y se agrego una **auditoria del grafo de fases** que compara
destinos contra manejadores. Hoy da: 43 y 43, **cero huerfanos en los dos
sentidos**.

**La expectativa nunca se modifico**, verificado por hash en los tres intentos:
fixture `1f6253d1…` y `QACase` `e769284d…`, byte-identicos antes del primer
lanzamiento y despues del ultimo. Lo unico que cambio fue el adaptador,
recongelado cada vez.

---

## 11. Seis aserciones, y por que no mas

| # | Asercion | Falso positivo que cierra |
|---|---|---|
| 1 | `ordinary_movement_confirmed` | via de movimiento rota |
| 2 | `session_remained_connected` | leer posiciones de una sesion caida |
| 3 | `house_access_denial_observed` | colision generica o casilla que no es de casa |
| 4 | `participant_remained_outside` | el servidor aviso pero lo dejo pasar |
| 5 | `guest_relationship_accepted_by_server` | el texto se armo bien pero el servidor no lo acepto |
| 6 | `entry_allowed` | estar en la lista no cambio nada |

**5 y 6 son observaciones distintas**, no la misma contada dos veces: una sale
de la **lista que devuelve el servidor** y la otra de la **posicion autoritativa
de B**. Una lista que se lee pero no da acceso falla la 6; un acceso sin lista
falla la 5.

**No** se agrego `authoritative_inside_transition_observed`: saldria de la misma
lectura que `entry_allowed`. Es el mismo criterio de 10 y no 11 en deposito, 7 y
no 8 en comercio, 4 y no 5 en acceso, y 5 y no 6 en acceso del dueno.

La **guarda final** —B rechazado otra vez despues de quitarlo de la lista— se
observo y **no** es una asercion: es una comprobacion de que la limpieza quito
la relacion, no una propiedad del fixture.

---

## 12. Restauracion y residuo

### La casa quedo exacta

`83|0|0|1400|1|0|0|0|0|35|2`, **byte-identica** a la linea base congelada. En el
mundo: **862** casas, **860** sin dueno, **2** con dueno, **los mismos dos**, y
`house_lists` con **0 filas** antes y despues.

### La lista: semanticamente restaurada, y despues exacta

Al devolver el texto base, el servidor contesto **27** caracteres donde la base
tenia **26**. No es un fallo de restauracion: es un **artefacto de ida y vuelta
del propio formato legacy**, y se verifico en la fuente.

`explodeString` (`tools.cpp:297-309`) parte `"# Guests of <casa>\n"` en
**dos** elementos: el encabezado y una cadena **vacia** final. El encabezado se
descarta por empezar con `#`; la vacia **no**, y recibe su `std::endl`. La lista
guardada queda como `"\n"` en vez de `""`.

Semanticamente es lo mismo: `parseList("\n")` recorre esa unica linea, la
encuentra vacia y la saltea, asi que **la lista de jugadores queda vacia** — y
la guarda final lo confirmo en vivo, porque B volvio a ser rechazado.

Y el estado final **si** es byte-identico, porque `/owner none` llama
`setAccessList(GUEST_LIST, "")` de forma incondicional (`house.cpp:69-72`). Esa
misma propiedad es la que hacia seguro el camino de emergencia del adaptador.

### Auditoria de mutacion

| Concepto | Valor |
|---|---:|
| Asignaciones de propiedad | **1** (autorizada) |
| Casas mutadas de forma permanente | **0** |
| Listas de subduenos o de puerta modificadas | **0** |
| Entradas comodin | **0** |
| Segunda casa tocada | **0** |
| Premium | **0** |
| Cuentas creadas | **0** |
| Progresion modificada | **0** |
| Camas usadas | **0** |
| Muertes / combate / monstruos / comandos amplios | **0** |

### Residuo declarado: el turno NO cierra en cero

**+1 carta de bienvenida** en el deposito de A: de **1** a **2**. Es exactamente
el residuo unico que el turno tenia autorizado, y no se intento borrarlo: la
unica via sin tocar `servidor/` lo dejaria tirado en la via publica antes de
eliminarlo, y cambiar un residuo acotado por uno mayor no es limpiar.

El deposito de B quedo en **0** cartas: intacto.

Los archivos de jugador no estan versionados (`.gitignore:25`).

---

## 13. Limitaciones

1. **Un solo invitado**, agregado una sola vez. No se probaron duplicados,
   varias entradas, ni el limite de 100 lineas de `parseList`.
2. **Nada de subdueno ni de puertas**, aunque comparten el mismo transporte.
3. **Nada de precedencia** entre niveles de acceso.
4. **Nada de comodines** (`*`) ni de gremios (`@`): el adaptador los rechaza
   antes de enviarlos.
5. **Nada de persistencia**: la lista se restauro en la misma sesion; no se
   reinicio el servidor con B adentro de ella. Conviene saber que las listas
   solo llegan a la tabla `house_lists` cuando corre un guardado completo
   (`IOMap::saveHouseDatabaseInformation`), no en cada edicion.
6. **Una sola casa, una sola casilla, una sola direccion** de entrada.
7. **Nada de expulsar, comprar, vender, alquilar ni transferir.**

---

## 14. Bloqueos

| Bloqueo | Estado |
|---|---|
| `HOUSE_GUEST_LIST_SIN_TRANSPORTE_DE_PRODUCCION` | **RESUELTO** por `protocolo-red 2.2.0`; este turno lo **consumio**, no lo re-resolvio |
| `CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA` | **abierto y sin modificar.** No se concedio premium ni se uso ninguna cama |

---

## 15. Reproducir

```text
TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER    jugador A (dueno temporal)
TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER   jugador B (el medido)
TVP772_GOD_ACCOUNT / _PASSWORD / _GOD_CHARACTER   operador (solo montaje)
TVP772_HOUSE_ID        id de la casa de sandbox
TVP772_HOUSE_OUTSIDE   "x,y,z" casilla exterior de partida
TVP772_HOUSE_BOUNDARY  "x,y,z" casilla de la casa que se intenta pisar
TVP772_HOUSE_INSIDE    "x,y,z" casilla interior declarada
TVP772_HOUSE_OPERATOR  "x,y,z" casilla interior del operador
TVP772_HOUSE_ALREADY_OWNED   definirla SOLO si la casa ya quedo asignada por un
                             intento anterior del mismo turno; evita gastar una
                             segunda asignacion

Godot --headless --path cliente3d \
    pruebas/prueba_parity_house_guest_access_capture.tscn
```

Ningun valor de credencial aparece en el codigo, en el log, en la observacion ni
en este documento.
