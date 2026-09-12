# Phase 2F — Paridad de entrega de correo (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay grabado **`PASS 6/6`** y replay vivo
**`PASS 6/6`**, los dos con el comparador generico sin modificar.

`PARITY-PARCEL-DELIVERY-001` abre el **quinto dominio de comportamiento** del
corpus de paridad.

## 1. Por que el correo es un dominio distinto

| Dominio | Propiedad semantica |
|---|---|
| Muerte / corpse | resultado autoritativo de una muerte |
| Reacquisicion de objetivo | memoria de objetivo del monstruo |
| Party / experiencia compartida | elegibilidad y reparto |
| Deposito | persistencia de estado de jugador entre sesiones |
| **Correo** | **ruteo autoritativo desde una direccion escrita hasta el deposito de otro jugador** |

La ventana de texto, el contenedor y la persistencia del deposito son
**mecanismos de apoyo** y ya estan cubiertos. Lo nuevo aca es que el servidor
**lee una direccion escrita por el jugador y transporta un objeto hasta el
deposito del destinatario direccionado**, incluso si ese destinatario **no esta
conectado**. Es la primera vez que el corpus mide una decision de ruteo entre
dos identidades distintas.

## 2. Evidencia historica

`docs/qa/PRUEBA_VIVA_PARCEL.md` (2026-08-29) es la fuente **unica** de la
observacion `RECORDED_EVIDENCE`.

### 2.1 Auditoria linea por linea

Cada hecho congelado, con su respaldo textual:

| # | Hecho | Respaldo |
|---:|---|---|
| 1 | `text_window_opened` | `OK usar la etiqueta abre la ventana de texto del servidor` (linea 94) |
| 2 | `address_roundtrip_matches` | `OK el servidor guarda lo que se escribio en la etiqueta` (96) + *"El texto se comprueba leyendolo de vuelta, no solo mandandolo."* (100) |
| 3 | `written_label_inserted` | `OK la etiqueta escrita entra en la parcel` (97) |
| 4 | `mailbox_present` | *"El mailbox del mapa esta donde dice el OTBM y el cliente lo ve."* (127) |
| 5 | `submitted_parcel_consumed` | *"El mailbox se lleva la parcel: al dejarla encima desaparece de la casilla... `/tileinfo`... la parcel recien dejada ya no estaba mientras una parcel vieja de otra corrida seguia ahi."* (106-109) |
| 6 | `recipient_depot_received_parcel` | *"El usuario ejecuto el recorrido vivo y confirmo que la parcel aparece dentro del depot del destinatario. La persistencia local tambien conserva parcels dirigidas en depot 1..."* (113-115), mas la linea de estado del documento (7-8) |

**Grado de evidencia declarado.** Los hechos 1 a 5 son lineas de salida del
arnes historico. El hecho 6 es distinto y se dice sin adornos: es una
**confirmacion del usuario sobre el recorrido vivo**, corroborada por los datos
persistidos, no una linea de assert del arnes. El documento lo afirma dos veces
como resultado verificado de punta a punta, asi que se congela; pero un
revisor merece saber exactamente que clase de evidencia sostiene cada
asercion.

### 2.2 Lo que NO se congelo, por no estar demostrado

La corrida viva nueva es **mas fuerte** que la historica, y aun asi esos
hechos **no** entraron al payload:

- remitente y destinatario distintos;
- destinatario **desconectado** durante el envio;
- sesion nueva del destinatario despues del envio;
- deposito del destinatario **+1** contra una linea base;
- relectura de la etiqueta dentro de la encomienda entregada.

Son **guardas del arnes vivo**. Que la prueba nueva sea mejor no convierte esos
hechos en historia.

## 3. La regla, leida del codigo vigente del oracle

### 3.1 `Mailbox::getReceiver`

```cpp
const Container* container = item->getContainer();
if (container) {
    for (Item* containerItem : container->getItemList()) {
        if (containerItem->getID() == ITEM_LABEL && getReceiver(containerItem, name, town)) {
            return true;
        }
    }
    return false;
}
...
while (getline(iss, temp, '\n')) {
    if (currentLine == 1)      name = temp;
    else if (currentLine == 2) town = temp;
    else break;
    ++currentLine;
}
trimString(name); trimString(town);
```

Verificado, no supuesto:

| Propiedad | Valor |
|---|---|
| Busqueda | dentro del contenedor, por **id de etiqueta**, recursivo |
| Formato | **DOS LINEAS**: linea 1 destinatario, linea 2 **nombre del pueblo** |
| Limpieza | `trimString` en las dos |

Esto corrige una lectura ingenua de la evidencia historica: alli el texto se
**imprime** como `'Valentino / Thais'`, pero el arnes historico escribia
`"%s\n%s"` y solo reemplazaba el salto por `" / "` **para mostrarlo**. Codigo y
evidencia coinciden: la direccion va en dos lineas. Una sola linea dejaria el
pueblo vacio y el envio fallaria en silencio.

### 3.2 `Mailbox::sendItem`

```cpp
Town* town = g_game.map.towns.getTown(townName);
...
Player* player = g_game.getPlayerByName(receiver);
if (player) {                       // ONLINE
    DepotLocker* depotLocker = player->getDepotLocker(town->getID(), true);
    ... internalMoveItem(..., depotLocker, ...)
    g_game.transformItem(item, item->getID() + 1);
    player->onReceiveMail();
} else {                            // OFFLINE
    Player tmpPlayer(nullptr);
    if (!IOLoginData::loadPlayerByName(&tmpPlayer, receiver)) return false;
    DepotLocker* depotLocker = tmpPlayer.getDepotLocker(town->getID(), true);
    ... internalMoveItem(..., depotLocker, ...)
    g_game.transformItem(item, item->getID() + 1);
    IOLoginData::savePlayer(&tmpPlayer);
}
```

| Propiedad | Valor |
|---|---|
| Pueblo | se resuelve **por nombre**, sin distinguir mayusculas (`Towns::getTown`, `town.h:56-63`, usa `strcasecmp`) |
| Deposito destino | `town->getID()`, es decir el deposito **del pueblo direccionado**, no el del domicilio del destinatario |
| Destino del movimiento | el **locker**, no el cofre de adentro: la encomienda entregada queda **hermana** del cofre |
| Transformacion | `getID() + 1`: lo que llega al deposito es la encomienda **sellada**, no la original |
| Destinatario offline | se carga su archivo, se inserta y **se vuelve a guardar** |
| Remitente | **no se consulta en ningun momento**: ni grupo, ni permisos |

Esa ultima fila es la que autoriza usar al operador como remitente: el ruteo
**no depende del remitente**, asi que su grupo no puede cambiar la semantica.

Y la anteultima es la que hace valioso el diseno con destinatario
desconectado: obliga al servidor a recorrer el camino que **persiste** el
resultado antes de que el destinatario vuelva.

### 3.3 `Mailbox::canSend` y `Mailbox::addThing`

`canSend` acepta unicamente encomienda o carta. `addThing` descarta el envio si
la casilla tiene mas de un objeto movible, **pero solo cuando
`trashableMailbox` es falso**; en `servidor/config.lua` esta en **`true`**, asi
que el residuo historico de la casilla **no** bloquea el envio. Se verifico
antes de disenar la corrida, porque de lo contrario la suciedad conocida habria
invalidado el recorrido entero.

`disabledMailboxes` esta vacio: ningun pueblo esta deshabilitado.

### 3.4 El arreglo historico del servidor sigue puesto

La evidencia historica documenta que los items escribibles eran rechazados
**antes** de llegar a `Actions::internalUseItem`, lo que dejaba el correo
inutilizable. La guarda actual de `servidor/src/game.cpp` es:

```cpp
const ItemType& useItemType = Item::items[item->getID()];
if (!item->isUseable() && !item->getContainer() && !item->getDoor()
        && !useItemType.canReadText && !item->getBed() && !g_actions->hasAction(item)) {
```

El `&& !useItemType.canReadText` **sigue presente**, con su comentario
explicativo. **Verificado, no asumido.** Si hubiera regresado, esta captura
devuelve `BLOCKED`: QA **no repara el oracle** para poder certificarlo.

## 4. Roles y aislamiento

| Rol | Quien | Por que |
|---|---|---|
| `MAIL_SENDER` / operador | personaje operador de QA | `sendItem` no lo consulta; ademas permite creacion determinista de los objetos de prueba |
| `MAIL_RECIPIENT` | personaje **normal dedicado de QA**, en **otra cuenta** | es su deposito el que tiene que recibir |

**remitente != destinatario** y **cuenta del remitente != cuenta del
destinatario**. Ningun personaje del usuario es destinatario. **No** se
reasigna ninguna cuenta ni personaje: la tecnica historica de mover un
personaje de cuenta **no se repite**.

Credenciales **solo por entorno**, con el helper publicado en el turno de
higiene; sin la variable requerida la captura corta con `BLOCKED` y codigo 2
**antes** de abrir ningun socket (verificado: 0 lineas de conexion). La busqueda
del personaje es **exacta**; si no esta, `BLOCKED` sin enumerar la cuenta.

## 5. Pueblo de destino

Se usa **Thais**, el recorrido que la evidencia historica certifico.

La evidencia tambien documenta que **ningun locker del mapa usa el deposito 10**,
que es el numero de pueblo de Rookgaard: una encomienda dirigida ahi caeria en
un deposito que nadie puede abrir. Por eso Rookgaard **no** se ejercita.

El nombre del pueblo, su id y las coordenadas son **metadata del harness**. El
payload normaliza a `recipient_depot_received_parcel`: **no** se congela ningun
id de pueblo ni de deposito.

## 6. Objetos de prueba

A diferencia de Phase 2E, aca **se crean objetos frescos**: `test_items_created
= 2`, una encomienda y una etiqueta en blanco.

Es deliberado. Reusar una encomienda vieja produce ambiguedad real y conocida:
el propio operador ya tiene, de corridas historicas, una encomienda en su
mochila **que contiene etiquetas**. Un par nuevo y en blanco da una cadena
causal limpia.

Manejo de identidad, sin depender de nombres sueltos:

- los dos `/i` van **separados**, y cada uno se espera contra el estado
  autoritativo: la evidencia historica encontro que dos ordenes en el mismo
  instante pueden perder una;
- la encomienda nueva se identifica exigiendo que la mochila **crezca en
  exactamente uno** y se la pasa enseguida a la **mano libre**, donde su
  posicion ya no depende de indices;
- la etiqueta se resuelve por su identidad de proceso y se la mueve a la
  encomienda **por esa identidad**, no por nombre.

Se usa **una sola mano**, en secuencia, para **no desplazar nada** de lo que el
operador ya tenga equipado.

## 7. Lo que no se da por bueno sin volver a leerlo

- La direccion **no** se da por escrita porque se mando el paquete de texto: se
  **vuelve a abrir** la etiqueta y se exige que el servidor devuelva
  **exactamente** el mismo texto.
- La aceptacion del buzon **no** se da por buena porque el movimiento no diera
  error: se exige que la encomienda **deje de estar** en la casilla, medido
  contra una **linea base** tomada antes, de modo que una encomienda vieja
  apoyada ahi no pase por resultado nuevo.
- La entrega **no** se da por buena por ver una encomienda cualquiera: se
  compara contra la **linea base del deposito del destinatario**.

## 8. Prueba de deposito PERSONAL

Se reaplica la leccion de Phase 2E: abrir el mueble **no alcanza**, porque sin
activar se abre el contenedor del mapa. Se exigen las dos senales externas: el
aviso autoritativo de deposito cargado y la presencia del **cofre de deposito**
dentro del mueble.

La **cuenta** de encomiendas entregadas se hace al nivel del **locker**, no del
cofre, porque `sendItem` mueve al locker. No se lee ningun estado interno.

Y se reaplica tambien la leccion de Phase 2C.1 y 2E: **alcanzable con `/gotopos`
de un god no es lo mismo que caminable por un personaje normal**. La casilla de
salida del destinatario se **descubre empiricamente** entre las vecinas.

## 9. Suciedad historica que NO se toca

La evidencia historica deja constancia de encomiendas viejas apoyadas en la
casilla del buzon y de encomiendas dirigidas ya presentes en depositos. **No se
borran**, **no se cuentan** como resultado y **no se usan** como evidencia: por
eso todas las mediciones son contra linea base.

**No se usa `/limpiarpruebas`.** Existe como talkaction, pero este turno no lo
emplea: no se usa una herramienta de limpieza sin poder demostrar que su
alcance se limita **exactamente** a lo que esta corrida creo. Un residuo
declarado de QA es preferible a una limpieza amplia insegura.

## 10. Artefactos

| Artefacto | Ruta |
|---|---|
| Fixture | `qa/parity/fixtures/tvp772/parcel_delivery/parity-parcel-delivery-001.json` |
| `QACase` | `qa/parity/cases/tvp772/parcel_delivery/parity-parcel-delivery-001.case.json` |
| `RECORDED_EVIDENCE` | `qa/parity/observations/tvp772/parcel_delivery/recorded/parity-parcel-delivery-001.observation.json` |
| Captura | `cliente3d/pruebas/prueba_parity_parcel_delivery_capture.gd` + `.tscn` |
| Observacion viva | `qa/parity/observations/tvp772/parcel_delivery/live/parity-parcel-delivery-001.observation.json` |
| Reporte grabado | `qa/parity/reports/replay_recorded_parcel_delivery_report.json` |
| Reporte vivo | `qa/parity/reports/replay_live_parcel_delivery_report.json` |

`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, `MATCH_EXPECTED`.
`tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`,
`case_id == fixture_id`. **Sin cambios de schema.**

**Seis** aserciones `EQ`, una por hecho historico auditado en 2.1.

Replay contra evidencia grabada con `replay.py` **sin modificar**:
**`PASS 6/6`**, byte-identico entre dos corridas
(`sha256 b83c2322ce97b6bdc2b85888d715334f6415dc6cc741c81585e0bffd7c743d54`).

## 11. Congelamiento previo a la corrida viva

| Artefacto | SHA-256 |
|---|---|
| fixture | `39d66d1784252742f0c5277b1453239b3fa682a65305eff1635d32d8ce8b417e` |
| `QACase` | `3f9915426b6b64e681b8f1efe5ab921a285327d61faa10f602889d9ce6474608` |
| observacion grabada | `17d8c68fd0c9e7d0686c367b7405cd6726de10af827ff082874d6bed3dbc9cc8` |
| captura `.gd` (final, la que produjo la observacion) | `7eb9dba789240aad8d219fdf92182774d068608f4208ce70d506294333aad84b` |
| helper de credenciales | `edf69015380ee78bc05ff6966e6978665d45caebf60c34431e039cb4f24ef896` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en Phase 2D, 2D.1,
2D.2 y 2E.

Verificacion previa sin tocar el oracle: el adaptador **compila**
(`--check-only`, codigo 0) y la escena corta limpio en la guarda de
credenciales (codigo **2**, con **0** lineas de conexion).

## 12. Resultado en vivo — **CERTIFICADO**

Codigo de salida 0 y **exactamente una** linea `OBSERVATION_JSON`.

### 12.1 Los tres lanzamientos, clasificados con honestidad

| # | Clasificacion | Hasta donde llego | Causa | Correccion |
|---:|---|---|---|---|
| 1 | **salida de preflight** | posicionamiento | El destinatario **no podia desconectarse**: `You may not logout during or immediately after a fight!` | Elegir un destinatario sin condiciones persistidas |
| 2 | **intento completo 1 de 3** | creo la encomienda | `Drop the double-handed object first`: el operador lleva un **arma de dos manos**, asi que no hay mano libre | Apoyar la encomienda en el **suelo** en vez de en una mano |
| 3 | **intento completo 2 de 3** | **completa** | — | **exito** |

El lanzamiento 1 **no creo ningun objeto**, no escribio ninguna etiqueta y no
despacho nada, asi que se clasifica como salida de preflight. El lanzamiento 2
**si creo una encomienda**, asi que se cuenta como **intento completo**, aunque
nunca llego a despachar. **Intentos completos usados: 2 de 3.**

### 12.2 Los dos defectos encontrados, y por que importan

**El destinatario envenenado.** El primer candidato arrastraba un
`CONDITION_POISON` **persistido** de corridas anteriores. El veneno refresca
`CONDITION_INFIGHT`, y `ProtocolGame::logout`
(`servidor/src/protocolgame.cpp:311-322`) rechaza el logout con signo de
batalla **aunque el jugador este en zona de proteccion**; solo los personajes
con acceso estan exentos. Como el diseno fuerte de este fixture exige que el
destinatario este **desconectado** durante el envio, un destinatario que no
puede desconectarse lo invalida entero.

Se resolvio **eligiendo otro personaje dedicado de QA**, el unico sin
condiciones persistidas. **No se toco el servidor.** Se registra aparte, como
solicitud del carril `servidor`, la peticion del usuario de permitir el logout
inmediato dentro de zona de proteccion: es un cambio de producto legitimo pero
es una **divergencia declarada respecto de 7.72**, no un arreglo, y hacerlo en
medio de una certificacion habria invalidado la corrida.

**El arma de dos manos.** El operador equipa una lanza a dos manos, asi que el
servidor rechaza ocupar la otra mano. Desequiparla habria sido **tocar el
equipo de un personaje que este turno no debe modificar**. La encomienda pasa a
apoyarse en el **suelo**, en la casilla del propio remitente, que da exactamente
lo que hacia falta —una posicion estable que no depende de indices de
contenedor— sin mover nada ajeno. La casilla se verifica **vacia de encomiendas**
antes de usarla y la identidad de la encomienda se resuelve exigiendo que haya
**exactamente una** con ese identificador de proceso.

**La expectativa NUNCA se modifico**, verificado por hash en los tres
lanzamientos: fixture `39d66d17…`, `QACase` `3f991542…` y observacion grabada
`17d8c68f…` byte-identicos de punta a punta. Lo unico que cambio fue el
adaptador, recongelado cada vez (`e1abe9be…` -> `7eb9dba7…`).

### 12.3 Cronologia observada (lanzamiento 3)

| Etapa | Observacion |
|---|---|
| Linea base | El destinatario activa su deposito **personal**; el mueble trae el cofre; **0** encomiendas entregadas |
| Cierre | Sesion del destinatario **cerrada de verdad**: queda desconectado |
| Buzon | Visible; **0** encomiendas apoyadas en su casilla |
| Creacion | **1** encomienda, esperada contra el estado autoritativo; despues **1** etiqueta, en una orden **separada** |
| Ventana | El servidor **abre** la ventana de texto de la etiqueta |
| Direccion | Escrita y **releida**: el texto guardado **coincide** con el escrito |
| Insercion | La etiqueta escrita queda **dentro** de la encomienda |
| Despacho | La encomienda **sale** de la casilla del remitente y **no** queda apoyada en la del buzon |
| Sesion nueva | El destinatario entra en una sesion **nueva** |
| Reactivacion | Sale y vuelve a **entrar** a la baldosa; el servidor confirma el deposito personal |
| **Entrega** | **1** encomienda entregada contra una linea base de **0** |
| Guarda extra | La encomienda entregada **trae la etiqueta adentro** |

Duracion total: **~20 s**.

Un detalle que confirma la lectura del codigo: el aviso del deposito paso de
`1 item` a **`3 items`** entre la linea base y la reactivacion. Es coherente con
`getItemHoldingCount()` contando el cofre, la encomienda entregada y la etiqueta
de adentro.

### 12.4 Corroboracion independiente, con el destinatario DESCONECTADO

Esto es lo mas fuerte de la corrida y **no** pasa por el camino de observacion
del cliente. Se leyo el archivo de persistencia del destinatario **mientras
estaba desconectado**, despues del despacho y **antes** de su sesion nueva:

```
Depot = (1, {2594 Content={}, 2596 Content={2599 Text="<destinatario>\n<pueblo>" ...}})
```

Cuatro cosas quedan probadas de una sola vez, y ninguna depende del cliente:

1. el servidor **persistio** el resultado del ruteo antes de que el
   destinatario volviera, o sea que recorrio el camino **offline** de
   `sendItem`;
2. la encomienda llego **transformada a sellada** (`2596`), tal como predice
   `transformItem(item, item->getID() + 1)`;
3. la etiqueta viaja **dentro** de la encomienda, con su texto intacto;
4. la direccion esta guardada en **dos lineas** (`\n`), exactamente el formato
   que `getReceiver` necesita — confirmacion directa de la lectura del codigo
   de la seccion 3.1.

Es **evidencia de apoyo documental**: no se agrego ningun campo al fixture por
esto, no se congelo ninguna forma de archivo y ningun id de pueblo entro al
payload.

### 12.5 Mutaciones, residuos y limpieza

| Concepto | Valor |
|---|---|
| Objetos de prueba creados | **2** en la corrida certificada (1 encomienda + 1 etiqueta) |
| Objetos creados por el intento fallido | **1** encomienda vacia |
| Objetos del usuario tocados | **0** |
| Equipo del operador modificado | **0** |
| Personajes del usuario usados | **0** |
| Cuentas / personajes creados | **0** |
| Credenciales cambiadas | **0** |
| Combate / ataques | **0** |
| Monstruos invocados | **0** |
| Muertes de jugador | **0** |
| Usos de `/killall` | **0** |
| Usos de `/limpiarpruebas` | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

**Residuos declarados, sin disimular:**

1. **La encomienda entregada** queda dentro del deposito del destinatario de
   QA, con su etiqueta adentro. Es el **resultado** del fixture y quedarse ahi
   es lo correcto.
2. **Una encomienda vacia** en la mochila del operador, creada por el intento
   completo fallido y nunca despachada.
3. **Un cofre de deposito vacio** en el deposito del destinatario, creado por el
   propio servidor al abrir su deposito personal por primera vez, igual que en
   Phase 2E.

**No se ejecuto ninguna limpieza.** `/limpiarpruebas` existe como talkaction,
pero no se uso: no se emplea una herramienta de limpieza sin poder demostrar
que su alcance se limita **exactamente** a lo que esta corrida creo. Tres
residuos de QA declarados valen mas que una limpieza amplia insegura. Tampoco
se tocaron los residuos historicos previos.

### 12.6 Replay y congelamiento

- Replay contra **evidencia grabada**: **`PASS 6/6`**, byte-identico entre dos
  corridas
  (`sha256 b83c2322ce97b6bdc2b85888d715334f6415dc6cc741c81585e0bffd7c743d54`).
- Replay contra **observacion viva**: **`PASS 6/6`**, byte-identico entre dos
  corridas
  (`sha256 e5d627d3f4329e5a298b6745e6ea0e1e1cb0c617110c3b8daa47c07a2900ddb1`).
- Los **9 hashes congelados** de la seccion 11 se recalcularon despues de la
  corrida, del wrap y de los cuatro replays: **identicos los nueve**.
- `replay.py` y `wrap_live_observation.py` **no se modificaron**: aceptaron un
  **sexto** dominio de comportamiento sin ningun cambio.

### 12.7 Credenciales

Ninguna credencial se imprimio, se guardo ni se versiono. La busqueda del
personaje es **exacta**; sin la variable requerida la captura corta con
`BLOCKED` y codigo **2** antes de abrir ningun socket (verificado: **0** lineas
de conexion).

## 13. Guardas vivas que NO se congelaron

La corrida viva probo **mas** de lo que afirma el fixture. Estas guardas se
cumplieron todas y quedan documentadas, **sin** entrar al payload, porque la
evidencia historica no las demuestra:

| Guarda viva | Resultado |
|---|---|
| remitente **distinto** del destinatario | **si** |
| cuentas distintas | **si** |
| destinatario **desconectado** durante el envio | **si** |
| sesion **nueva** del destinatario despues del envio | **si** |
| deposito del destinatario **+1** contra linea base | **si** |
| deposito **personal** positivamente identificado en las dos sesiones | **si** |
| casilla del buzon medida contra linea base | **si** |
| la encomienda entregada **trae la etiqueta** adentro | **si** |
| persistencia del ruteo corroborada **antes** del regreso | **si** |

Que la prueba nueva sea mejor **no** convierte esos hechos en historia. Si en
algun momento se quiere congelarlos, corresponde un fixture propio con su
propia evidencia.

## 14. Lo que este fixture NO afirma

- **No** certifica todos los pueblos: se ejercito uno solo.
- **No** certifica que el correo sea utilizable en Rookgaard; la evidencia
  historica documenta justamente lo contrario.
- **No** certifica el rechazo de una direccion invalida.
- **No** certifica que pasa con un destinatario inexistente.
- **No** certifica las cartas por separado de las encomiendas.
- **No** congela ningun id de pueblo ni de deposito.
- **No** congela ningun indice de ventana de contenedor del cliente.
- **No** congela la forma interna con que el servidor serializa a un jugador
  desconectado.
- **No** afirma el valor de ninguna variable interna del servidor.

## 15. Solicitud registrada para el carril `servidor`

Durante este turno el usuario pidio que un personaje **pueda desconectarse de
inmediato dentro de una zona de proteccion**.

Estado: **registrado, no implementado.** No se toco `servidor/`.

Analisis para quien lo tome:

- La guarda vive en `ProtocolGame::logout`
  (`servidor/src/protocolgame.cpp:311-322`) y rechaza el logout con
  `CONDITION_INFIGHT` **sin** consultar la zona; solo
  `player->isAccessPlayer()` exime.
- Es el comportamiento de TFS y del Tibia original, asi que quitarlo es una
  **divergencia deliberada respecto de 7.72**, no una correccion de defecto.
  Si se aplica, conviene declararlo como tal para que no se lea despues como
  paridad.
- Un cambio minimo y acotado seria permitir el logout cuando el jugador esta en
  `ZONE_PROTECTION`, dejando intacta la guarda fuera de ella.
- **Impacto sobre este corpus:** ninguno de los fixtures actuales afirma nada
  sobre el logout en combate, asi que el cambio no invalida ninguna
  certificacion existente. Si que haria mas facil este mismo fixture, porque el
  destinatario podria desconectarse aun con veneno encima.
