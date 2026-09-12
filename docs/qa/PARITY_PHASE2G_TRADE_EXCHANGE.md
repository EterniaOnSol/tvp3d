# Phase 2G — Paridad de intercambio entre jugadores (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay grabado **`PASS 7/7`** y replay vivo
**`PASS 7/7`**, los dos con el comparador generico sin modificar, al **primer**
intento vivo.

`PARITY-TRADE-EXCHANGE-001` abre el **sexto dominio de comportamiento** del
corpus de paridad.

## 1. Por que el comercio es un dominio distinto

| Dominio | Propiedad semantica |
|---|---|
| Muerte / corpse | resultado autoritativo de una muerte |
| Reacquisicion de objetivo | memoria de objetivo del monstruo |
| Party / experiencia compartida | elegibilidad y reparto |
| Deposito | persistencia de estado de jugador entre sesiones |
| Correo | ruteo desde una direccion escrita hasta el deposito de otro |
| **Comercio** | **intercambio autoritativo de dos lados, negociado y simultaneo** |

El correo (Phase 2F) mueve un objeto en **un solo sentido** y sin que el
destinatario participe. El comercio es lo primero que exige **dos voluntades
concurrentes**: dos jugadores presentes, cada uno viendo lo que ofrece el otro,
y un cruce de propiedad que solo ocurre cuando **los dos** aceptan.

## 2. Lo que este fixture afirma, y lo que NO

**Afirma:** el camino **exitoso** del intercambio de dos lados.

**NO afirma: atomicidad transaccional bajo fallo**, es decir la propiedad
**AMBOS O NINGUNO**.

Esta distincion no es cautela retorica; sale de leer el codigo. Ver la seccion
3.3: el servidor **no tiene un deshacer transaccional**. Consigue la
consistencia **validando antes** con pruebas en seco, y si algo falla despues
de mover el primer objeto, no revierte nada. Un intercambio exitoso observado
desde el cliente **no puede distinguir** un verdadero rollback de una
validacion previa afortunada.

Certificar AMBOS O NINGUNO exige un **fixture negativo dedicado** que provoque
un fallo real de transferencia. Eso es Phase 2G.1, no esto.

Tampoco se afirma nada por **cercania temporal** de los paquetes: que dos
actualizaciones de inventario lleguen juntas no prueba atomicidad. La evidencia
decisiva es el **estado final de propiedad**, no el orden ni el instante de los
mensajes.

## 3. La regla, leida del codigo vigente del oracle

### 3.1 `Game::playerRequestTrade` (`servidor/src/game.cpp:2874-2991`)

| Validacion | Detalle |
|---|---|
| Contraparte | debe existir y **no** ser uno mismo |
| **Alcance** | `Position::areInRange<2, 2, 0>(contraparte, jugador)` |
| Linea de tiro | `canThrowObjectTo(...)` |
| Objeto | `isPickupable()`, **sin** `ITEM_ATTRIBUTE_UNIQUEID`, action id fuera de `1000..2000` |
| Identidad | el client id declarado debe coincidir con el real del objeto |
| Reserva previa | rechaza objetos ya reservados en otro comercio, en **los dos** sentidos de anidamiento |
| Comercio abierto | rechaza si el jugador ya esta comerciando |
| Contenedor | maximo **100** objetos si se ofrece un contenedor |

**El alcance merece atencion:** es `<2, 2, 0>` — dos casillas por eje y **mismo
piso**, con `dz = 0`. No tolera un piso de diferencia, a diferencia de la regla
de party (`<30, 30, 1>`) certificada en Phase 2D.1. Son reglas distintas y
conviene no confundirlas.

### 3.2 `Game::internalStartTrade` (`game.cpp:2993-3022`)

Reserva el objeto en el mapa global `tradeItems` con
`incrementReferenceCounter()`, y la emision de ofertas es **asimetrica en el
tiempo**:

- al **primer** oferente se le manda **su propia** oferta;
- a la contraparte se le avisa por texto y se la deja en `TRADE_ACKNOWLEDGE`;
- **recien cuando la contraparte ofrece a su vez**, cada uno recibe la oferta
  del otro.

Por eso el arnes no puede dar por visible la oferta cruzada hasta que **los
dos** hayan ofrecido.

### 3.3 `Game::playerAcceptTrade` (`game.cpp:3024-3135`) — la parte que importa

1. solo actua cuando **los dos** estan en `TRADE_ACCEPT`;
2. **revalida la linea de tiro** en el momento de aceptar;
3. libera las reservas de los dos objetos;
4. **prueba en seco** con `internalAddItem(..., test = true)` que cada destino
   puede recibir el objeto del otro;
5. **solo si las dos pruebas en seco dan bien**, ejecuta los movimientos reales;
6. si algo falla, manda cancelacion y dispara `ON_TRADE_CANCEL`, pero **no
   deshace** un movimiento ya realizado.

```cpp
if (tradePartnerRet == RETURNVALUE_NOERROR && playerRet == RETURNVALUE_NOERROR) {
    tradePartnerRet = internalAddItem(tradePartner, playerTradeItem, ..., true);  // seco
    playerRet       = internalAddItem(player, partnerTradeItem, ..., true);       // seco
    if (tradePartnerRet == RETURNVALUE_NOERROR && playerRet == RETURNVALUE_NOERROR) {
        ... movimientos REALES ...
        isSuccess = true;
    }
}
if (!isSuccess) { ... cancelacion, SIN deshacer ... }
```

Al terminar, con exito o sin el, los dos quedan en `TRADE_NONE` y los dos
reciben cierre de ventana (`game.cpp:3126-3134`).

**Esta es la razon exacta por la que el fixture no reclama atomicidad.**

### 3.4 Cancelacion: `Game::internalCloseTrade` (`game.cpp:3214-3260`)

Libera reservas, dispara `ON_TRADE_CANCEL` sobre los objetos de los dos,
resetea los dos estados y cierra las dos ventanas. Tiene una guarda explicita:
**no hace nada si alguno esta en `TRADE_TRANSFER`**, es decir que no se puede
cancelar en mitad de la transferencia.

### 3.5 El grupo del jugador no interviene

Ninguna de las funciones de comercio consulta el grupo ni los permisos del
jugador. Aun asi, esta corrida usa **dos jugadores normales** y deja al
operador **fuera** del comercio, para que no quede ninguna duda de que un
privilegio pudo haber influido en el resultado.

## 4. Opcodes: el mismo numero significa cosas distintas segun la direccion

Verificado en el codigo, y vale la pena escribirlo porque es una trampa real:

| Numero | **Entrante** (cliente -> servidor) | **Saliente** (servidor -> cliente) |
|---|---|---|
| `0x7D` | solicitar comercio | **mi** oferta |
| `0x7E` | mirar objeto de la ventana | oferta de la **contraparte** |
| `0x7F` | **aceptar** | **cerrar** la ventana |
| `0x80` | cerrar/cancelar | — |

Fuentes: `protocolgame.cpp:511-513` (entrante) y `protocolgame.cpp:1465-1509`
(saliente). O sea que `0x7F` entrante es "acepto" y `0x7F` saliente es "se
cerro".

**Ningun numero de opcode entra al payload.** Son metadata de origen: el
servidor nativo futuro no tiene por que reproducir la numeracion de 7.72.

## 5. Transporte de produccion, no bytes rearmados en QA

La evidencia historica dice que `Conexion772` **no exponia** la solicitud
inicial y que QA armaba el payload a mano.

**Eso ya no es cierto.** Hoy `cliente3d/red/conexion772.gd` publica:

- `enviar_solicitar_comercio(origen, client_id, stackpos, id_jugador)`
- `enviar_solicitar_comercio_inventario(ranura, client_id, id_jugador)`
- `enviar_aceptar_comercio()`
- `enviar_cerrar_comercio()`
- `enviar_mirar_comercio(es_contraparte, indice)`

Asi que este adaptador usa el **metodo de produccion** y **no** duplica el
formato del paquete dentro de QA. La deuda que la evidencia historica dejaba
abierta esta saldada del lado del transporte.

## 6. Evidencia historica, y la separacion de VIP

`docs/qa/PRUEBA_VIVA_TRADE_VIP.md` (2026-08-29) mezcla **dos** areas de
comportamiento: presencia VIP y comercio. Phase 2G congela **solo comercio**.

### 6.1 Hechos de comercio auditados linea por linea

| # | Hecho congelado | Respaldo textual |
|---:|---|---|
| 1 | `participants_within_trade_range` | `OK: servidor reune ambos jugadores a distancia de trade` |
| 2 | `each_participant_offered_a_real_item` | `OK: Valentino recoge un objeto real para contraofertar` + `OK: el servidor crea un segundo objeto para la oferta del god` |
| 3 | `both_participants_saw_own_and_counterpart_offer` | `OK: ambos clientes reciben oferta propia y contraparte` |
| 4 | `both_participants_accepted` | paso 7 del recorrido: *"Ambos aceptan con `0x7F`"* |
| 5 | `trade_closed_for_both_participants` | `OK: servidor cierra trade en ambas sesiones tras aceptar` |
| 6 | `no_trade_error_observed` | `OK: trade aceptado no devuelve error mecanico` |
| 7 | `both_offered_items_transferred` | `OK: trade transfiere ambos objetos en inventarios autoritativos` |

**Siete** aserciones.

### 6.2 Por que siete y no ocho

Una forma tentadora era partir el hecho 3 en **cuatro** (A vio la propia, A vio
la de la contraparte, B vio la propia, B vio la de la contraparte) y llegar a
ocho.

**No se hizo.** El documento historico registra **un solo assert combinado**:
`ambos clientes reciben oferta propia y contraparte`. Partirlo en cuatro seria
**fabricar granularidad** que la corrida historica no midio por separado. El
hecho combinado tiene exactamente la misma fuerza de deteccion —si cualquiera
de las cuatro vistas faltara, el assert combinado tambien fallaria— y no
inventa precision que no existio.

El **adaptador vivo si** distingue las cuatro vistas por separado y aborta si
alguna falta; eso queda como guarda viva documentada en la seccion 11.

### 6.3 VIP, excluido a proposito

**Ningun** hecho de VIP entra al fixture: ni el alta por nombre, ni el GUID
devuelto, ni las transiciones online/offline. VIP es un dominio propio y
merece su propio fixture (`PARITY-VIP-PRESENCE-001`), no un anexo del contrato
semantico del comercio.

## 7. Roles y aislamiento

| Rol | Quien | Por que |
|---|---|---|
| `TRADE_A` | jugador **normal** dedicado de QA, cuenta 1 | ofrece y recibe |
| `TRADE_B` | jugador **normal** dedicado de QA, **cuenta 2** | ofrece y recibe |
| `OPERADOR` | personaje con permisos, **fuera** del comercio | solo posiciona y crea los objetos de prueba |

Las cuentas son **distintas** a proposito: una cuenta normal no admite dos
sesiones simultaneas, y ademas elimina cualquier acoplamiento accidental entre
las dos sesiones.

El operador **no participa** del comercio. La evidencia historica uso el god
como una de las dos puntas por comodidad; aca se prefiere que los dos lados
sean jugadores normales para que no quede duda de que un privilegio de grupo,
un salto de capacidad o un comportamiento de inventario especial hayan
influido.

**0 personajes del usuario.** Credenciales **solo por entorno**; sin la
variable requerida la captura corta con `BLOCKED` y codigo 2 **antes** de abrir
ningun socket (verificado: 0 lineas de conexion). Busqueda de personaje
**exacta**, sin enumerar la cuenta.

## 8. Objetos de prueba

### 8.1 Por que no se reusaron los que ya tenian

Los dos participantes tienen **exactamente el mismo juego** de objetos
iniciales (chaqueta, antorcha, garrote). Usar garrote contra antorcha habria
dejado la propiedad **ambigua**: cada uno ya posee un ejemplar de los dos
tipos, asi que despues del intercambio la unica lectura posible seria por
conteo, no por presencia.

Como la regla del dominio es no medir sobre duplicados, se descarto la
reutilizacion.

### 8.2 Lo que se creo

`test_items_created = 2`, de **tipos distintos**, y **ninguno de los dos
participantes posee ya uno**:

| Rol | Tipo | Por que es seguro |
|---|---|---|
| `OFFER_A` | yelmo de cuero | movible, **no** apilable, **no** contenedor, sin cargas, **sin `duration` ni `decayto`** |
| `OFFER_B` | botas de cuero | idem, y mas liviano todavia |

Verificado contra los datos vigentes del oracle antes de elegirlos. Los tipos
concretos son **metadata del harness** y **no entran** al payload.

### 8.3 Aprovisionamiento sin tocar equipo ajeno

El arnes historico "normalizaba las manos" vaciando ranuras. **Este no lo
hace.**

El operador crea cada objeto, lo apoya en el **suelo**, y cada participante lo
levanta a una ranura que tiene **vacia** (cabeza y pies). Ninguno de los dos
participantes tiene nada equipado ahi, asi que **nada de su equipo preexistente
se mueve**. Si alguna de esas ranuras no estuviera vacia, la captura devuelve
`BLOCKED` en vez de desplazar algo ajeno.

**No se usa el comercio para aprovisionar**: seria usar justo el mecanismo que
se esta midiendo.

## 9. Nada se da por bueno sin volver a leerlo

- La visibilidad de las ofertas **no** se infiere de haber mandado el pedido:
  se exige que las **dos** sesiones hayan recibido de verdad su oferta propia y
  la de la contraparte, por el evento autoritativo del parser.
- El cierre **no** se da por hecho: se exige el evento de cierre en **las dos**
  sesiones.
- La transferencia **no** se da por hecha por ausencia de error: se compara la
  **matriz de propiedad** completa antes y despues.
- Una transferencia **a medias** es `FAIL`, no una forma rara de `PASS`.

## 10. Artefactos

| Artefacto | Ruta |
|---|---|
| Fixture | `qa/parity/fixtures/tvp772/trade_exchange/parity-trade-exchange-001.json` |
| `QACase` | `qa/parity/cases/tvp772/trade_exchange/parity-trade-exchange-001.case.json` |
| `RECORDED_EVIDENCE` | `qa/parity/observations/tvp772/trade_exchange/recorded/parity-trade-exchange-001.observation.json` |
| Captura | `cliente3d/pruebas/prueba_parity_trade_exchange_capture.gd` + `.tscn` |
| Observacion viva | `qa/parity/observations/tvp772/trade_exchange/live/parity-trade-exchange-001.observation.json` |
| Reporte grabado | `qa/parity/reports/replay_recorded_trade_exchange_report.json` |
| Reporte vivo | `qa/parity/reports/replay_live_trade_exchange_report.json` |

`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, `MATCH_EXPECTED`.
`tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`,
`case_id == fixture_id`. **Sin cambios de schema.**

Replay contra evidencia grabada con `replay.py` **sin modificar**:
**`PASS 7/7`**, byte-identico entre dos corridas
(`sha256 666c91560d4ea2ed49e66f9ad1d2fe19df0e10c28ad1c3bcba84d23bdfca6ece`).

## 11. Congelamiento previo a la corrida viva

| Artefacto | SHA-256 |
|---|---|
| fixture | `c9880a536e5213b011f036803d2bbb3bf4a521bc7eb88ec92adf896728558aae` |
| `QACase` | `1ac79ee19d2dc5c06fb9e5fa88745f987cf8ae9f47dff7521fd0274e07d643e7` |
| observacion grabada | `7f7cbdca3094a6739253db2528f0a319beab1c0916f9c716e57ab061b701eca8` |
| captura `.gd` | `2ee635863a656c133407356fa9cfe7c8ffe23b8b7ce9e4dbec2239149db9300a` |
| helper de credenciales | `edf69015380ee78bc05ff6966e6978665d45caebf60c34431e039cb4f24ef896` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en Phase 2D, 2D.1,
2D.2, 2E y 2F.

## 12. Resultado en vivo — **CERTIFICADO**

**Exito al PRIMER intento vivo** (1 de 3 permitidos), codigo de salida 0 y
exactamente **una** linea `OBSERVATION_JSON`. **0 salidas de preflight.**

Es el primer dominio del corpus que sale limpio de una sola vez pese a
involucrar **tres sesiones simultaneas**, y eso se debe a que las lecciones de
las fases anteriores ya estaban incorporadas al diseno desde el principio:
esperar a que el operador se aparte antes de mover a nadie, no ocupar ranuras
que puedan estar llenas, y no heredar coordenadas sin comprobarlas.

### 12.1 Cronologia observada

| Etapa | Observacion |
|---|---|
| Sesiones | Operador + `TRADE_A` + `TRADE_B`, con 6-7 s entre aperturas por la proteccion de conexiones del servidor |
| Reunion | El operador junta a los dos y **se aparta**, quedando fuera del comercio |
| Provision | El operador crea cada objeto y lo apoya en el suelo; cada participante lo levanta a una ranura **que tenia vacia** |
| Linea base | A tiene lo suyo=`true`, lo del otro=`false`; B tiene lo suyo=`true`, lo del otro=`false` |
| Alcance | Recalculado sobre las posiciones reportadas: **holgadamente dentro** |
| Oferta de A | `... wants to trade with you.` recibido por B — coherente con `internalStartTrade`, que primero solo avisa |
| Oferta de B | Recien ahi **cada uno** recibe la oferta del otro |
| Ofertas | Las **dos** sesiones recibieron su oferta propia **y** la de la contraparte |
| Aceptacion | A acepta, despues B acepta |
| Cierre | El servidor cerro la ventana en **las dos** sesiones |
| **Propiedad final** | A conserva lo suyo=`false`, recibio lo del otro=`true`; B conserva lo suyo=`false`, recibio lo del otro=`true` |

Duracion total: **~34 s**.

El aviso de texto que recibe B confirma en vivo la lectura del codigo de la
seccion 3.2: el primer oferente solo ve **su** oferta y la contraparte recibe
un aviso; la oferta cruzada aparece **despues** de que el segundo ofrezca.

### 12.2 Corroboracion independiente en la persistencia

Leida **fuera** del camino de observacion del cliente, con **los dos
participantes ya desconectados**:

| Participante | Ofrecio | Estado persistido final |
|---|---|---|
| `TRADE_A` | yelmo | **botas** equipadas; **cero** yelmos |
| `TRADE_B` | botas | **yelmo** equipado; **cero** botas |

El cruce es exacto en las dos direcciones y **sobrevive al cierre de sesion**.
Ademas el servidor coloco cada objeto recibido en su ranura correspondiente,
que es el comportamiento esperado de `internalAddItem` con `INDEX_WHEREEVER`.

Es **evidencia de apoyo documental**: no se agrego ningun campo al fixture por
esto y no se congelo ninguna forma de archivo.

### 12.3 Guardas vivas que NO se congelaron

La corrida viva probo **mas** de lo que afirma el fixture. Todas se cumplieron
y quedan documentadas **sin** entrar al payload, porque la evidencia historica
no las demuestra con esa granularidad:

| Guarda viva | Resultado |
|---|---|
| Las **cuatro** vistas de oferta por separado (A propia, A contraparte, B propia, B contraparte) | **si** |
| Matriz de propiedad completa **antes** del comercio | **si** |
| Matriz de propiedad completa **despues** del comercio | **si** |
| Los dos participantes son jugadores **normales** | **si** |
| Cuentas **distintas** | **si** |
| El operador queda **fuera** del comercio | **si** |
| Alcance recalculado sobre posiciones reales | **si** |
| Corroboracion en persistencia tras desconectar | **si** |
| Una transferencia **parcial** habria sido `FAIL` | guarda armada, no ejercitada |

### 12.4 Mutaciones y residuos

| Concepto | Valor |
|---|---|
| Objetos de prueba creados | **2** (uno por participante) |
| Objetos del usuario tocados | **0** |
| Equipo preexistente desplazado | **0** — se usaron ranuras vacias |
| Personajes del usuario usados | **0** |
| Cuentas / personajes creados | **0** |
| Credenciales cambiadas | **0** |
| Combate / ataques | **0** |
| Monstruos invocados | **0** |
| Muertes de jugador | **0** |
| Usos de `/killall` | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

**Residuo declarado:** los **dos objetos frescos** quedan con los participantes
de QA, cruzados: cada uno conserva el que recibio del otro. Es el **resultado**
del fixture y dejarlo asi es lo correcto.

**No se hizo un comercio inverso de limpieza.** Correspondia solo si se
hubieran reusado objetos preexistentes; como se crearon frescos, la guia es
dejarlos con los participantes de QA salvo que exista un mecanismo de borrado
acotado y probado, y no lo hay. **No se uso ninguna limpieza amplia.**

### 12.5 Replay y congelamiento

- Replay contra **evidencia grabada**: **`PASS 7/7`**, byte-identico entre dos
  corridas
  (`sha256 666c91560d4ea2ed49e66f9ad1d2fe19df0e10c28ad1c3bcba84d23bdfca6ece`).
- Replay contra **observacion viva**: **`PASS 7/7`**, byte-identico entre dos
  corridas
  (`sha256 e90e94484912e651596454ecb4b8bb7367a706f9dad34fdb899b362299c133c2`).
- Los **9 hashes congelados** de la seccion 11 se recalcularon despues de la
  corrida, del wrap y de los cuatro replays: **identicos los nueve**.
- `replay.py` y `wrap_live_observation.py` **no se modificaron**: aceptaron un
  **septimo** dominio de comportamiento sin ningun cambio.

### 12.6 Credenciales

Ninguna credencial se imprimio, se guardo ni se versiono. Busqueda de personaje
**exacta**; sin la variable requerida la captura corta con `BLOCKED` y codigo
**2** antes de abrir ningun socket (verificado: **0** lineas de conexion).

## 13. Lo que este fixture NO afirma

- **NO** certifica la propiedad **AMBOS O NINGUNO** bajo fallo de
  transferencia. Ver secciones 2 y 3.3: el servidor valida antes en seco, no
  deshace despues.
- **NO** certifica el borde del alcance de comercio (2 contra 3 casillas).
- **NO** certifica la cancelacion por parte de un participante.
- **NO** certifica el logout ni la desconexion en mitad de un comercio.
- **NO** certifica el rechazo por capacidad.
- **NO** certifica la invalidacion de un objeto con el comercio ya abierto.
- **NO** certifica contenedores con objetos anidados: los dos objetos de prueba
  son simples.
- **NO** congela ningun numero de opcode legacy.
- **NO** afirma nada sobre VIP.

## 14. Siguiente paso recomendado, evaluado contra el codigo

La continuacion natural seria **Phase 2G.1 — cancelacion y rollback**, para
certificar de verdad AMBOS O NINGUNO. Evaluada contra el codigo, se divide en
dos piezas de dificultad muy distinta:

**(a) Cancelacion explicita: viable y limpia.** `internalCloseTrade`
(`game.cpp:3214-3260`) es un camino normal y observable: un participante
cancela, los dos reciben `Trade cancelled.`, las dos ventanas cierran y
**ningun** objeto cambia de dueno. No exige nada artificial y da un fixture
negativo honesto.

**(b) Fallo de transferencia real: exige un montaje forzado.** Para que
`isSuccess` quede en false hay que hacer fracasar `internalAddItem`, es decir
llenar el inventario del destinatario o exceder su capacidad. Es un montaje
deliberadamente destructivo sobre un personaje de QA y, mas importante, la
propia lectura del codigo dice que **no hay deshacer**: lo que se certificaria
es que la validacion previa evita el estado inconsistente, que es una
afirmacion mas debil y **distinta** de "rollback".

**Recomendacion:** abrir Phase 2G.1 **solo con (a)**, la cancelacion explicita,
y dejar (b) declarado como hueco conocido. Alternativa de igual valor y menor
riesgo: `PARITY-VIP-PRESENCE-001`, que ya tiene evidencia historica fuerte en
el mismo documento y quedo deliberadamente fuera de este fixture.
