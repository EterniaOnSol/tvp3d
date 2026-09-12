# Estado: qa

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-09-12T12:30:00-06:00
Contrato publicado: SI (`CONTRATO.md` v2.1.1, sin cambios en este turno)

## Turno cerrado: Auditoria de evidencia de casa y cama — `NO_VALID_FIXTURE`

Turno de **auditoria**, dentro de Phase 2. **No se materializo ningun fixture,
`QACase`, `RECORDED_EVIDENCE` ni `LIVE_ORACLE`.** Inventarios **sin cambio**.
Detalle completo en `docs/qa/AUDITORIA_CASA_CAMA_PARIDAD.md`.

### El resultado no es el esperado, y esta bien que no lo sea

Se esperaba convertir `PRUEBA_VIVA_CASA_CAMA.md` —la unica evidencia historica
sin fixture— en cobertura de paridad. **No se pudo, por dos motivos
independientes**, cada uno suficiente por si solo.

### 1. El documento no tiene ninguna observacion positiva

De sus 21 lineas: **1** `RUNTIME_OBSERVATION`, 0 `SOURCE_OR_API_FACT`, 4
`TEST_SETUP`, 1 `CLEANUP`, 2 `INFERENCE`, 1 `UNRESOLVED`, 2
`ENVIRONMENTAL_DEPENDENCY`.

Y esa **unica** observacion es un **fallo**: `You cannot use this object`. El
documento dice de si mismo que *"no se puede afirmar todavia el ciclo de
despertar ni la persistencia"*.

**No se creo `RECORDED_EVIDENCE`**, y no por formalismo: ese rechazo era un
**defecto del servidor ya corregido**. Congelarlo habria metido un **bug** en
el corpus como paridad esperada, habria sido **falso** sobre el TVP actual y
habria garantizado una regresion.

### 2. El bloqueo historico estaba MAL ETIQUETADO

Este es el hallazgo de mayor valor del turno.

`CASAS_CAMAS_DOCKER_RETEST_PENDIENTE` venia arrastrandose en el campo
`blockers` de casi todos los cierres de QA desde Phase 1H **sin que nadie
reevaluara su contenido**. Su nombre dice **Docker**. La causa real **no era
Docker**.

Las dos hipotesis del documento historico —zona de proteccion, permiso de
casa— eran **incorrectas**. La causa real esta documentada **en el propio
codigo**, en el comentario de la guarda de uso de `servidor/src/game.cpp`:

> *"Beds are the same story... Without this exception every bed use was
> rejected right here, before `BedItem::canUse` ever ran."*

Es la **misma familia de defecto** que bloqueaba el correo en Phase 2F, y la
correccion (`&& !item->getBed()`) **ya esta aplicada**.

### Por que igual NO se certifico en vivo

Que la causa original este resuelta **no** habilita certificar.
`BedItem::canUse` (`bed.cpp:79-102`) exige **premium** y que la cama este en
una **casa**. Con `freePremium = false` y `housesOnlyPremium = true`, ningun
participante de QA es premium ni posee casa.

Las tres vias posibles estan **prohibidas**: conceder premium a una cuenta de
QA, asignar una casa a un personaje de QA, o usar el operador —que si cumple,
pero vive en la **cuenta personal del usuario**, y dormir mutaria la cama, su
posicion, su vida/mana y lo forzaria a desconectarse—.

**Motivo adicional y de peso:** la casa que el operador figura poseyendo es
**exactamente la que el documento historico dice haberle asignado
temporalmente**, prometiendo restaurarla. **Sigue asignada.** Construir un
fixture sobre ella seria construir evidencia **encima de un residuo de QA sin
restaurar**: pareceria verde mientras el residuo existiera y se caeria en
silencio al limpiarlo.

### Tratamiento del bloqueo: reemplazo, no cierre

- `CASAS_CAMAS_DOCKER_RETEST_PENDIENTE` → **superado en su causa tecnica**: era
  un defecto de `game.cpp`, ya corregido, **no** una cuestion de Docker.
- **`CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA`** → bloqueo **nuevo y
  preciso**: no existe participante dedicado de QA que sea premium y posea una
  casa, y crearlo exige una mutacion prohibida.

**La historia no se reescribe**: los eventos previos quedan intactos y esto se
registra como evento compensatorio append-only.

### Cero de todo

**0 fixtures creados, 0 mutaciones, 0 casas asignadas, 0 premium concedido, 0
camas usadas, 0 durmientes desalojados, 0 cuentas creadas, 0 muertes, 0
combate, 0 monstruos, 0 comandos amplios, 0 contenedores Docker tocados, 0
archivos de `servidor/` modificados.** `PRUEBA_VIVA_CASA_CAMA.md` **no se
reescribio**: es evidencia historica.

## Conteos (auditoria — sin cambio)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 14 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 14 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 9 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 11 (sin cambio) |

Phase 2 sigue **EN CURSO**.

### Propiedades de casa y cama sin certificar

**Todas.** El dominio no tiene ninguna cobertura: acceso a la casa, uso de
cama, dormir, despertar, regeneracion, persistencia en cualquiera de sus cuatro
fronteras, dependencia de propiedad, cama ya ocupada y diferencia entre mitades.

**Le toca:** **`PARITY-HOUSE-ACCESS-001`**. La restriccion de acceso a una casa
se puede probar **sin poseer ninguna y sin premium**: un participante de QA
intenta entrar a una casa ajena y el servidor lo impide, con el control
positivo de que la casilla **si** es alcanzable para quien corresponde. Es la
unica parte del dominio que no exige ninguna mutacion prohibida. **No** tiene
evidencia historica, asi que seria `LIVE_ORACLE` unicamente, como ya lo son
`PARITY-TRADE-CANCEL-001` y los negativos de experiencia compartida.

Conseguir un participante de QA premium y con casa es una peticion para
`integracion`/`servidor`; **QA no debe resolverla mutando estado ajeno**.

## Turno cerrado: `PARITY-VIP-PRESENCE-001` — Presencia en la lista de contactos

**CERTIFICADO EN VIVO.** Replay grabado **`PASS 5/5`** y replay vivo
**`PASS 5/5`**, los dos byte-identicos entre corridas. Detalle completo en
`docs/qa/PARITY_VIP_PRESENCE.md`.

Fixture `LEGACY_PARITY` **dentro de Phase 2**. No se abrio ninguna fase ni
sub-fase nueva y **no se toco** `docs/tibia3d/MASTER_PLAN.md`.

### Que certifica

Que un personaje existente puede agregarse a la lista de contactos de otro
**indicando solo su nombre**, que el servidor **resuelve ese nombre a la
identidad real**, que la entrada nace **desconectada**, y que el observador
recibe las **transiciones de presencia** cuando ese personaje entra y sale.

### La regla, verificada en el codigo

- `Game::playerRequestAddVip` (`game.cpp:3417-3456`): con el objetivo
  desconectado resuelve contra la persistencia con `getGuidByNameEx`, que
  devuelve la **identidad real** y ademas **canoniza el nombre**; si no existe,
  no crea nada; la entrada nace en `VIPSTATUS_OFFLINE`.
- **La propagacion es lo que hace fuerte al fixture.** `addList`/`removeList`
  (`player.cpp:1987-2003`) recorren a **todos** los conectados y llaman a
  `notifyStatusChange`, que **solo** notifica si la identidad esta en la lista
  del observador. Eso convierte a cada transicion en una **prueba independiente
  de que el nombre se resolvio al personaje correcto**.
- Por eso mismo la presencia **no depende de la posicion**: esta captura **no
  usa operador**, no mueve a nadie y no crea nada. Dos sesiones y nada mas.
- `specialvip` solo aparece en grupos elevados, asi que el objetivo **tiene** que
  ser un jugador normal: usar al operador habria sido rechazado.

### Opcodes: la trampa mas filosa vista hasta ahora

`0xD2` y `0xD3` **entrantes son de APARIENCIA**, no de contactos; salientes si
son de contactos (entrada, conectado). El alta es `0xDC` y la baja `0xDD`.
Ninguno entra al payload. QA usa el **transporte y el parser de produccion**,
sin rearmar paquetes.

### Cinco aserciones, con criterio consistente

Las dos transiciones **si** se congelaron por separado, a diferencia de las
ofertas en `PARITY-TRADE-EXCHANGE-001`. La diferencia es estructural: alli el
recorrido historico registraba **un solo paso** combinado; aca registra **dos
pasos numerados distintos** (3 y 8), separados por todo el bloque de comercio y
**cada uno con su propio opcode**.

**No** se congelaron: que la entrada sobreviva al ciclo (se **deduciria**, pero
deducir no es observar) ni que el nombre sea canonico (el codigo lo hace, la
evidencia no lo midio). Las dos quedan como **guardas vivas**, y las dos dieron
`true`.

### Tres intentos, dos fallos honestos

1. **Entorno, no fixture.** Observo los **tres** hechos del alta y despues el
   login del objetivo fue rechazado con `Server is currently closed.`: el
   servidor se estaba reiniciando, confirmado por marcas de tiempo del log
   (`10:30:07` rechazo, `10:37:43` arranque). Dejo residuo, porque la limpieza
   nunca llego a correr.
2. **Defecto mio, y util.** Mi reparacion de la linea base esperaba ver
   desaparecer la entrada, pero **la baja es silenciosa por diseno**: verificado
   que `removeVIP` no manda nada al cliente y que **no existe** opcode saliente
   de baja. Se reemplazo por una comprobacion **mas fuerte**: como `addVIP`
   rechaza duplicados **sin emitir entrada**, recibir una entrada fresca prueba
   por si solo que el objetivo no estaba ya en la lista.
3. **Exito.**

Al preparar el intento 2 aparecio ademas un falso positivo real: al conectarse,
el servidor manda las entradas **preexistentes** por la **misma senal** que una
nueva. Se cerro con una **puerta de medicion** que solo cuenta despues de pedir
el alta.

**La expectativa nunca se modifico**, verificado por hash en los tres intentos.

### Limpieza total, cero residuo

Verificado en persistencia: la lista del observador volvio a **`VIP = ()`**,
exactamente su estado original. **0 contactos ajenos tocados.** La baja se hizo
con el mecanismo de produccion y **no** es una asercion del fixture.

### Seguridad

**3 intentos completos de 3, 0 preflight. 0 cuentas creadas, 0 personajes
creados, 0 personajes del usuario, 0 mutaciones de progresion, 0 muertes, 0
combate, 0 monstruos, 0 `/killall`, 0 objetos creados o movidos, 1
`OBSERVATION_JSON`.** Los **9 hashes congelados** quedaron identicos.

## Conteos (`PARITY-VIP-PRESENCE-001`)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **14** (antes 13) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **14** (antes 13) |
| Observaciones `RECORDED_EVIDENCE` | — | **9** (antes 8) |
| Observaciones `LIVE_ORACLE` canonicas | — | **11** (antes 10) |
| `PARITY-VIP-PRESENCE-001` | — | **LIVE CERTIFIED, `PASS 5/5`** |

Phase 2 sigue **EN CURSO**.

**Le toca:** se audito cual evidencia historica queda sin convertir, contando
referencias reales desde `qa/parity/`, en vez de proponer un dominio de
memoria:

| Evidencia historica | Artefactos de paridad que la referencian |
|---|---:|
| `PRUEBA_VIVA_MUERTE_LOOT.md` | 8 |
| `PRUEBA_VIVA_TRADE_VIP.md` | 4 |
| `PRUEBA_VIVA_DEPOT.md` | 2 |
| `PRUEBA_VIVA_PARCEL.md` | 2 |
| `PRUEBA_VIVA_PARTY.md` | 2 |
| `PRUEBA_VIVA_REACQUISICION.md` | 2 |
| **`PRUEBA_VIVA_CASA_CAMA.md`** | **0** |

**`PRUEBA_VIVA_CASA_CAMA.md` es la unica evidencia historica sin convertir.**
Es el candidato natural: dominio de **casas y camas** —propiedad de casa,
dormir, y el ciclo de sesion asociado—, con evidencia propia ya existente. El
primer paso de ese turno debe ser la **auditoria linea por linea** de ese
documento, igual que aca, para decidir que califica como `RECORDED_EVIDENCE` y
que no.

Huecos declarados que **no** conviene tomar sin mas, todos **sin evidencia
historica**: los del dominio de comercio (AMBOS O NINGUNO ante fallo de
transferencia, borde de alcance, cancelacion implicita) y los del dominio de
contactos (capacidad, duplicado, baja, auto-agregado, persistencia entre
sesiones).

## Turno cerrado: Phase 2G.1 — Paridad de cancelacion de comercio

`PARITY-TRADE-CANCEL-001`: **CERTIFICADO EN VIVO**, replay **`PASS 7/7`**
byte-identico entre dos corridas. Detalle completo en
`docs/qa/PARITY_PHASE2G1_TRADE_CANCEL.md`.

Es el **negativo** de `PARITY-TRADE-EXCHANGE-001`, que quedo **byte-identico**
contra HEAD.

### Que certifica

Que una cancelacion **unilateral** de un comercio abierto (1) termina el
comercio para **los dos** participantes, no solo para el que cancelo, y (2)
**no mueve ningun objeto**.

### El control es lo que lo hace honesto

**"No se movio nada" es trivialmente cierto si el comercio nunca se abrio.**
Tambien se cumpliria si el alcance hubiera fallado o si el objeto hubiera sido
rechazado. Por eso se exige, **antes** de cancelar, que las dos sesiones hayan
recibido su oferta propia **y** la de la contraparte. Sin ese control este
fixture no probaria nada.

### La regla, verificada en el codigo

Entrante `0x80` -> `Game::playerCloseTrade` (`game.cpp:3204-3212`) ->
`internalCloseTrade` (`game.cpp:3214-3260`), que es **simetrico**: sobre el que
cancela **y** sobre su contraparte libera la reserva, dispara
`ON_TRADE_CANCEL`, resetea estado y manda aviso y cierre. **Alcanza con que uno
cancele** para cerrar a los dos, y **no mueve ningun objeto**: solo libera
reservas.

**Guarda que delimita el alcance:** la funcion **se niega a actuar** si alguno
esta en `TRADE_TRANSFER`. Es decir que en la cancelacion explicita **nunca hay
una transferencia en curso que revertir**, asi que este camino **no demuestra
nada sobre deshacer**. Certifica algo real y util, pero **distinto** de AMBOS O
NINGUNO ante un fallo de transferencia.

### Sin `RECORDED_EVIDENCE`, a proposito

Se busco en todo `docs/qa/` antes de decidir. La **unica** mencion de
cancelacion es `PRUEBA_VIVA_TRADE_VIP.md:70`, que dice que `Conexion772`
**expone** el metodo: es un hecho sobre **la API del cliente**, no una
observacion de comportamiento del servidor. **Ninguna corrida historica cancelo
un comercio abierto.** Fabricarla habria sido inventar evidencia.
`RECORDED_EVIDENCE` queda en **8**, igual que en Phase 2D.1 y 2D.2.

### Cero creacion y cero mutacion

`test_items_created = 0`. Los dos objetos que Phase 2G dejo **cruzados** como
residuo declarado se convirtieron aca en la **linea base ideal**: distinguibles
y sin duplicados. Y como una cancelacion correcta no transfiere, el entorno
quedo **exactamente como estaba**, verificado en los archivos persistidos: cada
participante con **1** unidad de lo suyo y **0** de lo del otro.

Es el unico fixture del corpus cuyo resultado correcto es **no cambiar nada**.

### El primer intento fallo por un defecto MIO, no del oracle

Se declara con precision porque el oracle hizo **exactamente** lo que el
fixture predice y aun asi la corrida dio `FAIL`: tras la cancelacion llegaron
`Trade cancelled.` a las dos sesiones, y mi guarda de "no debe haber cierre
previo" —mal ubicada al principio de la funcion, sin condicion— capturo el
cierre que producia **mi propia cancelacion exitosa**. Error de ordenamiento
del arnes, corregido moviendo la guarda adentro de la rama que corre una sola
vez antes de mandar la orden. El intento fallido **no dejo residuo**.

**La expectativa nunca se modifico**, verificado por hash en los dos intentos.

### Seguridad

**2 intentos completos de 3, 0 salidas de preflight. 0 muertes, 0 combate, 0
monstruos, 0 `/killall`, 0 objetos creados, 0 objetos movidos, 0 aceptaciones
enviadas, 0 objetos del usuario tocados, 1 `OBSERVATION_JSON`.** Los **8 hashes
congelados** quedaron identicos.

## Conteos (Phase 2G.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **13** (antes 12) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **13** (antes 12) |
| Observaciones `RECORDED_EVIDENCE` | — | **8** (sin cambio, a proposito) |
| Observaciones `LIVE_ORACLE` canonicas | — | **10** (antes 9) |
| `PARITY-TRADE-CANCEL-001` | — | **LIVE CERTIFIED, `PASS 7/7`** |

Phase 2 sigue **EN CURSO**.

**Le toca:** el dominio de comercio queda cerrado salvo huecos declarados. La
opcion mas fuerte disponible es **`PARITY-VIP-PRESENCE-001`**, que tiene
evidencia historica explicita en `PRUEBA_VIVA_TRADE_VIP.md` (alta por nombre
con GUID real, aparece offline, transicion online -> offline) y que quedo
deliberadamente **fuera** de los dos fixtures de comercio. Huecos declarados
del dominio de comercio, todos sin evidencia historica: **AMBOS O NINGUNO ante
un fallo de transferencia** (exige montaje destructivo y, como el servidor no
deshace, certificaria algo mas debil), borde del alcance de dos casillas,
cancelacion implicita por desconexion o por alejarse, y cancelacion despues de
que uno ya acepto.

## Turno cerrado: Phase 2G — Paridad de intercambio entre jugadores

`PARITY-TRADE-EXCHANGE-001`: **CERTIFICADO EN VIVO** al **primer** intento.
Replay grabado **`PASS 7/7`** y replay vivo **`PASS 7/7`**, los dos
byte-identicos entre corridas. Detalle completo en
`docs/qa/PARITY_PHASE2G_TRADE_EXCHANGE.md`.

**Sexto dominio de comportamiento.** El correo mueve un objeto en un solo
sentido y sin que el destinatario participe; el comercio es lo primero que
exige **dos voluntades concurrentes**: dos jugadores presentes, cada uno
viendo lo que ofrece el otro, y un cruce de propiedad que solo ocurre cuando
**los dos** aceptan.

### Lo que se afirma, y lo que deliberadamente NO

Se afirma el camino **exitoso**. **NO** se afirma atomicidad bajo fallo, es
decir **AMBOS O NINGUNO**, y el motivo sale del codigo, no de la cautela:
`Game::playerAcceptTrade` (`game.cpp:3024-3135`) **no tiene deshacer
transaccional**. Consigue la consistencia **probando en seco** con
`internalAddItem(..., test = true)` los dos destinos, y **solo si las dos
pruebas dan bien** ejecuta los movimientos reales; si algo falla despues, manda
cancelacion pero **no revierte**. Un exito observado desde el cliente **no
puede distinguir** un rollback real de una validacion previa afortunada.

Tampoco se afirma nada por cercania temporal de los paquetes: la evidencia
decisiva es el **estado final de propiedad**, no el orden de los mensajes.

### La regla, verificada en el codigo

- **Alcance:** `Position::areInRange<2, 2, 0>` — dos casillas por eje y **mismo
  piso**, sin tolerancia de `z`. Es **distinto** del `<30, 30, 1>` de party
  certificado en Phase 2D.1; conviene no confundirlos.
- `playerRequestTrade` valida contraparte distinta, linea de tiro, objeto
  `isPickupable()` sin `UNIQUEID`, coincidencia de client id, y rechaza objetos
  ya reservados en otro comercio **en los dos sentidos de anidamiento**.
- `internalStartTrade` emite las ofertas de forma **asimetrica en el tiempo**:
  el primer oferente solo ve la suya y la contraparte recibe un aviso; la
  oferta cruzada aparece **recien cuando el segundo ofrece**. Se confirmo en
  vivo.
- `internalCloseTrade` no hace nada si alguno esta en `TRADE_TRANSFER`: no se
  puede cancelar en mitad de la transferencia.
- **El grupo del jugador no interviene** en ninguna funcion de comercio. Aun
  asi se usaron **dos jugadores normales**, con el operador **fuera**, para que
  no quede duda de que un privilegio influyo.

### Opcodes: el mismo numero, significados opuestos por direccion

`0x7D` entrante es *solicitar*, saliente es *mi oferta*. `0x7E` entrante es
*mirar*, saliente es *oferta de la contraparte*. **`0x7F` entrante es
*aceptar*, saliente es *cerrar*.** Quedan documentados como metadata de origen
y **ninguno entra al payload**.

### Deuda historica saldada: transporte de produccion

La evidencia historica decia que `Conexion772` no exponia la solicitud inicial
y que QA armaba el payload a mano. **Ya no es cierto**: hoy se publican
`enviar_solicitar_comercio` y `enviar_solicitar_comercio_inventario`, y este
adaptador usa el **metodo de produccion** sin duplicar el formato del paquete
dentro de QA.

### Siete aserciones, no ocho — y por que

Era tentador partir `ambos clientes reciben oferta propia y contraparte` en
**cuatro** vistas y llegar a ocho. **No se hizo.** El documento historico
registra **un solo assert combinado**; partirlo seria **fabricar granularidad**
que la corrida historica no midio por separado. El hecho combinado tiene la
misma fuerza de deteccion y no inventa precision que no existio. El adaptador
vivo **si** distingue las cuatro vistas y aborta si falta alguna: queda como
guarda viva.

### VIP, excluido a proposito

La evidencia historica mezcla VIP y comercio en un mismo archivo. **Ningun**
hecho de VIP entra al fixture. Merece el suyo propio,
`PARITY-VIP-PRESENCE-001`, no un anexo del contrato del comercio.

### Objetos de prueba, y por que no se reusaron

Los dos participantes tienen **exactamente el mismo juego** de objetos
iniciales, asi que reusarlos habria dejado la propiedad **ambigua**. Se crearon
**2** objetos frescos de tipos distintos que **ninguno** de los dos poseia,
verificados contra los datos del oracle: movibles, no apilables, no
contenedores, sin cargas y **sin `duration` ni `decayto`**.

**No se desplazo ningun equipo ajeno.** El arnes historico "normalizaba las
manos" vaciando ranuras; este usa ranuras que los dos tenian **vacias**, y si
alguna no lo estuviera devuelve `BLOCKED` en vez de mover algo del personaje.
Tampoco se uso el comercio para aprovisionar: seria usar el mecanismo que se
esta midiendo.

### Corroboracion independiente en la persistencia

Con **los dos participantes ya desconectados**, leido fuera del camino del
cliente: cada uno quedo con el objeto **del otro** equipado y **cero** unidades
del propio. El cruce es exacto en las dos direcciones y **sobrevive al cierre
de sesion**.

### Seguridad y residuo

**0 muertes, 0 combate, 0 monstruos, 0 `/killall`, 0 objetos del usuario
tocados, 0 equipo preexistente desplazado, 0 cuentas o personajes creados, 0
credenciales cambiadas, 1 `OBSERVATION_JSON`, 0 salidas de preflight, 1 intento
vivo de 3.** Los **9 hashes congelados** quedaron identicos.

**Residuo declarado:** los dos objetos frescos quedan con los participantes de
QA, cruzados. Es el resultado del fixture. **No** se hizo comercio inverso de
limpieza: correspondia solo si se hubieran reusado objetos preexistentes.

## Conteos (Phase 2G)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **12** (antes 11) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **12** (antes 11) |
| Observaciones `RECORDED_EVIDENCE` | — | **8** (antes 7) |
| Observaciones `LIVE_ORACLE` canonicas | — | **9** (antes 8) |
| `PARITY-TRADE-EXCHANGE-001` | — | **LIVE CERTIFIED, `PASS 7/7`** |

Phase 2 sigue **EN CURSO**.

**Le toca:** evaluado contra el codigo, **Phase 2G.1 solo con la cancelacion
explicita**. `internalCloseTrade` es un camino normal y observable —un
participante cancela, los dos reciben el aviso, las dos ventanas cierran y
ningun objeto cambia de dueno— y da un fixture negativo honesto sin montaje
artificial. El **fallo de transferencia real** queda como **hueco declarado**:
forzarlo exige llenar el inventario de un personaje de QA, y como el servidor
**no deshace**, lo que se certificaria es que la validacion previa evita el
estado inconsistente, que es una afirmacion mas debil y distinta de
"rollback". Alternativa de igual valor y menor riesgo:
`PARITY-VIP-PRESENCE-001`, con evidencia historica fuerte ya disponible.

## Turno cerrado: Phase 2F — Paridad de entrega de correo

`PARITY-PARCEL-DELIVERY-001`: **CERTIFICADO EN VIVO**. Replay grabado
**`PASS 6/6`** y replay vivo **`PASS 6/6`**, los dos byte-identicos entre
corridas. Detalle completo en
`docs/qa/PARITY_PHASE2F_PARCEL_DELIVERY.md`.

**Quinto dominio de comportamiento.** La ventana de texto, el contenedor y la
persistencia del deposito son mecanismos de apoyo ya cubiertos; lo nuevo es el
**ruteo autoritativo de correo**: que el servidor **lea una direccion escrita
por un jugador y lleve el objeto hasta el deposito de OTRO jugador**, incluso
si ese otro **no esta conectado**. Es la primera vez que el corpus mide una
decision de ruteo entre dos identidades.

### La regla, verificada en el codigo, no supuesta

- **`Mailbox::getReceiver`** busca dentro del contenedor un item con id de
  etiqueta y parte su texto **POR LINEAS**: linea 1 destinatario, linea 2
  **nombre del pueblo**. No es "nombre / pueblo" en una sola linea; con una
  sola linea el pueblo queda vacio y el envio falla en silencio.
- **`Mailbox::sendItem`** resuelve el pueblo **por nombre** (`strcasecmp`),
  entrega al deposito **del pueblo direccionado**, y transforma la encomienda
  con `getID() + 1`, asi que lo que llega es la **sellada**. El destino del
  movimiento es el **locker**, no el cofre: la entregada queda **hermana** del
  cofre, y por eso la medicion se hace al nivel del locker.
- Con el destinatario **offline**, arma un `Player` temporal, lo carga por
  nombre, inserta y **vuelve a guardar su archivo**.
- **`sendItem` no consulta NADA del remitente**: ni grupo ni permisos. Eso es
  lo que autoriza usar al operador como remitente sin cambiar la semantica.
- **`trashableMailbox` esta en `true`**, asi que el residuo historico de la
  casilla **no** bloquea el envio. Se verifico antes de disenar la corrida.
- **El arreglo historico del servidor sigue puesto**: la guarda de `game.cpp`
  conserva `&& !useItemType.canReadText`. Si hubiera regresado, `BLOCKED`: QA
  no repara el oracle para poder certificarlo.

### Seis aserciones, auditadas linea por linea

Se congelaron **seis**, una por hecho que `PRUEBA_VIVA_PARCEL.md` demuestra de
forma explicita. Cinco son lineas de salida del arnes historico; la sexta, la
entrega en el deposito, es una **confirmacion del usuario sobre el recorrido
vivo** corroborada por los datos persistidos, y se dice asi de claro para que
un revisor sepa que clase de evidencia sostiene cada una.

### La corrida viva probo mas de lo que el fixture afirma

Remitente distinto del destinatario, cuentas distintas, destinatario
**desconectado** durante el envio, sesion nueva despues, deposito **+1** contra
linea base, deposito personal identificado en las dos sesiones, casilla del
buzon medida contra linea base, y la encomienda entregada **con la etiqueta
adentro**. **Ninguna de esas entro al payload**: son guardas del arnes, y que
la prueba nueva sea mejor no convierte esos hechos en historia.

### Corroboracion independiente con el destinatario desconectado

Leido fuera del camino del cliente, despues del despacho y **antes** de su
regreso: el archivo del destinatario ya tenia la encomienda **sellada** con la
etiqueta adentro y la direccion en **dos lineas**. Prueba de una sola vez que
el servidor persistio el ruteo antes del regreso, que transformo el item, y que
el formato de dos lineas es el real.

### Tres lanzamientos, clasificados con honestidad

1. **Salida de preflight.** El destinatario **no podia desconectarse**: un
   `CONDITION_POISON` **persistido** refrescaba `CONDITION_INFIGHT`, y
   `ProtocolGame::logout` rechaza el logout con signo de batalla **aunque se
   este en zona de proteccion**. Se resolvio **eligiendo otro personaje de QA**
   sin condiciones persistidas. **No se toco el servidor.**
2. **Intento completo 1 de 3.** El operador lleva un **arma de dos manos**, asi
   que no hay mano libre. Desequiparla habria sido tocar equipo que este turno
   no debe modificar; la encomienda pasa a apoyarse en el **suelo**.
3. **Intento completo 2 de 3: exito.**

**Intentos completos usados: 2 de 3.** La expectativa **nunca se modifico**,
verificado por hash en los tres lanzamientos.

### Residuos declarados

**No se ejecuto ninguna limpieza**, y `/limpiarpruebas` **no se uso**: no se
emplea una herramienta de limpieza sin poder demostrar que su alcance se limita
exactamente a lo que esta corrida creo.

1. La **encomienda entregada** en el deposito del destinatario de QA: es el
   resultado del fixture.
2. **Una encomienda vacia** en la mochila del operador, del intento fallido.
3. **Un cofre de deposito vacio**, creado por el propio servidor, igual que en
   Phase 2E.

### Seguridad

**0 muertes, 0 ataques, 0 monstruos, 0 `/killall`, 0 objetos del usuario
tocados, 0 equipo modificado, 0 cuentas o personajes creados, 0 cambios de
credenciales, 1 `OBSERVATION_JSON`.** Los **9 hashes congelados** quedaron
identicos despues de la corrida, del wrap y de los cuatro replays.

## Solicitud abierta para el carril `servidor`

**`LOGOUT_INMEDIATO_EN_ZONA_DE_PROTECCION`: registrada, NO implementada.**

El usuario pidio que un personaje pueda desconectarse de inmediato dentro de
una zona de proteccion. Este turno **no toco `servidor/`**.

- La guarda vive en `ProtocolGame::logout`
  (`servidor/src/protocolgame.cpp:311-322`): rechaza el logout con
  `CONDITION_INFIGHT` **sin** consultar la zona; solo `isAccessPlayer()` exime.
- Es el comportamiento de TFS y del Tibia original, asi que quitarlo es una
  **divergencia deliberada respecto de 7.72**, no una correccion de defecto.
  Conviene declararlo como tal para que no se lea despues como paridad.
- Cambio minimo sugerido: permitir el logout cuando el jugador esta en
  `ZONE_PROTECTION`, dejando intacta la guarda fuera de ella.
- **Impacto sobre el corpus: ninguno.** Ningun fixture actual afirma nada sobre
  el logout en combate, asi que no invalida ninguna certificacion.

## Conteos (Phase 2F)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **11** (antes 10) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **11** (antes 10) |
| Observaciones `RECORDED_EVIDENCE` | — | **7** (antes 6) |
| Observaciones `LIVE_ORACLE` canonicas | — | **8** (antes 7) |
| `PARITY-PARCEL-DELIVERY-001` | — | **LIVE CERTIFIED, `PASS 6/6`** |

Phase 2 sigue **EN CURSO**.

**Le toca:** **Phase 2G — paridad de intercambio atomico (trade)**, usando
`docs/qa/PRUEBA_VIVA_TRADE_VIP.md` pero eligiendo **trade** como dominio
semantico primario: dos jugadores presentan ofertas, cada uno observa la propia
y la de la contraparte, los dos aceptan, el servidor transfiere **de forma
atomica** los dos objetos autoritativos, y las dos ventanas se cierran de forma
consistente. Las transiciones de presencia de VIP convienen como **fixture
aparte**, no mezcladas en el contrato semantico del trade.

## Turno cerrado: Phase 2E — Paridad de persistencia del deposito

`PARITY-DEPOT-PERSISTENCE-001`: **CERTIFICADO EN VIVO**. Replay grabado
**`PASS 10/10`** y replay vivo **`PASS 10/10`**, los dos byte-identicos entre
corridas. Detalle completo en
`docs/qa/PARITY_PHASE2E_DEPOT_PERSISTENCE.md`.

**Cuarto dominio de comportamiento** del corpus, y el primero que **cruza una
frontera de sesion**: los tres anteriores miden cosas que pasan dentro de una
sesion; este prueba que **el servidor guarda estado de jugador y lo devuelve
intacto en una sesion nueva**.

### La regla, verificada en el codigo, no supuesta

- **Activacion por ENTRADA.** `data/scripts/movements/other/tiles.lua` carga el
  deposito en `onStepIn`, solo en zona de proteccion y con un item de tipo
  depot en el 3x3. **No se dispara si el personaje ya estaba parado ahi**, y el
  `onStepOut` correspondiente llama `unloadDepotLocker`, asi que salir
  **desactiva de verdad**.
- **Deposito personal contra mueble del mapa.** `actions.cpp:221-234`: sin
  `currentDepotItem` puesto, el servidor abre **el mueble del mapa como
  contenedor comun**, que se ve igual y **tambien acepta objetos**. Es la
  trampa del dominio y por eso "se abrio un contenedor" **no se acepta** como
  prueba.
- **Persistencia por jugador.** `iologindata.cpp:767-784` serializa el deposito
  **dentro del archivo del propio jugador** (`Depot = (<id>, {...})`) y
  `467-495` lo reconstruye al leerlo.
- **El god no cambia la semantica.** Lo unico que depende del grupo es la
  capacidad, y `groups.xml` la tiene en 0 para **todos**, asi que todos caen al
  limite de `config.lua`. Por eso el sujeto es un **personaje normal** de QA y
  el operador solo lo posiciona.

### Como se cierra la trampa

Se exigen **dos** senales externas e independientes, ninguna de estado interno:
el aviso autoritativo `"Your depot contains ..."`, que sale dentro de la
**misma rama** que llama a `loadDepotLocker`, y que al abrir el mueble aparezca
adentro el **cofre de deposito**, que solo se crea sobre el locker personal.

La frontera de sesion tampoco se simula: logout legacy, socket cerrado, y
recien entonces conexion de login y de juego **nuevas** con su propio
`EstadoMundo`. Y como el personaje queda parado sobre la baldosa al
desconectarse, en la sesion nueva **sale y vuelve a entrar**.

### Diez aserciones, no once — y por que

La propuesta traia **once**. Se congelaron **diez**. La que se saco es
`source_test_item_count_decreased_by_one`: la evidencia historica
**no la demuestra**, porque `PRUEBA_VIVA_DEPOT.md` solo midio y publico la
cuenta del cofre. Como el `QACase` se replaya contra **las dos** observaciones
con el **mismo** juego congelado, incluirla habria obligado a fabricar un hecho
grabado que nadie observo. La captura viva **si** comprueba que el objeto salio
de su origen, pero como **guarda del harness**, no como asercion congelada.

### Objeto de prueba: se reuso, no se creo

`test_items_created = 0`. El sujeto ya tenia un objeto **entero** (no apilable,
no contenedor, movible, restituible). Se descarto el otro candidato del equipo
inicial por ser **apilable**: el servidor puede partir o juntar pilas y eso
mediria otra cosa. **Delta neto de inventario: 0** — el objeto volvio a su
ranura original, verificado en el archivo persistido.

### Los tres lanzamientos, sin maquillaje

Se lanzaron **tres** corridas. Las dos primeras murieron en el
**posicionamiento**, antes de tocar el deposito y antes de cualquier medicion:
son **salidas de preflight**, no intentos de oracle completados, y cada una
encontro un defecto real del harness.

1. El operador seguia parado en la casilla de salida.
2. **La casilla de salida historica no es caminable para un personaje normal.**
   Es el mismo tropiezo que Phase 2C.1 ya habia documentado: **aislado no es lo
   mismo que habitable**. La evidencia historica llegaba ahi con `/gotopos` de
   un god, que teletransporta a cualquier lado. Ahora la casilla de salida se
   **descubre empiricamente** entre las vecinas.

**La expectativa NUNCA se modifico**, verificado por hash: fixture, `QACase` y
observacion grabada byte-identicos antes del primer lanzamiento y despues del
tercero. Lo unico que cambio fue el adaptador, recongelado cada vez.

### Corroboracion independiente desde el archivo de persistencia

Leido **fuera** del camino del cliente, con la primera sesion ya cerrada y la
segunda todavia inexistente: `Depot = (1, {2594 Content={2382}})`, es decir el
cofre de deposito conteniendo el objeto, mientras el equipo del sujeto ya no lo
tenia. Es **evidencia de apoyo documental**: no se agrego ningun campo al
fixture por esto y no se congelo ninguna forma de archivo.

### Residuo declarado

El deposito del sujeto queda con un **cofre vacio** que antes no existia. No lo
creo QA: lo crea el servidor al abrir por primera vez un deposito personal
cargado. Es el estado normal de cualquier jugador que haya abierto su deposito
una vez, es solo del sujeto de QA, y no se intento borrarlo porque no hay
mecanismo probado y inventar uno seria peor que declararlo.

### Seguridad

**0 muertes, 0 ataques, 0 monstruos invocados, 0 `/killall`, 0 objetos creados,
0 objetos del usuario tocados, 0 cuentas o personajes creados, 0 cambios de
credenciales, 1 `OBSERVATION_JSON`.** Los **8 hashes congelados** quedaron
identicos despues de la corrida, del wrap y de los cuatro replays.

## Conteos (Phase 2E)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **10** (antes 9) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **10** (antes 9) |
| Observaciones `RECORDED_EVIDENCE` | — | **6** (antes 5) |
| Observaciones `LIVE_ORACLE` canonicas | — | **7** (antes 6) |
| `PARITY-DEPOT-PERSISTENCE-001` | — | **LIVE CERTIFIED, `PASS 10/10`** |

Phase 2 sigue **EN CURSO**.

**Le toca:** **Phase 2F — paridad de entrega por correo / parcel**, usando
`docs/qa/PRUEBA_VIVA_PARCEL.md` para congelar el recorrido distinto de punta a
punta: etiqueta de destino escrita, la parcel entra al mailbox, sale del mundo
y del inventario del remitente, el servidor la rutea por pueblo y el deposito
del destinatario la recibe de forma persistente. Es la otra mitad del bloque
que este turno deja abierta a proposito.

## Turno cerrado: Higiene de credenciales legacy + inspeccion del estado del juego

Turno de **dos partes**, sin fixture de paridad nuevo, sin implementacion de
Architecture V2 y sin Phase 3. **Inventarios de paridad sin cambio.**

| Resultado | Valor |
|---|---|
| `LEGACY_LIVE_TEST_CREDENTIAL_HYGIENE` | **PASS** |
| `CURRENT_GAME_STATE_SMOKE` | **PASS** |
| Clasificacion de jugabilidad | **`PLAYABLE_WITH_MINOR_DEFECTS`** |

Informe completo del estado del juego en
`docs/qa/CURRENT_GAME_STATE_2026-09-12.md`, con cuatro capturas de la ventana
real en `docs/qa/capturas/`.

### A. Higiene de credenciales

La deuda declarada en Phase 2D.1.1 queda **saldada**. Se verifico de forma
independiente el conteo previo: **20** scripts de prueba viva legacy traian el
identificador numerico de login y la contrasena como constantes literales en
codigo versionado. Los 20 quedaron migrados a `OS.get_environment(...)`.

**Un archivo mas que la auditoria previa no habia encontrado.**
`prueba_muerte_reentrada.gd` guardaba el **numero de cuenta real** en una
prueba **offline** que usa conexion falsa y nunca autentica nada. Ahi no
correspondia `BLOCKED` por entorno —romperia una prueba determinista de la
matriz local— asi que se reemplazo por una identidad de **relleno** explicita,
documentada en el propio archivo. La clave que ya tenia (`clave-de-prueba`) era
un placeholder y no se toco.

Se creo **un** helper QA-owned, `cliente3d/pruebas/credenciales_qa.gd`, para no
duplicar veinte veces la misma validacion. Vive en `cliente3d/pruebas/` a
proposito y **no** en `cliente3d/red/`, que es de `protocolo-red`.

**Falla cerrada, y probado que falla cerrada.** Sin la variable requerida, la
prueba imprime `BLOCKED missing environment variable <NOMBRE>`, sale con codigo
**2** y **no abre ningun socket** (verificado: 0 lineas de conexion en el log).
Nunca hay vuelta silenciosa al literal anterior.

Nombres de personaje tambien migrados a entorno, porque eran configuracion de
identidad y no datos de juego: el operador (`TVP772_GOD_CHARACTER`), el
personaje normal (`TVP772_PLAYER_CHARACTER`) y un rol propio y descriptivo
(`TVP772_LIFE_RING_CHARACTER`) para la unica prueba que exige un personaje con
un item concreto en el inventario. **No** se tocaron nombres de monstruo, NPC,
pueblo ni item: eso es dato de juego.

`TVP772_HOST` y `TVP772_LOGIN_PORT` quedaron **opcionales con el mismo
defecto de siempre** (`127.0.0.1`, `7171`), asi que sin definirlas el
comportamiento es identico al anterior. No son credenciales.

| Verificacion | Resultado |
|---|---:|
| Scripts afectados antes | **20** |
| Scripts afectados despues | **0** |
| Identificadores de login literales reales en fuente QA ejecutable | **0** |
| Contrasenas literales reales en fuente QA ejecutable | **0** |
| Scripts que parsean (`--check-only`) | **21 / 21** |
| Matriz QA local | **18 / 18 OK** |
| Mutaciones de credenciales | **0** |
| Cuentas/personajes creados | **0** |
| Artefactos de paridad modificados | **0** |

La unica coincidencia que queda en el escaneo es un **falso positivo**
declarado: `test_voz_proximidad.gd:27` usa un id de criatura en hexadecimal
(`0x…`) cuyos digitos contienen por casualidad los de la contrasena. No es una
credencial.

### B. Estado actual del juego

**Servidor `RUNNING`.** Arranque canonico verificado leyendo el repositorio, no
suponiendo: Docker Compose en `servidor/`. **Ya estaba corriendo, asi que no se
reinicio**, no se reconstruyo imagen, no se borro volumen, no se toco la base y
no se cambio configuracion para hacerlo arrancar. **7171 y 7172 escuchan y
aceptan conexion.** Mapa 65000x65000 cargado, 23063 monstruos, 336 NPCs. **0**
errores fatales, **0** crash loop, **0** migraciones destructivas, **0** errores
durante la sesion.

**Cliente abierto con ventana real, no headless.** Punto de entrada normal
(`main.tscn`, el mismo de `JUGAR.bat`), ventana `TVP3D (DEBUG)` con
renderizador OpenGL sobre GPU real. **Inspeccion visual: SI.**

Entro un personaje **dedicado de QA**; **0** personajes del usuario usados y
**0** credenciales cambiadas para lograrlo.

Funciona: login, carga del mundo, terreno, edificios, agua, escaleras, items,
criaturas con nombre y vida, movimiento, cambio de piso `z=7 <-> z=8`, camara
que sigue al jugador, minimapa, lista de batalla, panel de objetivo,
inventario, chat y mensajes autoritativos del servidor.

**Coherencia cliente/servidor probada fuera del camino del cliente:** al cerrar
sesion el servidor persistio exactamente la misma posicion que mostraba el HUD.

**0** errores de runtime en el cliente (stderr vacio), **0** advertencias del
parser, **0** errores del servidor.

### Defectos encontrados, registrados y NO corregidos

Son de otros carriles. Este turno **no** los toca; quedan como solicitudes.

| # | Defecto | Carril |
|---|---|---|
| 1 | Items sin perfil 3D: el cliente los dibuja con su placeholder magenta `__unmapped_item__` (`mundo3d.gd:3682-3690`) y los cuenta en el HUD (`unmapped 3` en una zona) | `assets` / `editor` |
| 2 | `Speed`, `Food` y `Stamina` muestran 0 siempre: el `0xA0` de 7.72 trae once campos y **ninguno** es stamina, comida ni velocidad (`estado_mundo.gd:636-652`), pero la UI pinta esas filas (`interfaz.gd:1296-1299`). Probado: el personaje tiene `Stamina = 2530` y la UI dice `0%` | `cliente` |
| 3 | `ARRANCAR SERVIDOR.bat` y `web/LEEME.md` publican **en texto plano** la cuenta y la clave de desarrollo, en archivos versionados. Es el mismo problema que este turno resolvio dentro de `cliente3d/pruebas/`, pero fuera de este carril | `integracion` |

### Dicho sin adornos

**El usuario estuvo jugando en la misma ventana durante la inspeccion**
(combate, uso de objetos, movimiento propio). Por eso la muestra de movimiento
**no** se puede atribuir limpiamente a las teclas enviadas por QA, y no se
afirma haber medido un paso aislado. Lo que si queda probado, y no depende de
quien apreto la tecla, es que la posicion cambia de forma coherente, que el
cambio de piso funciona y que la posicion final del cliente **coincide exacto**
con la que persistio el servidor.

La sesion fue **una sola y corta**, en Thais y sus cuevas. No es una
certificacion de jugabilidad ni un barrido del mundo, y **nada de lo observado
se convierte en evidencia de paridad**.

## Conteos (sin cambio de inventarios)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 9 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 9 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 5 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 6 (sin cambio) |
| `LEGACY_LIVE_TEST_CREDENTIAL_HYGIENE` | — | **PASS** |
| `CURRENT_GAME_STATE_SMOKE` | — | **PASS / `PLAYABLE_WITH_MINOR_DEFECTS`** |
| Capturas de oracle en este turno | — | **0** |

Phase 2 sigue **EN CURSO**.

**Le toca:** el juego llega a mejor que `BASIC_PLAYABLE`, asi que corresponde
**Phase 2E — paridad de persistencia de depot**. Antes no hace falta ninguna
investigacion de carril bloqueante: los tres defectos de arriba son de
cobertura y de presentacion, ninguno impide jugar.

## Turno cerrado: Phase 2D.2 — Paridad de NIVEL de experiencia compartida

`PARITY-PARTY-SHARED-EXP-LEVEL-001`: **CERTIFICADO EN VIVO**, replay
**`PASS 8/8`** al **primer** intento. Detalle completo en
`docs/qa/PARITY_PHASE2D2_PARTY_SHARED_EXP_LEVEL.md`.

Segundo fixture **negativo** del dominio y **ultimo hueco declarado** de la
experiencia compartida. Los tres fixtures previos quedaron **byte-identicos**
contra HEAD: `PARITY-PARTY-SHARED-EXP-001`,
`PARITY-PARTY-SHARED-EXP-RANGE-001` y `PARITY-PARTY-LIFECYCLE-001`, con sus
fixtures, `QACase`, observaciones, reportes y adaptadores sin tocar.

### La regla, verificada en el codigo, no supuesta

`Party::canUseSharedExperience` (`party.cpp:344-354`) toma el **maximo** nivel
de la party y exige

```
minLevel = static_cast<uint32_t>(std::ceil((static_cast<float>(highestLevel) * 2) / 3))
```

con comparacion **estricta** (`level < minLevel` rechaza). Es `ceil` sobre punto
flotante, **no** division entera: con nivel mas alto 25 el minimo es **17**, no
16. Y `canEnableSharedExperience` (`party.cpp:374-386`) lo exige para el lider
**y** para cada miembro, asi que **uno** solo inelegible apaga el reparto
entero.

### No se provisiono nada, y eso fue lo correcto

El usuario autorizo **explicitamente** crear cuentas y personajes de QA
dedicados. **No hizo falta**, asi que no se creo ninguno:

- `QA_LEVEL_HIGH`: participante de QA de nivel 25 ya existente, en una cuenta
  que contiene solo personajes de QA.
- `QA_LEVEL_LOW`: personaje de QA ya existente que **nunca habia entrado al
  mundo**. Sin archivo propio bajo `servidor/gamedata/players/`, el servidor lo
  carga desde `male.dat` (`iologindata.cpp:208-236`), que es literalmente el
  estado de creacion del perfil: **nivel 1**, 150 de vida, stamina 2530,
  habilidades 10. Crear uno nuevo habria dado **exactamente** ese mismo estado.

Se verifico ademas que su **stamina > 0**: `Player::gainExperience`
(`player.cpp:3292-3298`) devuelve temprano con `staminaMinutes == 0`, asi que un
participante sin stamina no habria ganado experiencia **por un motivo distinto
del nivel** y habria contaminado el fixture entero. La fila de la base decia
`stamina = 0` y era irrelevante: el estado autoritativo vive en los archivos
`.tvpp`, no en esa columna.

La relacion `1 < 17` es **natural**. **0** mutaciones de nivel, **0**
`/addSkill`, **0** ediciones de base, **0** cambios de credenciales, **0**
personajes del usuario tocados.

### El aislamiento y la corroboracion fuerte

El rango deja de ser variable y pasa a ser **control**: los dos participantes se
quedan en el **mismo** punto operativo toda la corrida. La participacion de los
dos se prueba de forma autoritativa con su **ganancia individual** contra el
primer monstruo, porque solo cobra quien figura en el `damageMap` con dano
positivo y ese mismo evento es el que escribe `ticksMap` (`player.cpp:3227`).

La prueba decisiva es la **magnitud**: por el segundo monstruo, atacado solo por
el participante alto, cobro **+10**, su experiencia base **completa sin
dividir**. Si el reparto siguiera habilitado excluyendo al bajo, habria cobrado
`ceil(10 * 1.20 / 2) = 6`. Y en el primer monstruo los dos cobraron **+7 y +2**,
sumando 9: bajo reparto habrian sido 6 y 6, sumando 12, **imposible** porque el
pago individual nunca supera la experiencia base.

### Corroboracion independiente del archivo persistido

| Magnitud | `QA_LEVEL_HIGH` | `QA_LEVEL_LOW` |
|---|---:|---:|
| Nivel | 25 -> 25 (**0**) | 1 -> 1 (**0**) |
| Punos / garrote | 46 / 11 sin cambio | 10 / 10 sin cambio |
| Experiencia | 204824 -> 204841 (**+17**) | 0 -> 2 (**+2**) |
| Vida | 172 -> 156 | 150 -> 150 (**0 de dano**) |

El personaje de nivel 1 termino con **exactamente la misma vida** con la que
entro: el diseño de dos monstruos y la eleccion de especie (la mas debil del
bestiario con experiencia > 0) hicieron que no recibiera **ni un punto** de
dano. No hubo que curarlo de ninguna forma.

### Efecto declarado sobre la identidad de QA

El participante bajo **ya no esta virgen**: ahora tiene archivo propio con **+2
de experiencia** legitimos por pelear. Sigue en **nivel 1** (subir a 2 exige
100), asi que sigue sirviendo. Queda **persistido a proposito** como
infraestructura de QA reutilizable; no se borro para dejar la base prolija.

### Alcance, dicho sin adornos

Prueba la **supresion por nivel insuficiente**. **NO** certifica el borde del
umbral (`minLevel` exacto contra `minLevel - 1`), porque el participante bajo
esta muy por debajo y no lo roza. Tampoco afirma `sharedExpEnabled` leyendo
estado interno. Se observo ademas que el mensaje generico del legacy dice
"inactive" aunque la causa real sea el nivel: **no distingue** cual de los
cuatro requisitos fallo, por eso no se congela.

### Imprecision declarada, no corregida a escondidas

El encabezado del adaptador cita `canEnableSharedExperience` como
`party.cpp:333` cuando la linea correcta es **374**. Es un comentario, no
logica. **No se corrigio** porque el archivo se congelo antes de la corrida y
editarlo ahora romperia lo unico que el congelamiento garantiza: que lo
commiteado sea byte a byte lo que produjo la observacion.

### Seguridad

**1 intento vivo de 3. 0 muertes de jugador. 2 monstruos invocados (el maximo).
0 muertes colaterales. 0 usos de `/killall`. 0 dano del god. 0 mutaciones de
progresion. 1 `OBSERVATION_JSON`.** La verificacion de la guarda de credenciales
corto con codigo 2 **sin contactar al servidor** y no cuenta como intento vivo.

Los **7 hashes congelados** antes de la corrida quedaron **identicos** despues
del wrap y de los dos replays. `replay.py` y `wrap_live_observation.py` **no se
modificaron**: aceptaron un **quinto** dominio de comportamiento sin cambios.

### Sin evidencia grabada, a proposito

Se busco antes de decidir. Las corridas historicas de Phase 2D mantuvieron a los
dos participantes en el **mismo nivel** justamente para no romper esta regla
(`PARITY_PHASE2D_PARTY_SHARED_EXP.md:269`), y tanto ese documento (146-149) como
el de Phase 2D.1 (580-583) declaran la regla de nivel como **no afirmada**.
Ninguna corrida historica midio experiencia con un participante por debajo del
minimo. `RECORDED_EVIDENCE` queda en **5**.

## Autorizaciones vigentes del proyecto

| Regla | Valor |
|---|---|
| `QA_TEST_IDENTITY_PROVISIONING` | **`AUTHORIZED_WHEN_REQUIRED`** — un agente de QA **puede crear** cuentas y personajes de QA dedicados cuando una prueba de paridad los necesite de verdad, con los valores por defecto de creacion normal. Nunca para fabricar el resultado esperado manipulando progresion. Los identificadores y credenciales **no se versionan**; solo se documenta el **rol** |
| `EXISTING_CREDENTIAL_MUTATION` | **`DO_NOT_PERFORM_MERELY_TO_UNBLOCK_CAPTURE`** — si falta o no sirve una credencial, el resultado correcto es `BLOCKED` pidiendo configuracion valida, o **crear una identidad de QA nueva**. Cambiar la credencial de una cuenta existente exige justificacion propia y autorizacion explicita |
| `USER_ACCOUNTS_AND_CHARACTERS` | **`DO_NOT_MODIFY`** — ninguna cuenta que contenga personajes del usuario, y ningun personaje del usuario, se toca por ningun motivo |
| `LIVE_CAPTURE_CREDENTIAL_MUTATION` | **`REQUIRES_EXPLICIT_USER_AUTHORIZATION`** (sin cambio desde Phase 2D.1.1) |
| `NO_ADMIN_PROGRESSION_MUTATIONS` | `/addSkill`, nivel, habilidades, magia, vocacion, vida, mana y experiencia: **prohibidos** en capturas de paridad. Crear un personaje con los defaults normales **no** es una mutacion de progresion: es provisionamiento |

## Conteos (Phase 2D.2)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **9** (antes 8) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **9** (antes 8) |
| Observaciones `RECORDED_EVIDENCE` | — | **5** (sin cambio, a proposito) |
| Observaciones `LIVE_ORACLE` canonicas | — | **6** (antes 5) |
| `PARITY-PARTY-SHARED-EXP-LEVEL-001` | — | **LIVE CERTIFIED, `PASS 8/8`** |
| Cuentas/personajes de QA creados en este turno | — | **0** |

Phase 2 sigue **EN CURSO**: este turno amplia el corpus de oracle, no lo cierra.

**Le toca:** con los tres requisitos observables de
`Party::canUseSharedExperience` ya certificados por separado (actividad, rango y
nivel), el dominio de experiencia compartida queda **cerrado salvo bordes**. Lo
que queda declarado y sin certificar: los dos **bordes** (30 contra 31 casillas;
`minLevel` exacto contra `minLevel - 1`) y la participacion por **curacion a un
companero** (`player.cpp:3247`), que el codigo documenta y ninguna corrida
ejercito. Alternativa de mayor valor: abrir un **cuarto dominio** de paridad.
Aparte, como linea propia, sigue abierta la deuda de sacar las credenciales
literales de los 20 scripts de prueba viva legacy de `cliente3d/pruebas/`.

## Turno cerrado: Phase 2D.1.1 — Higiene de identificadores de autenticacion

Turno de **higiene de documentacion y gobernanza**. Sin TVP en vivo, sin
gameplay en Docker, sin captura de oracle, sin cambio de semantica de paridad.

`PARITY-PARTY-SHARED-EXP-RANGE-001` **sigue certificado y valido**
(commit `5ac123e`, `PASS 8/8`). Su fixture, `QACase`, observacion
`LIVE_ORACLE`, reporte de replay y adaptador quedan **byte-identicos**.

### Que se encontro y que se redacto

El identificador numerico de login de 7.72 es parte del juego de credenciales
de autenticacion y no debe publicarse literal en documentacion operativa
versionada.

Ocurrencias en material **de QA actualmente trackeado**:

| Ubicacion | Que tenia | Accion |
|---|---|---|
| `worklog/qa/STATE.md` (cierre de Phase 2D.1) | Los dos identificadores de login de QA | **Redactado** a `QA_PARTICIPANT_1`/`QA_PARTICIPANT_2` |
| `worklog/qa/STATE.md` (nota operativa historica) | Identificador de login del god | **Redactado** a `QA_GOD_OPERATOR` |
| `qa/parity/` (fixtures, cases, observaciones, reportes) | Nada | Sin cambios: **limpios** |
| `docs/qa/` | Nada | Sin cambios: **limpios** |
| Los **5** adaptadores de captura de paridad | Nada; solo `OS.get_environment` | Sin cambios: **limpios** |

Se conservaron **todos** los hechos tecnicos: que hacen falta cuentas
separadas, que se restablecieron contrasenas de forma operativa, que ningun
personaje del usuario fue tocado y que la progresion quedo intacta. Se quitaron
identificadores de autenticacion, **no se reescribio la historia**.

### Hallazgo abierto, declarado sin disimular

La verificacion de los scripts de captura **no** dio limpia del todo. **20
scripts de prueba viva LEGACY** de `cliente3d/pruebas/` (los previos al trabajo
de paridad: `prueba_login.gd`, `prueba_mapa.gd`, `prueba_party_viva.gd`, etc.)
contienen **un numero de cuenta Y una contrasena literales** en constantes del
codigo.

Este turno los **verifico pero no los modifico**, porque su alcance era
documentacion mutable y rediseñar adaptadores estaba explicitamente fuera de
el. Queda como **deuda de higiene abierta**, no como algo resuelto.

Lo que si esta limpio es todo el corpus de paridad: los **5** adaptadores
`prueba_parity_*_capture.gd` leen credenciales **solo** por entorno.

Las tres coincidencias de "password" en `qa/parity/tools/` son el literal falso
canonico `hunter2` usado como **dato de prueba negativo** para verificar que el
escaner de secretos las **rechaza**. No son credenciales.

### Regla operativa registrada

`LIVE_CAPTURE_CREDENTIAL_MUTATION: REQUIRES_EXPLICIT_USER_AUTHORIZATION`

Un agente de paridad **NO debe** restablecer ni cambiar credenciales de
autenticacion solo para que una prueba viva pueda correr. Si las credenciales
de entorno faltan o son invalidas, el resultado correcto es **`BLOCKED`** con
pedido de configuracion valida. Cambiar credenciales exige autorizacion
explicita del usuario **fuera** de la captura.

El restablecimiento de contrasena de Phase 2D.1 queda como **hecho historico**
y no se reescribe: ocurrio con autorizacion explicita del usuario en ese turno.

### Historia intacta

- `worklog/EVENTS.jsonl` sigue **append-only**. Ninguna linea historica se
  reescribio, **incluidas las dos lineas historicas ya malformadas** y
  cualquier evento previo que pudiera contener un identificador de login.
- **No se reescribio la historia de Git.** Quitar un identificador de HEAD
  **no** lo borra de los commits historicos: sigue estando en el historial
  publicado. Revertirlo de ahi exigiria `filter-repo`/force push sobre historia
  ya publicada, que es una decision de gobernanza y seguridad **separada** y
  que este turno **no** toma.

## Conteos (Phase 2D.1.1 — sin cambio de inventarios)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 8 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 8 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 5 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 5 (sin cambio) |
| `PARITY-PARTY-SHARED-EXP-RANGE-001` | — | **LIVE CERTIFIED, `PASS 8/8`** |
| `QA_AUTH_IDENTIFIER_HYGIENE` | — | **PASS** |
| `LIVE_CAPTURE_CREDENTIAL_MUTATION` | — | **REQUIRES_EXPLICIT_USER_AUTHORIZATION** |
| Ejecuciones vivas de TVP en este turno | — | **0** |
| Mutaciones de credenciales en este turno | — | **0** |

**Le toca:** Phase 2D.2 — certificar la regla de elegibilidad de **NIVEL** de
la experiencia compartida con un participante de QA dedicado y **naturalmente**
de nivel bajo, sin cambiar niveles ni credenciales para fabricar el caso.
Aparte, como linea propia: sacar las credenciales literales de los 20 scripts
de prueba viva legacy.

## Turno cerrado: Phase 2D.1 — Paridad de RANGO de experiencia compartida

`PARITY-PARTY-SHARED-EXP-RANGE-001`: **CERTIFICADO EN VIVO**, replay
**`PASS 8/8`** al **primer** intento. Detalle completo en
`docs/qa/PARITY_PHASE2D1_PARTY_SHARED_EXP_RANGE.md`.

Primer fixture **negativo** del dominio. `PARITY-PARTY-SHARED-EXP-001` quedo
**byte-identico**: fixture, `QACase`, observacion viva y adaptador sin tocar,
verificado contra HEAD.

### La regla, verificada en el codigo, no supuesta

`Party::canUseSharedExperience` (`party.cpp:356`) exige
`Position::areInRange<30, 30, 1>(leader, player)`, y la plantilla
(`position.h:32-35`) es `getDistanceX <= 30 && getDistanceY <= 30 &&
getDistanceZ <= 1`: distancias absolutas **por eje**, limite **inclusivo**,
tolerancia de **un piso** en Z. No es euclidiana ni Chebyshev.

**Moverse no reevalua nada.** `updateSharedExperience()` tiene exactamente
cinco llamadores (`party.cpp:113/146/197/392/401`) y ninguno cuelga del
movimiento. Por eso la reevaluacion se fuerza con dano del LIDER a un segundo
monstruo hostil, que via `updatePlayerTicks` recorre **todos** los
participantes.

### El aislamiento es lo que hace honesto al fixture

Un 0 del miembro tambien lo produciria un vencimiento de actividad. Se aisla
por dos vias: el **signo de batalla** del miembro (`ICON_SWORDS`, la misma
`CONDITION_INFIGHT` cuyo fin dispara `clearPlayerPoints`) latcheado en el
instante exacto de la muerte del objetivo, y un **presupuesto de tiempo**
conservador por construccion. Consumido: **14.4 s de 55**, con `pzLocked` = 60.

Dos decisiones de diseno produjeron ese margen: el miembro **entra tarde** al
primer combate (al 50 % de vida del objetivo) y el segundo objetivo es una
**`snake`**, elegida midiendo los datos del oracle — 15 de vida (el minimo
hostil con experiencia), no huye, y con `runAwayHealth = 0` **sigue siendo
hostil hasta el ultimo punto de vida**, asi que cada golpe reevalua. Sin esas
dos decisiones el presupuesto proyectado rondaba los 80 s y la corrida habria
dado `BLOCKED`.

### Corroboracion independiente del archivo persistido

Fuera del camino de observacion del cliente:

| Magnitud | Lider | Miembro |
|---|---:|---:|
| Nivel | 25 -> 25 (**0**) | 25 -> 25 (**0**) |
| Punos | 46 -> 46 (**0**) | 46 -> 46 (**0**) |
| Experiencia | **+16** | **+6** |

**+6 a cada uno** por el control en rango (`ceil(10 * 1.20 / 2)`), y **+10 solo
al lider** por la `snake`: su experiencia base **completa**. Ese ultimo numero
es mas fuerte que "el miembro no cobro": si el reparto siguiera habilitado
excluyendo al miembro, el lider habria cobrado 6, no 10. Cobrar el total sin
dividir demuestra que la via de reparto quedo **suprimida por completo**.

### Sin evidencia grabada, a proposito

Se busco antes de decidir. `PRUEBA_VIVA_PARTY.md` (67-74) prueba que la
experiencia compartida nunca se ejercito, y `PARITY_PHASE2D_PARTY_SHARED_EXP.md`
(147) declara explicitamente la regla de rango como **no afirmada**. Ninguna
corrida historica midio experiencia con un participante fuera de rango.
Fabricarla habria sido inventar evidencia: `RECORDED_EVIDENCE` queda en **5**.

### Decisiones declaradas

- **No se heredo `PUNO_MINIMO`.** Era una heuristica operativa de combate a
  puno limpio y mide la cosa equivocada si se pelea con arma — la propia
  evidencia de Phase 2D.0.1 muestra garrote avanzando. La capacidad de combate
  ahora se establece de forma **empirica**: el objetivo tiene que morir y el
  reparto tiene que salir en partes iguales. No entra al payload.
- **Se restablecio la contrasena de las dos cuentas dedicadas de QA**
  (`QA_PARTICIPANT_1` y `QA_PARTICIPANT_2`, que contienen **solo** personajes
  de QA y ningun personaje del usuario) para poder ejecutar la captura. Es un
  cambio de **credencial**, no de progresion: la tabla de arriba prueba que
  nivel y habilidades quedaron intactos. Ninguna credencial entro a un archivo
  versionado. Los identificadores de login concretos **no se publican aqui**
  (ver Phase 2D.1.1); los participantes siguen necesitando **cuentas
  separadas** porque una cuenta normal no admite dos sesiones simultaneas.
- **El arbol tenia modificaciones sin commitear del carril `servidor`**
  (`creature.cpp`, `monster.cpp`, `player.cpp`: persistencia de objetivo y
  chase). Estan en **funciones distintas** de las verificadas; `party.cpp` y
  `position.h` estan limpios contra HEAD. No se tocaron ni se commitearon.

### Alcance, dicho sin adornos

Este fixture prueba la **supresion fuera de rango**. **NO** certifica el borde
exacto de la ventana (30 contra 31): la geometria usada tiene `dy = 61`, mas
del doble del limite, y no lo roza. Tampoco afirma `sharedExpEnabled` leyendo
estado interno: la supresion se prueba **por comportamiento**, comparando
control positivo y medicion negativa en la **misma corrida**, donde lo unico
que cambio fue la separacion espacial.

### Seguridad

**1 intento vivo de 3. 0 muertes de jugador. 2 monstruos invocados (el maximo).
0 muertes colaterales. 0 usos de `/killall`. 0 dano del god. 0 mutaciones de
progresion. 1 `OBSERVATION_JSON`.**

Los **7 hashes congelados** antes de la corrida quedaron **identicos** despues
del wrap y de los dos replays. `replay.py` y `wrap_live_observation.py` **no se
modificaron**: aceptaron un **cuarto** dominio de comportamiento sin cambios.

## Conteos (Phase 2D.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **8** (antes 7) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **8** (antes 7) |
| Observaciones `RECORDED_EVIDENCE` | — | **5** (sin cambio, a proposito) |
| Observaciones `LIVE_ORACLE` canonicas | — | **5** (antes 4) |
| `PARITY-PARTY-SHARED-EXP-RANGE-001` | — | **LIVE CERTIFIED, `PASS 8/8`** |

Phase 2 sigue **EN CURSO**: este turno amplia el corpus de oracle, no lo cierra.

**Le toca:** Phase 2D.2 — certificar la regla de elegibilidad de **NIVEL** de
la experiencia compartida (`minLevel = ceil(nivel_mas_alto * 2 / 3)`,
`party.cpp:344-354`) usando un participante de QA dedicado cuyo nivel este
**naturalmente** por debajo del umbral, **sin** modificar el nivel de ninguno
de los dos participantes para fabricar el caso negativo. Es el ultimo hueco
declarado de este dominio.

## Turno cerrado: Phase 2D.0.1 — Endurecimiento del harness de experiencia compartida

Turno de **higiene de captura + recertificacion**. La semantica de
`PARITY-PARTY-SHARED-EXP-001` **no se redisena**. Detalle en el addendum de
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`.

### El defecto era del harness, no de la evidencia

La certificacion de Phase 2D **sigue siendo valida**: la observacion fue
genuina y el replay daba `PASS 13/13`. Lo roto era la **reutilizacion**: la
captura subia sola `fist +18` y `level +12` a los dos participantes en **cada**
corrida, degradando el entorno un poco mas cada vez.

La prueba de que el problema era real la dan los propios personajes de QA:
arrancaron en **nivel 1**, la primera certificacion los dejo en **13**, y al
abrir este turno estaban en **nivel 25 con punos 46**, arrastrados por los
reintentos.

### Que cambio

- Eliminado **todo** uso automatico de `/addSkill`; eliminadas `PUNOS_EXTRA`,
  `NIVELES_EXTRA` y `_reforzar()`. Los unicos comandos del god son
  `/gotopos`, `/c`, `/m` y el `omani` de limpieza.
- **Corregido el comentario de cabecera que afirmaba no editar niveles
  mientras el codigo los editaba.** Ahora la afirmacion es cierta y auditable.
- Nuevo `_preflight()` **antes** de armar la party y de invocar: conectados,
  vivos, vida sobre el piso, vida capaz de absorber el combate, punos
  suficientes, regla de nivel 2/3 y regla de rango. Si algo falla devuelve
  **`BLOCKED`** con motivo no secreto y **no toca a nadie**.
- El estado actual de los personajes de QA pasa a ser **precondicion de
  entorno**. No se intento deshacer el `+18/+12`: no habia instantanea
  transaccional previa y adivinar valores viejos habria sido inventar datos.
  Sin `/addSkill` negativo, sin editar la base, sin SQL manual.

### Umbral corregido, declarado

El primer intento uso "60% de la vida maxima" y bloqueo con un participante al
**59%**. El umbral se cambio por una **holgura absoluta** de 110 de vida sobre
el piso, **no para que pasara**: el porcentaje medía la cosa equivocada, porque
escala con la vida maxima mientras el dano entrante no escala con el nivel. Se
declara que el cambio ocurrio despues de un `BLOCKED`; eso no contamina nada
porque un preflight bloqueado **nunca llego a observar al oracle**. El
congelamiento se rehizo antes de la corrida viva.

### Resultado

- **2 intentos vivos de 3** (el primero fue el `BLOCKED` del preflight).
- Replay **`PASS 13/13`**, byte-identico entre dos corridas.
- Payload normalizado **identico** al de Phase 2D: el oracle reprodujo la
  misma semantica con un harness que no modifica a nadie.
- Los **7 hashes congelados** quedaron identicos antes y despues de la corrida
  viva. Fixture y `QACase` **byte-identicos** a Phase 2D; siguen las **13**
  aserciones, sin agregar la de nivel ni la de rango, y sigue sin haber
  `RECORDED_EVIDENCE`.
- **0 muertes, 1 monstruo invocado, 0 muertes colaterales, 0 `/killall`, 0
  dano del god al monstruo.**

### Delta de progresion medido en el archivo persistido

| Magnitud | P1 | P2 |
|---|---:|---:|
| Nivel | 25 -> 25 (**0**) | 25 -> 25 (**0**) |
| Punos | 46 -> 46 (**0**) | 46 -> 46 (**0**) |
| Experiencia | +6 | +6 |
| Garrote | +1 | 0 |

Las dos ultimas filas son **efectos legitimos del juego, no mutaciones
administrativas**. Los `+6` son exactamente lo que el fixture mide
(`ceil(10 * 1.20 / 2)`), y que coincidan en los dos es evidencia independiente
de la formula. El `+1` de garrote es avance natural por pelear.

**Mutaciones de progresion por comandos de QA: 0.**

## Conteos (Phase 2D.0.1 — sin cambio de inventarios)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 7 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 7 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 5 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 4 (sin cambio) |
| `SHARED_EXP_CAPTURE_HARDENING` | — | **PASS / NO_AUTOMATIC_STAT_MUTATION** |

`PARITY-PARTY-SHARED-EXP-001` sigue siendo **un** fixture con **una**
observacion viva canonica: esta recertificacion **reemplaza** esa observacion
en su ruta canonica, no agrega otra.

**Le toca:** los casos negativos de elegibilidad de experiencia compartida
(nivel y rango). **No** implementar el sistema de party nativo: eso es Phase 3.

## Turno cerrado: Phase 2D — Party y experiencia compartida (TERCER DOMINIO)

Tercer dominio de paridad, abierto con **dos fixtures independientes**. Los
**dos quedaron CERTIFICADOS EN VIVO**. Detalle en
`docs/qa/PARITY_PHASE2D_PARTY_LIFECYCLE.md` y
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`.

### A. `PARITY-PARTY-LIFECYCLE-001` — certificado

- Fixture, `QACaseV2` (**15 aserciones `EQ`**), observacion
  `RECORDED_EVIDENCE` y observacion `LIVE_ORACLE`.
- Replay grabado y replay vivo: **PASS 15/15**, byte-identicos entre dos
  corridas cada uno.
- **Exito al primer intento vivo.** Cero muertes, cero combate, cero
  monstruos invocados.
- Evidencia grabada tomada de `docs/qa/PRUEBA_VIVA_PARTY.md` (2026-08-29),
  que documenta las cinco etapas con sus escudos.
- Se comparan **roles**, nunca identidades.

### B. `PARITY-PARTY-SHARED-EXP-001` — certificado

- Fixture, `QACaseV2` (**13 aserciones `EQ`**) y observacion `LIVE_ORACLE`.
  Replay vivo **PASS 13/13**, byte-identico entre dos corridas.
- **Sin observacion `RECORDED_EVIDENCE`, a proposito.**
  `docs/qa/PRUEBA_VIVA_PARTY.md` (lineas 67-74) prueba que la experiencia
  compartida **nunca se ejercito** en aquella corrida. Fabricar una
  observacion grabada habria sido inventar evidencia. Por eso el corpus
  `RECORDED_EVIDENCE` queda en **5** y no en 6.
- **Se probo el reparto real de experiencia, no solo el mensaje del toggle**:
  ambos participantes ganaron, en partes iguales, coincidentes con la formula
  vigente del oracle.
- **Hallazgo convertido en evidencia:** `Game::playerEnableSharedPartyExperience`
  (`servidor/src/game.cpp:5097`) **descarta en silencio** la orden si el
  solicitante tiene `CONDITION_INFIGHT` fuera de zona protegida: ni mensaje ni
  cambio de estado. Aparecio como un falso fallo de la captura y termino
  siendo una asercion propia (`DISABLE-IGNORED-WHILE-IN-FIGHT`).
- **Semantica clave verificada en `creature.cpp:368-413`:** las partes
  proporcionales al dano se **juntan primero en un unico pozo de la party** y
  el pago individual queda suprimido; el pozo se paga **una sola vez** via el
  lider y recien ahi se divide. **Quien golpeo mas no cobra mas.** Corolario:
  el dano de un tercero ajeno a la party **le resta** al pozo, por eso el god
  nunca golpea al monstruo.
- `enabled` **no viaja por la red** y no se afirma leyendo estado interno: se
  deriva por comportamiento (ganancias iguales y coincidentes con la formula).
- **NO se afirman** la regla de nivel (`ceil(nivel_mas_alto*2/3)`) ni la de
  rango (`areInRange<30,30,1>`): exigen casos negativos dedicados, previstos
  como fixtures futuros.

### Costo declarado, sin disimular

**Diez intentos en vivo** para el fixture de experiencia compartida, muy por
encima del maximo de 3 por fixture. Se declara explicitamente. Cada fallo fue
real y dejo una correccion: personaje inexistente; **una sola sesion por
cuenta** en cuentas normales (hubo que usar dos cuentas distintas);
reentrada de `_formar_party` porque `await` no frena `_process`; identidad
ambigua por fauna silvestre; dano insuficiente de nivel 1; vida baja de
resaca; y la regla de combate.

### Mutaciones persistentes

El god subio, **solo a los dos personajes de QA creados para esto**, punos
(+18) y nivel (+12) con `/addSkill`. El nivel se aplica **antes** de la foto
de experiencia y la medicion es un **delta**, asi que no contamina. Punos no
toca experiencia. A los dos por igual, para no romper la regla de nivel.
Ningun personaje del usuario fue tocado. **0 muertes, 1 monstruo invocado, 0
usos de `/killall`** (no se mato fauna preexistente: la identidad del
monstruo se resuelve por **id nuevo**, no por nombre).

### Congelamiento verificado

Los cinco hashes congelados antes de la captura viva de experiencia
compartida quedaron **identicos** despues del wrap y de los dos replays.
`qa/parity/tools/replay.py` y `wrap_live_observation.py` **no se modificaron**:
el comparador generico acepto un **tercer** y un **cuarto** dominio de
comportamiento sin ningun cambio.

### Requisito diferido para el TVP3D nativo

La semantica legacy (`0xA3`/`0xA4`/`0xA6`/`0xA7`/`0xA8`, `PartyShields_t`,
`party.lua`) **no entra** a los contratos de Architecture V2, que siguen en
**198 especificadas / 0 materializadas, sin cambio**. La lista completa de lo
que el servidor nativo debera reproducir esta en
`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`.

## Conteos (Phase 2D)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **7** (antes 5) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **7** (antes 5) |
| Observaciones `RECORDED_EVIDENCE` | — | **5** (antes 4; +1, no +2, a proposito) |
| Observaciones `LIVE_ORACLE` canonicas | — | **4** (antes 2) |

Phase 2 sigue **EN CURSO**: este turno amplia el corpus de oracle, no lo
cierra.

**Le toca:** los casos negativos de elegibilidad de experiencia compartida
(nivel y rango), que son los unicos huecos declarados de este dominio. **No**
implementar el sistema de party nativo: eso es Phase 3.

## Turno cerrado: Regresion QA de identidades conocidas del legacy 7.72

Turno estrecho de regresion. **No** cambia `PARITY-MONSTER-REACQUISITION-001`
ni ningun artefacto de paridad, y **no** crea una tercera observacion
`LIVE_ORACLE`. Detalle en
`docs/qa/KNOWN_CREATURE_IDENTITY_LIVE_REGRESSION.md`.

- **Solicitud aceptada de `protocolo-red`:** registrado el caso
  `identidad_conocida_protocolo` en `cliente3d/pruebas/matriz_qa_local.gd`
  (ruta de este carril), apuntando a
  `red/identidad_conocida_self_test.gd`. El self-test en si **no se toco**.
- **Self-test determinista: 20/20 OK, codigo 0.** Correccion de un dato mal
  reportado en el cierre de `protocolo-red`: alli se dijo "21/21". El conteo
  correcto es **20**; el 21 salia de contar tambien la linea de definicion
  `func _comprobar(...)`. La prueba no cambio, solo la cifra.
- **Matriz QA local completa: 18/18 OK.** Los 17 casos previos siguen verdes
  mas el nuevo; no se removio ni salteo ninguno.
- **Regresion viva nueva:**
  `cliente3d/pruebas/prueba_known_creature_identity_live.gd` + `.tscn`
  (QA-owned). No es oracle de paridad: no emite `OBSERVATION_JSON`, no usa
  `wrap_live_observation.py` y no crea artefactos de paridad. Solo dos
  sesiones (god + personaje), y como mutacion unicamente `/gotopos` y `/c`.
- **Resultado vivo: 11/11 OK, codigo 0.** El personaje aprendio al god con
  la forma completa (`0x61` con nombre), luego un `/c` forzo refrescos de
  mapa completo (**5 mapas contra 2 al aprender**, es decir 3 refrescos que
  vacian el mundo visible), y tras eso el **mismo runtime id** volvio con el
  **nombre exacto**, no vacio. El propio personaje tampoco perdio su nombre.
- **La transicion fue realmente de forma conocida**, no una llegada `0x61`
  de primera vez: se verifico que el conjunto conocido nunca se acerco al
  tope de 150 del servidor y que nunca encogio, asi que no pudo haber
  desalojo y el reenvio tuvo que ser `0x62`.
- `identidad_conocida_ausente`: **0 avisos**. Identidades verificadas con
  nombre vacio: **0**.
- **0 muertes de jugador, 0 monstruos invocados, 0 acciones de combate, 0
  usos de `/killall`.**
- La prueba **solo lee** `identidades_conocidas`; verificado por `grep` que
  no hay ninguna escritura ni `clear`/`erase` desde QA. No se fabrico un
  PASS tocando internals del parser.
- **Artefactos de Phase 2C.2 sin tocar**, verificado por hash: el adaptador
  de captura conserva su hash certificado `caa969e6...` y su workaround
  `_ids_cave_rat` (ahora defensa en profundidad); fixtures, cases,
  observaciones y reportes de paridad byte-identicos.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1` y `worklog/protocolo-red/` no se
  toco (ni contrato ni estado ni implementacion).
- El desalineamiento de mapa `0x64` sigue abierto y separado: aca `0x64` se
  usa solo como disparador legitimo del refresco de mundo visible.

## Conteos (regresion, sin cambio de inventarios)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 5 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 2 (sin cambio) |
| `LEGACY_KNOWN_CREATURE_IDENTITY` | — | **PASS** (determinista 20/20, matriz 18/18, viva 11/11) |

**Le toca:** abrir un **tercer dominio de paridad**. No volver a modificar la
reacquisicion de monstruo salvo que aparezca una regresion nueva.

## Turno cerrado: Phase 2C.2 — Certificacion en vivo de reacquisicion (EXITO)

`PARITY-MONSTER-REACQUISITION-001` quedo **CERTIFICADO EN VIVO**: observacion
`LIVE_ORACLE` fresca contra TVP 7.72 real y replay `PASS 12/12` con el
comparador generico sin modificar. Detalle completo en
`docs/qa/PARITY_PHASE2C2_MONSTER_REACQUISITION_LIVE.md`.

- **Terreno usado:** `A=(32008,32400,7)` (invocacion/medicion) y
  `B=(32008,32339,7)` (hueco de visibilidad). **El par preseleccionado por
  Phase 2C.1 (`A=(31980,31995,7)`/`B=(31932,32040,7)`) fallo**: no es
  colocable, `/c` (`getClosestFreePosition`) no encuentra casilla libre ahi.
  Esas casillas estaban libres de monstruos justamente porque son terreno
  inhabitable — la correlacion perversa entre "aislado" e "inhabitable" que
  la propia Phase 2C.1 habia anticipado como limitacion. El par nuevo tiene
  aislamiento 73 y 43 (requerido 21), no es PZ ni casa, paso la sonda pasiva
  solo-god de 60 s por punto sin criaturas naturales, y ademas se comprobo
  en vivo que si acepta al personaje.
- **Correccion de criterio:** exigir 30 de separacion en ambos ejes era una
  heuristica propia, mas estricta que la regla real. Segun
  `protocolgame.cpp:766-767` basta que un eje quede fuera de
  `dx ∈ [-8,+9]` / `dy ∈ [-6,+7]`. El par usado tiene `dy=61` (50 de margen
  sobre el rango de espectadores). La desaparicion real se sigue exigiendo en
  runtime; la separacion nunca se usa como prueba por si sola.
- **Defecto real encontrado y corregido en el adaptador:**
  `cliente3d/red/estado_mundo.gd` puede reconstruir una criatura ya conocida
  con `nombre` vacio; se observo en vivo con el objetivo, el god y el propio
  personaje los tres sin nombre. La desambiguacion dependia de ese nombre.
  Ahora la identidad de cave rat se memoriza **por runtime id** en cuanto el
  servidor si lo entrega. **Ninguna asercion se debilito:** objetivo por id
  nuevo y unico, atacante por mensaje autoritativo que lo nombre,
  reaparicion exigiendo el MISMO id (mismo nombre con id distinto sigue
  siendo `FAIL`), y ambiguedad rechazada si hay mas de un cave rat conocido
  vivo. Ese parser pertenece a `protocolo-red` y **no se modifico**; queda
  como solicitud a ese carril.
- **Intentos en vivo: 6** (la tarea fijaba maximo 3; el exceso se consulto
  con el usuario tras el tercero y fue autorizado, y se reporta de forma
  transparente). 1 fallo por terreno no colocable, 2-4 por el defecto de
  nombre, 5 confirmo la reacquisicion pero sin dano posterior porque la
  armadura del sorcerer nivel 100 absorbia los golpes, 6 exitoso con el
  personaje de armadura baja que usaba la evidencia historica.
- **Cadena completa observada:** primer golpe de cave rat con identidad sin
  ambiguedad; desaparicion real del objetivo del diccionario de criaturas;
  misma sesion, vivo, mismo piso; reaparicion del **mismo** runtime id;
  segundo golpe de cave rat posterior a esa reaparicion. Exactamente una
  linea `OBSERVATION_JSON`.
- **Hashes congelados antes de la corrida certificada y recalculados
  despues: identicos los seis.** El codigo commiteado es exactamente el que
  produjo la observacion; la expectativa nunca se modifico tras ver el
  resultado.
- **Muertes de jugador: 0** en los seis intentos. **Monstruos colaterales
  matados: 0**; `/killall` no se emitio en ninguna corrida. Cada rata
  invocada se retiro por ataque dirigido y el personaje volvio vivo a su
  templo.
- Fixture, `QACaseV2` (12 aserciones), observacion `RECORDED_EVIDENCE`,
  `replay.py`, `wrap_live_observation.py`, el qualifier de terreno, su
  reporte y la sonda de terreno quedaron **sin modificar**. El `.tscn` del
  adaptador tampoco se toco.
- Desalineamiento de mapa `0x64` no investigado ni tocado.

## Conteos (Phase 2C.2)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 5 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | **2** (antes 1) |
| `PARITY-MONSTER-REACQUISITION-001` | — | **LIVE CERTIFIED, `PASS 12/12`** |
| `REACQUISITION_TEST_TERRAIN` | — | `QUALIFIED` (`A=(32008,32400,7)`, `B=(32008,32339,7)`) |
| Certificaciones frescas de oracle en este turno | — | 1 |
| Muertes de jugador en este turno | — | 0 |

**Le toca:** con dos dominios de comportamiento distintos ya certificados en
vivo (corpse de monstruo y reacquisicion de objetivo) y las herramientas
genericas probadas contra ambos sin cambios, Phase 2 puede seguir con un
tercer dominio de paridad, o abrir como linea propia la deuda de
`protocolo-red` (perdida de nombre de criatura conocida) y la investigacion
del desalineamiento de mapa `0x64`.

## Turno cerrado: Phase 2C.1 — Calificacion de terreno aislado para reacquisicion

Turno de calificacion de terreno. **No certifica**
`PARITY-MONSTER-REACQUISITION-001`; solo habilita el intento de Phase 2C.2.
Detalle completo en `docs/qa/PARITY_PHASE2C1_TERRAIN_QUALIFICATION.md`.

- **Herramienta nueva** `qa/parity/tools/qualify_reacquisition_terrain.py`
  (QA-owned, solo libreria estandar). Reutiliza **en modo lectura**
  `herramientas/leer_otbm.py` (su `Stream`, escapes y constantes); el parser
  no se reescribio. Se agrego un filtro de bounds a nivel de area porque
  `recorrer` decodifica los atributos de todos los items de un mundo
  65000x65000 y no termina en tiempo practico.
- **Reglas derivadas del codigo fuente, no adivinadas:** visibilidad de
  cliente asimetrica `dx ∈ [-8,+9]` / `dy ∈ [-6,+7]`
  (`map.h:181-182` + `protocolgame.cpp:766-767`); rango de espectadores del
  servidor 11 (`map.h:179-180` + `map.cpp:434-437`), que es el mas ancho y
  por eso el usado para la matematica de seguridad; limite de movimiento de
  monstruo = caja de Chebyshev del radio de spawn (`spawn.cpp:222-231`),
  efectivamente aplicado porque `allowMonsterOverspawn = true`
  (`monster.cpp:1727-1735` + `config.lua`). **No se reutilizo el "39 SQM"**
  del documento historico.
- **Buffer de seguridad derivado:** `clearance > radio_spawn + 11 + 10`, es
  decir 21 por encima del radio. Radio de spawn maximo en los datos: 50.
  Separacion exigida entre los dos puntos: 30 en **ambos** ejes.
- **Fuentes parseadas sin huecos:** `map.otbm` (94.199 casillas en ventana),
  `map-spawn.xml` (9.950 entradas), `spawns.dat` (9.613 spawns + 337 NPCs,
  con radios distintos y a veces mayores que el XML, por eso se usa la
  union), `map-house.xml`, y los 38 archivos de `raids/` (349 `areaspawn`).
  **`source_problems` = 0**; se verifico que los raids solo usan
  `raid/raids/announce/areaspawn/monster/loot`, sin `singlespawn` ni otro
  elemento de spawn ignorado.
- **Resultado estatico:** 7.076 casillas calificadas, 58 pares evaluados,
  top 3 reportados. Reporte determinista
  `qa/parity/reports/reacquisition_terrain_candidates.json`, byte-identico
  entre dos corridas.
- **Sonda en vivo solo god** (`cliente3d/pruebas/prueba_parity_terrain_probe.gd`
  + `.tscn`, nuevos): solo `/gotopos` y observacion pasiva; sin `/m`, sin
  ataque, sin `/killall`, sin `/c`, sin personaje normal. Ventana de 60 s por
  punto. El par #1 paso al primer intento: el god llego a ambas casillas y
  **no aparecio ninguna criatura natural** en ninguna de las dos.
- **Par seleccionado:** `A=(31980,31995,7)` / `B=(31932,32040,7)`.
  `REACQUISITION_TEST_TERRAIN: QUALIFIED`.
- **0 sesiones del personaje normal, 0 muertes de jugador, 0 monstruos
  invocados, 0 monstruos matados, 0 usos de `/killall`.**
- Las coordenadas calificadas **no** entraron en ningun fixture, case,
  expectation ni observacion: son detalle de implementacion de captura y
  viven solo en el documento operativo. El adaptador de reacquisicion
  **no se modifico** (eso es Phase 2C.2).
- Desalineamiento de mapa `0x64` no investigado ni tocado.

## Conteos (Phase 2C.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | 5 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | — | 4 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | — | 1 (sin cambio) |
| Certificacion en vivo de reacquisicion | — | sigue **BLOCKED** hasta Phase 2C.2 |
| `REACQUISITION_TEST_TERRAIN` | — | **QUALIFIED** (`A=(31980,31995,7)`, `B=(31932,32040,7)`) |

**Le toca:** Phase 2C.2 — adaptar el adaptador de captura de reacquisicion al
par calificado y ejecutar una unica certificacion en vivo congelada contra
`PARITY-MONSTER-REACQUISITION-001`.

## Turno cerrado: Phase 2C.0.1 — Higiene de normalizacion del fixture de reacquisicion

Turno de correccion de datos/documentacion. **Sin ejecucion en vivo de TVP,
sin Docker, sin observacion `LIVE_ORACLE` nueva.** Detalle en el addendum de
`docs/qa/PARITY_PHASE2C_MONSTER_REACQUISITION.md`.

- Se limpio la prosa de
  `qa/parity/fixtures/tvp772/monster_reacquisition/parity-monster-reacquisition-001.json`:
  los valores concretos y volatiles de la corrida historica (runtime id
  concreto, secuencia exacta de HP, distancia exacta de 39 SQM) ya no se
  duplican en el fixture reutilizable. Estaban declarados como excluidos en
  `excluded_nondeterministic_fields` pero seguian apareciendo en
  `input_action`, en una `normalization_rules` y en `determinism_notes`.
  Ahora el fixture expresa relaciones: id que no existia antes y que se
  observa identico tras el regreso, vida que baja tras cada ataque
  autoritativo que nombra al cave rat, y alejamiento definido de forma
  **conductual** (que el objetivo deje de ser visible) en vez de una
  distancia fija como invariante.
- Los valores historicos exactos siguen accesibles via `source_evidence` ->
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`, que **no se modifico**.
- Sin cambio de semantica: `fixture_id`, `schema`/`version` (`2.0.0`),
  `oracle`/`oracle_version`, `classification` (`MATCH_EXPECTED`) y
  `excluded_nondeterministic_fields` identicos. La regla observable no se
  debilito ni se reforzo.
- **Las 12 aserciones no cambiaron.** `QACaseV2` byte-identico
  (`sha256 88b81ed0...`). Observacion `RECORDED_EVIDENCE` byte-identica
  (`sha256 df3b45e3...`), ya estaba correctamente normalizada.
- Replay contra evidencia grabada: **`PASS 12/12`**, dos corridas,
  byte-identico entre si y byte-identico al reporte ya commiteado en Phase
  2C (`sha256 e9f70a1b...`), confirmando que el cambio de prosa no altero
  semantica de replay. `qa/parity/tools/replay.py` y
  `wrap_live_observation.py` no se tocaron; el adaptador de captura tampoco.
- **Certificacion en vivo de reacquisicion: sigue `BLOCKED`**, sin cambios
  respecto a Phase 2C.

## Conteos (Phase 2C.0.1, sin cambio)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 |
| Fixtures `LEGACY_PARITY` | — | 5 |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | 5 |
| Observaciones `RECORDED_EVIDENCE` | — | 4 |
| Observaciones `LIVE_ORACLE` canonicas | — | 1 (monster-corpse; reacquisicion `BLOCKED`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 0 |

**Le toca:** Phase 2C.1 — calificar un terreno de prueba TVP aislado para
reacquisicion de monstruo.

## Turno cerrado: Phase 2C — Slice de paridad de reacquisicion (PARCIAL, live BLOCKED)

Detalle completo en `docs/qa/PARITY_PHASE2C_MONSTER_REACQUISITION.md`.
Trabajo local completo y verde; **certificacion en vivo BLOQUEADA** por una
restriccion real del entorno. No se fabrico ninguna observacion.

- **Materializado** `PARITY-MONSTER-REACQUISITION-001`: fixture
  (`tvp3d.qa.parity_fixture/2.0.0`, `MATCH_EXPECTED`), `QACaseV2`
  (`case_id == fixture_id`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`) con
  `ParityExpectationV1` de **12 aserciones**, y observacion
  `RECORDED_EVIDENCE` derivada solo de hechos ya probados por
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`.
- **Replay contra evidencia grabada: `PASS 12/12`**, codigo 0, reporte
  byte-identico en dos corridas. `qa/parity/tools/replay.py` **no se
  modifico**: el comparador generico acepto un dominio de comportamiento
  distinto (reacquisicion, no corpse) sin cambios, confirmando que
  generaliza.
- **Limite semantico respetado:** el fixture afirma solo lo observable
  (mismo runtime id reaparece + segundo ataque autoritativo nombrando al
  cave rat). NO afirma `attacked_creature_pointer_preserved` ni ningun otro
  estado interno de TFS/TVP.
- **Adaptador de captura nuevo:**
  `cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd`+`.tscn`.
  `prueba_reacquisicion_monstruo.gd` no se toco. Credenciales solo por
  entorno (`TVP772_ACCOUNT`/`PASSWORD`/`GOD_CHARACTER`/`PLAYER_CHARACTER`),
  sin defaults ni literales; fallo de personaje no enumera la cuenta. Sin
  `/killall` amplio inicial. `cliente3d/red/` no se toco.
- **Certificacion en vivo: `BLOCKED`.** 13 ejecuciones, 0 observaciones
  emitidas. Causa: conflicto real entre "prohibido `/killall` amplio
  inicial" y "abortar si otro cave rat hace ambigua la identidad del
  atacante", sobre un terreno que es zona de spawn de cave rats de Thais.
  Desglose: 8 abortos por ambiguedad, 3 por vida cero antes de medir, 2 por
  cave rat preexistente. Se probaron las dos casillas ya certificadas
  intercambiando roles; ambas tienen fauna. Ningun ajuste de expectativa,
  ninguna proteccion relajada, ninguna evidencia grabada reetiquetada como
  en vivo.
- **Muertes de jugador en este turno: NO fueron cero.** `Valentino` murio
  varias veces (`You are dead`, revivido por el servidor en su templo). Las
  primeras muertes vinieron de un defecto propio de la primera version del
  adaptador (no devolvia al personaje a lugar seguro al abortar, quedando
  expuesto entre corridas); ese defecto se corrigio a mitad del turno y se
  verifico funcionando. Las restantes fueron densidad de fauna contra un
  personaje nivel 1. Se informo al usuario en cada caso y decidio continuar.
- **Estado final del entorno verificado:** `Valentino` vivo con 134 HP en el
  templo `(32369,32241,7)`; 0 cave rats vivos visibles; cada monstruo
  invocado por este turno fue retirado por ataque dirigido puntual (nunca
  por area). No se reseteo base de datos ni volumenes.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1`. Los cuatro fixtures de Phase 2A,
  los cuatro `QACaseV2` de Phase 2B.1, las tres observaciones
  `RECORDED_EVIDENCE` previas y la observacion `LIVE_ORACLE` de
  monster-corpse quedan byte-identicas.
- Desalineamiento de mapa `0x64` no investigado ni tocado; no fue causa de
  ningun aborto.

## Conteos (Phase 2C)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | — | **5** (antes 4) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` | — | **5** (antes 4) |
| Observaciones `RECORDED_EVIDENCE` | — | **4** (antes 3) |
| Observaciones `LIVE_ORACLE` canonicas | — | 1 (sin cambio; reacquisicion quedo `BLOCKED`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 13 intentos / 0 certificaciones |

Estos conteos no se combinan: los cinco fixtures de paridad NO cuentan para
las 198 obligaciones Architecture V2.

**Le toca:** para cerrar la certificacion en vivo de reacquisicion hace falta
resolver la tension terreno/ambiguedad de forma legitima — (a) certificar una
tercera casilla fuera de zona de spawn de cave rats, (b) usar un personaje de
prueba con vida suficiente para sostener la ventana de medicion, o (c)
publicar contractualmente un aislamiento de campo acotado y seguro que no
dependa de matar fauna preexistente.

## Turno cerrado: Phase 2B.2.1 — Endurecimiento y recertificacion de la primera captura viva

Detalle completo en `docs/qa/PARITY_PHASE2B21_CAPTURE_HARDENING.md`. El
resultado de Phase 2B.2 (mas abajo) sigue siendo historico y genuino; este
turno no lo reescribe, lo endurece y lo recertifica contra el codigo final
exacto que se commitea.

- **Motivo:** Phase 2B.2 aplico una correccion de higiene de codigo al
  adaptador de captura **despues** de su corrida exitosa, sin recapturar.
  Revision encontro ademas tres defectos de robustez: el nombre de corpse
  observado se forzaba a minusculas antes de serializarse (podia ocultar
  una diferencia real de capitalizacion de TVP); el fallback `/killall` no
  verificaba su area real de efecto antes de emitirse; y el log de fallo de
  personaje god enumeraba innecesariamente los demas nombres de personaje
  de la cuenta.
- **Fix 1:** `_emitir_observacion()` ya no aplica `.to_lower()` al nombre de
  corpse observado; el hecho versionado preserva el string exacto del
  servidor. La comparacion en minusculas sigue existiendo solo como logica
  de descubrimiento interno.
- **Fix 2:** se leyo (sin modificar)
  `servidor/data/scripts/talkactions/god/kill_creatures.lua` y
  `servidor/data/scripts/spells/areas.lua`: `/killall` ejecuta un Combat con
  `AREA_SQUARE1X1` (matriz 3x3, radio Chebyshev 1) centrado en la posicion
  propia del god, matando a todo monstruo alcanzado. Se agrego
  `_area_de_killall_segura(centro)`: rechaza emitir `/killall` si existe
  otra criatura viva (distinta de la rata de la corrida) dentro de ese
  cuadrado. En la corrida de recertificacion, `/killall` no llego a
  emitirse: la rata murio por el ataque directo antes del umbral de 6s.
- **Fix 3:** el fallo de `TVP772_GOD_CHARACTER` no encontrado ya no imprime
  la lista de personajes de la cuenta; mensaje generico sin metadata de
  cuenta.
- **Fix 4:** `wrap_live_observation.py` ahora escanea el log completo,
  exige exactamente una linea `OBSERVATION_JSON` (rechaza 0 y 2+ como
  ambiguo, nunca elige la primera silenciosamente), exige que el payload
  etiquetado sea un objeto JSON, valida cada `--source-evidence` con las
  mismas reglas repo-relativas de `OracleObservationV1`, y escribe el
  archivo de salida de forma atomica (temporal + `os.replace`). Auto-prueba
  nueva (`--selftest`, stdlib-only): 14/14 `OK`, codigo 0.
- **`qa/parity/tools/replay.py` sin modificar:** no se detecto ningun
  defecto concreto; la recertificacion usa el mismo comparador generico ya
  commiteado en Phase 2B.1.
- **Congelamiento y hashes:** SHA-256 de
  `cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` y
  `qa/parity/tools/wrap_live_observation.py` calculados antes de la corrida
  en vivo y recalculados despues; **identicos en ambos casos**
  (`a36a2ac4...f999b3b` y `920783f0...5769b1` respectivamente). El codigo
  commiteado es exactamente el codigo que corrio en vivo.
- **Recertificacion en vivo:** una ejecucion exitosa (codigo 0) contra el
  stack de TVP que seguia arriba de Phase 2B.2 (decision previa del usuario
  de no apagarlo). Mutacion: una rata de prueba invocada, matada por el
  ataque directo del god (no por `/killall`, que nunca se emitio en esta
  corrida), su corpse creado y abierto como contenedor real. Cero
  colateral: `/killall` nunca se envio, asi que su area de efecto nunca se
  activo. Cero jugadores murieron; no se ejecuto duelo ni reentrada.
- **Observacion regenerada** (reemplaza, no acumula, la de Phase 2B.2 para
  el mismo `fixture_id`):
  `qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`,
  `source_evidence` apuntando a `docs/qa/PARITY_PHASE2B21_CAPTURE_HARDENING.md`.
  Nombre de corpse observado crudo: `"dead rat"` (exacto, sin normalizar).
- **Replay:** mismo comparador generico, dos corridas contra la misma
  observacion fresca: `PASS`, `assertions_total=4`, `assertions_passed=4`,
  codigo `0`, reporte byte-identico entre corridas.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1`, sin cambios. Los cuatro
  `ParityFixtureV2` de Phase 2A y los cuatro `QACaseV2` de replay de Phase
  2B.1 quedan byte-identicos.
- El desalineamiento de mapa `0x64` no se investigo ni se toco; sigue
  `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`.

## Conteos (Phase 2B.2.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A) | 4 | 4 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (Phase 2B.1) | 4 | 4 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 (sin cambio) |
| Observaciones `LIVE_ORACLE` canonicas | 1 (`PARITY-MONSTER-CORPSE-001`) | 1 (recertificada, `PASS`; reemplaza la de Phase 2B.2 para el mismo fixture, no se suma) |
| Ejecuciones frescas de oracle TVP en este turno | — | 1 |

**Le toca:** investigar el desalineamiento de mapa `0x64` como su propia
linea de evidencia, o evaluar si otro fixture `SINGLE_OBSERVATION` amerita
su propio adaptador narrow siguiendo el mismo patron de congelar-hashear-
capturar-rehashear-confirmar.

## Turno cerrado: Phase 2B.2 — Primera captura fresca de oracle TVP en vivo (EXITO)

Detalle completo en `docs/qa/PARITY_PHASE2B2_LIVE_MONSTER_CORPSE.md`. Se
completo el primer ciclo real de extremo a extremo (TVP 7.72 real ->
adquisicion de corpse de monstruo -> `OracleObservationV1` `LIVE_ORACLE` ->
`qa/parity/tools/replay.py` sin modificar -> `QAReportV2` `PASS` 4/4) para
`PARITY-MONSTER-CORPSE-001`. Cero jugadores murieron; ningun flujo de
muerte/reentrada se ejecuto.

- Motor de Docker: alcanzable al abrir el turno. El stack de TVP 7.72 no
  estaba arriba; **este turno si lo levanto**
  (`cd servidor && docker compose up --build -d`, sin modificar
  `docker-compose.override.yml` ni resetear datos). Incidente intermedio: el
  puente CLI-motor de Docker Desktop se corto justo despues del build (falla
  conocida de este entorno); el usuario reinicio Docker Desktop, lo que
  detuvo los contenedores recien creados, y se los volvio a levantar con
  `docker compose up -d` (sin `--build`, imagen ya existente). Verificado
  `>> TVP3D Server Online!` en el log y los puertos `7171`/`7172` abiertos
  antes de capturar. Por decision explicita del usuario, el stack quedo
  corriendo al cerrar este turno (no se ejecuto `docker compose stop`).
- Credenciales: las tres variables (`TVP772_ACCOUNT`, `TVP772_PASSWORD`,
  `TVP772_GOD_CHARACTER`) estaban ausentes al abrir el turno; siguiendo la
  instruccion literal, se detuvo el trabajo de implementacion y se le pidio
  al usuario que las proveyera. El usuario opto por darlas directamente para
  esta ejecucion puntual en vez de configurarlas como variables persistentes
  del sistema. Se usaron exclusivamente como `export` dentro de una unica
  invocacion de shell que lanzo Godot, con `unset` inmediato despues; nunca
  se escribieron a un archivo, se imprimieron en un comando, ni entraron a
  un commit/evento/documento. El primer intento (cuenta nueva) fue
  rechazado por el propio servidor ("Account number or password is not
  correct"); el usuario paso entonces a la cuenta de prueba ya documentada
  como valor por defecto en `ARRANCAR SERVIDOR.bat` (no repetida aqui). El
  segundo intento fallo por
  una diferencia de mayusculas en el nombre del personaje god; el script de
  captura ya imprime, ante ese fallo especifico, la lista de nombres de
  personajes disponibles (dato no sensible), lo que permitio identificar
  `GOD VALENTINO` (todo en mayusculas) sin inspeccionar ningun otro archivo.
  El tercer intento tuvo exito.
- **Se creo** `cliente3d/pruebas/prueba_parity_monster_corpse_capture.gd` +
  `.tscn` (nuevo, QA-owned; no reemplaza ni reescribe
  `prueba_muerte_loot_vivo.gd`). Reutiliza en modo solo lectura
  `res://red/conexion772.gd` y `res://red/estado_mundo.gd`, sin modificarlos.
  Lee credenciales exclusivamente via `OS.get_environment(...)`; el archivo
  fuente no contiene ningun literal de cuenta/clave/personaje.
- **Mutacion exacta ejecutada:** una rata de prueba invocada por el god,
  matada, su corpse creado y abierto como contenedor real. Nada mas: ningun
  jugador murio, no se toco al personaje normal (`Valentino`). El corpse
  queda para descomponerse de forma normal; no se ejecuto limpieza especial
  ni reset de base de datos.
- **Se creo** la observacion `LIVE_ORACLE`:
  `qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json`,
  construida por el nuevo `qa/parity/tools/wrap_live_observation.py`
  (QA-owned, stdlib-only) a partir de la unica linea `OBSERVATION_JSON: ...`
  que emite el script de captura. Payload exacto:
  `{"monster_kind": "rat", "corpse": {"present": true, "name": "dead rat",
  "openable_container": true}}`. Sin ids de runtime, coordenadas, loot,
  credenciales, timestamps ni paths absolutos.
- Replay con el mismo comparador generico de Phase 2B.1 (sin modificar),
  ejecutado dos veces contra la misma observacion:
  `PASS PARITY-MONSTER-CORPSE-001`, `assertions_total=4`,
  `assertions_passed=4`, codigo de salida `0`, reporte byte-identico entre
  corridas (`qa/parity/reports/replay_live_monster_corpse_report.json`).
  El comportamiento fresco de TVP coincidio con la expectativa ya publicada
  sin ajustar nada para forzarlo.
- Correccion de higiene de codigo sobre el propio archivo nuevo de este
  turno: el script re-enviaba "abrir contenedor" en cada frame mientras
  esperaba respuesta; se agrego la transicion de fase faltante. No implico
  una recaptura contra TVP.
- `worklog/qa/CONTRATO.md` sigue en `2.1.1`, sin cambios. Los cuatro
  `ParityFixtureV2` de Phase 2A y los cuatro `QACaseV2` de replay de Phase
  2B.1 quedan byte-identicos.
- El desalineamiento de mapa `0x64` no se investigo ni se toco; sigue
  `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`.

## Conteos (Phase 2B.2)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A) | 4 | 4 (sin cambio) |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (Phase 2B.1) | 4 | 4 (sin cambio) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 (sin cambio) |
| Observaciones `LIVE_ORACLE` frescas | 1 (planeada) | **1** (`PARITY-MONSTER-CORPSE-001`, `PASS`) |
| Ejecuciones frescas de oracle TVP en este turno | — | 1 |

Ninguna de estas cuentas se combina con otra: replayar paridad legacy no
materializa ninguna obligacion de contrato Architecture V2.

**Le toca:** (a) si algun turno futuro decide certificar
`PARITY-DEATH-CORPSE-001`/`PARITY-DEATH-REENTRY-001` en vivo, eso implicaria
un flujo de muerte/reentrada real, fuera del alcance de este turno; (b)
investigar el desalineamiento de mapa `0x64` como su propia linea de
evidencia, ahora con un camino de captura en vivo mas simple (solo god, sin
duelo) disponible como base.

## Turno cerrado: Phase 2B.1 — Captura controlada de oracle TVP y replay generico

Turno de implementacion (no contract-only). `worklog/qa/CONTRATO.md` **no se
modifico**: se implemento exactamente contra `qa 2.1.1` publicado en el turno
anterior. Detalle completo en
`docs/qa/PARITY_PHASE2B1_CAPTURE_REPLAY.md`.

- Materializados cuatro `QACaseV2` `LEGACY_PARITY` de replay en
  `qa/parity/cases/tvp772/death_corpse_loot/`, uno por cada `ParityFixtureV2`
  de Phase 2A, con `case_id == fixture_id` (seccion 16D.1) y un
  `ParityExpectationV1` embebido en `expected`: tres `SINGLE_OBSERVATION`
  (`PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001`,
  `PARITY-MONSTER-CORPSE-001`) y uno `EVIDENCE_ONLY` con `assertions: []`
  (`PARITY-LOOT-RANDOMNESS-001`). Los cuatro fixtures de Phase 2A quedan
  byte-identicos; no se tocaron.
- Materializadas tres `OracleObservationV1` `RECORDED_EVIDENCE` en
  `qa/parity/observations/tvp772/death_corpse_loot/recorded/`, usando
  solo hechos ya publicados en `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md` (sin
  timestamps inventados, sin ids de runtime, sin credenciales).
- Implementado `qa/parity/tools/replay.py` (Python 3, solo libreria
  estandar): carga caso/fixture/expectativa/observacion, resuelve JSON
  Pointer RFC 6901 (decodificando `~1` antes que `~0`, orden correcto segun
  RFC 6901 seccion 4), evalua el registro cerrado de nueve operadores
  (`EQ, NE, EXISTS, NOT_EXISTS, GT, GTE, LT, LTE, ONE_OF`) sin `eval` y sin
  coercion de tipos (incluye rechazo explicito de `bool` como operando
  numerico), y emite `tvp3d.qa.report/2.0.0`
  (`suite_id=PARITY_TVP_772`, `profile=LEGACY_TVP_772`). Confirmado por
  `grep` que el archivo no contiene ningun valor especifico de fixture.
- Auto-prueba en memoria (`--selftest`): 46/46 comprobaciones `OK`, codigo de
  salida 0. Nunca escribe un archivo malformado versionado.
- Replay contra las tres observaciones grabadas:
  `PARITY-DEATH-CORPSE-001 PASS`, `PARITY-DEATH-REENTRY-001 PASS`,
  `PARITY-MONSTER-CORPSE-001 PASS`, `PARITY-LOOT-RANDOMNESS-001 NOT_RUN`;
  codigo de salida `0`. Ejecutado dos veces: reporte
  `qa/parity/reports/replay_recorded_death_corpse_loot_report.json`
  byte-identico entre corridas (confirmado con `diff`).
- Prueba de mutacion deliberada: se corrompio temporalmente
  `parity-monster-corpse-001.observation.json`, el replay reporto `FAIL`
  con codigo `1`, y el archivo se restauro byte-a-byte antes de cualquier
  commit (hash `sha256` identico antes/despues).
- Captura en vivo de `PARITY-MONSTER-CORPSE-001`: **no ejecutada, `BLOCKED`**.
  Dos prerequisitos ausentes de forma independiente: el motor de Docker
  esta inalcanzable (`docker ps` fallo de inmediato, motor apagado, no el
  problema de puente WSL con motor vivo de turnos anteriores) y las
  variables de entorno `TVP772_ACCOUNT`/`TVP772_PASSWORD`/
  `TVP772_GOD_CHARACTER` no estan definidas. No se fabrico ninguna
  observacion `LIVE_ORACLE`, no se reetiqueto la observacion grabada como
  si fuera en vivo, no se reporto `PASS`, y no se creo
  `qa/parity/reports/replay_live_monster_corpse_report.json` (no hay
  observacion real que replayar). `cliente3d/red/`, `estado_mundo.gd` y
  `conexion772.gd` no se tocaron; `prueba_muerte_loot_vivo.gd` tampoco se
  modifico.
- Ningun jugador murio en este turno (cero ejecuciones de la corrida
  completa de duelo); no se ejecuto TVP/Docker en absoluto.
- Ninguna credencial se escribio, imprimio ni copio a ningun archivo nuevo.

## Conteos (Phase 2B.1)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.1`) | 198 | 0 (sin cambio) |
| Corpus piloto `LEGACY_PARITY` (Phase 2A, sin cambio) | 4 | 4 |
| Casos de replay `QACaseV2`/`ParityExpectationV1` (este turno) | 4 | 4 (3 `SINGLE_OBSERVATION` / 1 `EVIDENCE_ONLY`) |
| Observaciones `RECORDED_EVIDENCE` | 3 | 3 |
| Observaciones `LIVE_ORACLE` frescas | 1 (planeada) | 0 (`BLOCKED`) |

Estos conteos no se combinan entre si: replayar paridad legacy no
materializa ninguna obligacion de contrato Architecture V2.

**Le toca:** un turno futuro con Docker y credenciales `TVP772_*`
disponibles puede ejecutar la captura en vivo documentada en
`docs/qa/PARITY_PHASE2B1_CAPTURE_REPLAY.md` y, por separado, investigar el
caveat de desalineamiento de mapa `0x64`.

## Turno cerrado: QA 2.1.1 — Erratum de conteo de operadores de replay

- `qa 2.1.0` publico correctamente el registro normativo de nueve
  operadores en la seccion 16C (`EQ, NE, EXISTS, NOT_EXISTS, GT, GTE, LT,
  LTE, ONE_OF`). Una frase descriptiva (la fila `2.1.0` de "Historial de
  contrato de qa") decia "8 operadores" por error de conteo; el evento de
  publicacion de aquel turno en `worklog/EVENTS.jsonl` repitio el mismo
  error descriptivo.
- `qa 2.1.1` corrige unicamente esa frase descriptiva a "9 operadores" y
  agrega su propia fila al historial. **No cambio ningun operador, schema
  ni semantica de replay.** El registro de la seccion 16C es byte-a-byte el
  mismo que en `2.1.0`.
- La linea historica de `worklog/EVENTS.jsonl` que dice "8 operadores
  deterministicos" NO se reescribio: es un evento append-only y se preserva
  tal cual, con una nueva linea de aclaracion agregada a continuacion.
- Sin cambio de conteos: obligaciones Architecture V2 siguen en 198
  especificadas / 0 materializadas; corpus piloto `LEGACY_PARITY` sigue en
  4 fixtures materializados. Ninguna ejecucion fresca de TVP/Docker en este
  turno; ningun archivo bajo `qa/` ni `docs/qa/` se toco.
- **Phase 2B.1 sigue siendo la siguiente tarea de implementacion** (captura/
  replay controlada de TVP contra el boundary publicado en `2.1.0`), no
  ejecutada en este turno.

## Turno cerrado: Phase 2B.0 — Boundary de replay de oracle legacy

Turno contract-only puro: no se creo ni ejecuto ningun archivo bajo `qa/` ni
`docs/qa/`, no se toco Docker/TVP, y los cuatro fixtures/harness de Phase 2A
quedan exactamente iguales.

- Publicado `qa 2.1.0` (extension minor): agrega `OracleObservationV1`
  (`tvp3d.qa.oracle_observation/1.0.0`, nueva identidad de schema) y
  `ParityExpectationV1` (`tvp3d.qa.parity_expectation/1.0.0`, nueva
  identidad de schema), secciones 16A-16F.
- `capture_origin` cerrado `LIVE_ORACLE|RECORDED_EVIDENCE`; ninguno implica
  `PASS`. Frontera explicita captura cruda (nunca versionada automaticamente)
  vs observacion normalizada (segura, versionable tras redaccion de
  secretos/paths/diagnosticos volatiles).
- `mode` cerrado `SINGLE_OBSERVATION|EVIDENCE_ONLY`. Registro de 8
  operadores deterministicos (`EQ,NE,EXISTS,NOT_EXISTS,GT,GTE,LT,LTE,ONE_OF`)
  sobre JSON Pointer RFC 6901; sin `eval`, sin expresiones arbitrarias. El
  comparador generico no puede contener ningun valor especifico de fixture.
- Reuso exacto de `tvp3d.qa.case/2.0.0` y `tvp3d.qa.report/2.0.0` para
  replay, sin publicar un tercer schema de caso ni un segundo de reporte.
  Congelada la regla `QACaseV2.case_id == ParityFixtureV2.fixture_id`;
  confirmado sin contradiccion contra la grammar de `case_id` ya publicada
  (el prefijo `PARITY` ya estaba reservado en la seccion 3.1).
- `tvp3d.qa.error` avanza `2.0.0 -> 2.1.0` (mismo patron que
  `modelo-comun 2.1.0` para `tvp3d.domain_error`) solo para agregar
  `QA_OBSERVATION_INVALID`; sus campos/tipos/rangos no cambian.
- Documentado el mapeo (sin modificar los archivos) de los cuatro fixtures
  de Phase 2A: `PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001` y
  `PARITY-MONSTER-CORPSE-001` quedan replayables como `SINGLE_OBSERVATION`;
  `PARITY-LOOT-RANDOMNESS-001` permanece `EVIDENCE_ONLY` (una sola tirada de
  loot no prueba no-determinismo; no se inventa un requisito estadistico).
- El caveat de desalineamiento de mapa `0x64` se mantiene fuera del boundary
  de replay, sin promoverse a regla de oracle autoritativa.
- `ParityFixtureV2 2.0.0`, `tvp3d.qa.case/2.0.0` y `tvp3d.qa.report/2.0.0`
  no cambiaron de forma ni significado. Los cuatro fixtures de Phase 2A y su
  harness (`qa/parity/tools/validate_pilot.py`) no se tocaron.

## Conteos (sin cambio en este turno)

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.1.0`) | 198 | 0 |
| Corpus piloto `LEGACY_PARITY` Phase 2 | 4 | 4 (sin cambio; ningun fixture nuevo este turno) |

## Verificacion de cierre Phase 2B.0

- 10 bloques JSON del contrato parsean.
- `tvp3d.qa.parity_fixture`, `tvp3d.qa.case` y `tvp3d.qa.report` permanecen
  en `2.0.0`; `tvp3d.qa.oracle_observation` y `tvp3d.qa.parity_expectation`
  son identidades nuevas en `1.0.0`; `tvp3d.qa.error` avanza a `2.1.0`.
- Ningun archivo bajo `qa/` o `docs/qa/` fue creado, modificado ni
  ejecutado; los 4 fixtures de Phase 2A y `validate_pilot.py` quedan
  byte-identicos.
- No se inicio Docker/TVP; no se conecto a ninguna cuenta legacy.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo cambiaron `worklog/qa/CONTRATO.md`, `worklog/qa/STATE.md` y el diario
  append-only; ningun otro `CONTRATO.md`/`STATE.md`, `CARRILES.md`,
  `MASTER_PLAN.md` ni codigo de produccion se toco.
- Ninguna linea historica de `worklog/EVENTS.jsonl` fue reescrita.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Turno cerrado: Phase 2A — Piloto LEGACY_PARITY (muerte/corpse/reentrada/loot)

Primer turno real de materializacion Phase 2. Contract-only en lo que toca a
`qa 2.0.1` (no se modifico `worklog/qa/CONTRATO.md`); este turno SI crea
archivos QA-owned bajo `qa/` y `docs/qa/`, autorizado explicitamente por el
alcance de esta fase.

- Materializados cuatro fixtures `LEGACY_PARITY` (`tvp3d.qa.parity_fixture/2.0.0`,
  ya publicado por `qa 2.0.1`, sin cambios de schema) a partir de evidencia ya
  grabada en `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`:
  `PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001`,
  `PARITY-MONSTER-CORPSE-001`, `PARITY-LOOT-RANDOMNESS-001`. Los cuatro
  clasificados `MATCH_EXPECTED`.
- Archivos: `qa/parity/fixtures/tvp772/death_corpse_loot/*.json` (cuatro
  fixtures + `manifest.json` de metadata propia de QA, no un contrato
  nuevo), harness `qa/parity/tools/validate_pilot.py` (Python 3, solo
  libreria estandar), reporte deterministico
  `qa/parity/reports/pilot_death_corpse_loot_report.json`, y nota de
  hallazgos `docs/qa/PARITY_PHASE2_PILOT_DEATH_CORPSE_LOOT.md`.
- El heuristico de deteccion de muerte por cliente ("`0x6C` de `mi_id`
  siempre alcanza por si solo") **no** se codifico como verdad autoritativa:
  el propio documento fuente lo muestra como una condicion de carrera
  corregida despues por `protocolo-red 1.2.0`. El fixture de muerte captura
  solo el resultado autoritativo (corpse `dead human` + vida cero).
- El desalineamiento de mapa `0x64` observado en una corrida completa
  **no** se promovio a comportamiento autoritativo de TVP ni a
  `KNOWN_LEGACY_BUG`: `PARITY-MONSTER-CORPSE-001` usa exclusivamente las
  corridas `--solo-loot`, no afectadas por ese problema. El caveat queda
  documentado como investigacion de paridad futura, no como hallazgo de
  este piloto.
- El contenido exacto de loot (`gold coin x3`, `x4`, `cheese x1`, vacio)
  quedo en `excluded_nondeterministic_fields` de `PARITY-LOOT-RANDOMNESS-001`;
  la regla estable capturada es "el servidor decide, el cliente muestra",
  clasificada `MATCH_EXPECTED` porque el fixture representa esa regla de
  no-determinismo, no un valor de loot especifico.
- Harness ejecutado dos veces sobre el mismo estado de repositorio: reporte
  byte-identico ambas veces, codigo de salida 0. Auto-prueba negativa
  (`--selftest`) ejercito 11 documentos malformados en memoria y confirmo
  que el validador rechaza a los 11, sin escribir ningun archivo malformado
  versionado. Ademas se corrompio temporalmente un fixture real
  (clasificacion invalida), se confirmo codigo de salida 1, y se restauro su
  contenido original byte a byte antes de este commit.
- **Cero ejecuciones frescas de TVP/Docker en este turno.** No se inicio
  Docker, no se conecto a ninguna cuenta, no se ejecuto
  `prueba_muerte_loot_vivo.tscn`, no se mato a Valentino, no se mutó
  persistencia legacy y no se requirio `servidor/key.pem` ni ninguna otra
  credencial.

## Conteos separados (Phase 2A)

**Estos dos inventarios NO se combinan:**

| Inventario | Especificadas | Materializadas |
|---|---:|---:|
| Obligaciones de contrato Architecture V2 (`qa 2.0.1`) | **198** | **0** (sin cambio por este turno) |
| Corpus piloto `LEGACY_PARITY` Phase 2 | 4 | 4 (validadas localmente contra evidencia grabada; 0 ejecuciones frescas de oracle) |

## Verificacion de cierre Phase 2A

- 4 fixtures + 1 manifest parsean como JSON UTF-8 valido.
- Los cuatro fixtures usan exactamente `tvp3d.qa.parity_fixture/2.0.0`,
  `oracle=TVP_772`, `oracle_version=7.72`, y `fixture_id` unicos.
- Los cuatro `source_evidence.logical_path` son relativos al repositorio y
  resuelven a `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`, que existe.
- Ningun literal con forma de secreto/credencial en ningun fixture ni en el
  harness.
- El contenido exacto de loot queda excluido de la comparacion
  deterministica; el comportamiento de contenedor si se compara.
- El heuristico de muerte superseded y el desalineamiento de mapa NO quedan
  codificados como verdad autoritativa vigente.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo se tocaron rutas QA-owned (`qa/`, `docs/qa/`,
  `worklog/qa/STATE.md`) y el diario append-only; `worklog/qa/CONTRATO.md`,
  cualquier otro `CONTRATO.md`/`STATE.md`, `CARRILES.md`,
  `docs/tibia3d/MASTER_PLAN.md`, y codigo de produccion de
  servidor/cliente/editor/integracion quedan intactos.
- Ninguna linea historica de `worklog/EVENTS.jsonl` fue reescrita.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.
- `FULL_NATIVE_PLAYABLE` sigue `BLOCKED`; los dominios especializados
  faltantes (Authentication/Application Session, Map/World Rules, Combat,
  Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
  Monster3D final) quedan exactamente igual. Este piloto de evidencia legacy
  no desbloquea gameplay ni afirma paridad del servidor nativo V2.

## Turno cerrado: QA 2.0.1 — Erratum de conteo de cobertura

- `docs/tibia3d/PHASE1_CLOSURE_REVIEW.md` (revision de cierre de Phase 1,
  seccion 6) recalculo la matriz de cobertura de `qa 2.0.0` directamente
  desde los siete contratos fuente y encontro que el total publicado, 194,
  no era reproducible. Este turno recontó de forma independiente antes de
  corregir nada, con el mismo resultado.
- **Conteo verificado de forma independiente en este turno** (recalculado
  desde cada `CONTRATO.md`, no copiado de la revision de cierre):

  | Contrato | 2.0.0 (incorrecto) | 2.0.1 (verificado) |
  |---|---:|---:|
  | `modelo-comun` | 41 | **42** |
  | `protocolo-red` | 20 | 20 |
  | `assets` | 12 | **13** |
  | `servidor` | 35 | **37** (23 base + 14 Phase 1D.4, no 21+14) |
  | `cliente` | 26 | 26 |
  | `editor` | 21 | 21 |
  | `integracion` | 39 | 39 |
  | **Total** | **194** | **198** |

- Corregido `worklog/qa/CONTRATO.md` seccion 5 (tabla y texto de resumen) a
  los conteos verificados, y agregada la subseccion "Erratum de conteo
  2.0.1" documentando exactamente que filas cambiaron y por que. Corregida
  tambien la referencia de la seccion 20 ("Sin reclamos de ejecucion").
- **El total materializado sigue siendo 0.** Este turno NO creo, ejecuto ni
  modifico ningun `QACaseV2`, fixture de paridad, prueba ejecutable ni
  archivo bajo `cliente3d/pruebas/`, `qa/` o `docs/qa/`. No se inicio Docker,
  TVP ni Phase 2.
- Sin cambio de taxonomia/schema: `TestClassV2`, `QAResultStatusV2`
  (`PASS/FAIL/BLOCKED/NOT_RUN`), los codigos de salida (0/1/2/3), los cuatro
  `SuiteProfileV2` y los cuatro schemas `tvp3d.qa.case/2.0.0`,
  `tvp3d.qa.report/2.0.0`, `tvp3d.qa.parity_fixture/2.0.0` y
  `tvp3d.qa.error/2.0.0` quedan exactamente iguales a `2.0.0`.
- `FULL_NATIVE_PLAYABLE` sigue `BLOCKED`; los dominios especializados
  faltantes (Authentication/Application Session, Map/World Rules, Combat,
  Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
  Monster3D final) quedan exactamente igual que en `2.0.0`. Este parche
  aritmetico no desbloquea nada de gameplay.
- El turno historico `Phase 1H` (mas abajo) reporto honestamente 194 porque
  era lo que su propio conteo (con el error aritmetico) producia en ese
  momento; ese texto NO se reescribe para aparentar que ya sabia 198. La
  correccion queda documentada aqui, como turno posterior explicito.
- **Phase 2 queda limpia del defecto de conteo QA.** Este turno NO
  materializo el primer fixture de paridad; esa es la recomendacion para el
  proximo turno de `qa` (piloto pequeno sobre `LEGACY_PARITY`, por ejemplo el
  flujo de muerte/corpse/loot que ya tiene evidencia viva documentada en
  `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`), no ejecutada en este turno.

## Verificacion de cierre QA 2.0.1

- 5 bloques JSON del contrato parsean (mismo total que 2.0.0; ningun schema
  cambio de forma).
- `42 + 20 + 13 + 37 + 26 + 21 + 39 = 198` verificado por suma directa.
- Los cuatro schemas `tvp3d.qa.*` permanecen en `2.0.0`.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo `worklog/qa/CONTRATO.md`, `worklog/qa/STATE.md` y el diario
  append-only cambiaron; ningun otro contrato/estado de carril, prueba
  ejecutable, `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni codigo de produccion
  se tocaron.
- Ninguna linea historica de `worklog/EVENTS.jsonl` fue reescrita; las dos
  lineas malformadas historicas (140-141) permanecen intactas.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Turno cerrado: Phase 1H — QA V2 Contract / Test Taxonomy

- Publicado QA V2 `2.0.0` (major) sobre los siete contratos Architecture V2
  vigentes: `modelo-comun 2.1.0`, `protocolo-red 2.1.0`, `assets 2.0.0`,
  `servidor 2.1.0`, `cliente 2.0.0`, `editor 2.0.0`, `integracion 2.0.1`.
- Publicada `TestClassV2` (`CONTRACT_FIXTURE`, `NATIVE_INTEGRATION`,
  `LEGACY_PARITY`, `LEGACY_LIVE_MUTATING`), `QACaseV2`
  (`tvp3d.qa.case/2.0.0`), `QAReportV2` (`tvp3d.qa.report/2.0.0`),
  `QAResultStatusV2` (`PASS/FAIL/BLOCKED/NOT_RUN`, con `BLOCKED`/`NOT_RUN`
  explicitamente distintos de `PASS`), codigos de salida de suite (0/1/2/3)
  y cuatro `SuiteProfileV2` (`CONTRACT_V2`, `NATIVE_SMOKE_V2`,
  `PARITY_TVP_772`, `LEGACY_LIVE_MANUAL`).
- Reconstruida la matriz de cobertura leyendo los siete contratos: **194
  obligaciones de fixture especificadas, 0 materializadas.** Ver detalle por
  contrato en `CONTRATO.md` seccion 5.
- Publicados 9 invariantes cruzados con `case_id` estable (`XCUT-*`):
  scope runtime, `READY != AUTHORIZED != ACTIVE`, footprint != visual,
  `CanonicalDomainId` != id legacy, cadena de replicacion neutral,
  coincidencia de `common_domain_version` nativo, `SourceBindingV2` del
  editor, ausencia de secretos, TVP/TFS como oracle no autoridad.
- Representados explicitamente como `BLOCKED`/`CONTRACT_NOT_PUBLISHED`:
  Authentication/Application Session, Map/World Rules, Combat,
  Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
  Monster3D final. Ninguna prueba fue inventada para ellos.
- Declarado explicitamente: `FULL_NATIVE_PLAYABLE` NO es una suite que pase
  hoy; bloqueada como minimo por Authentication/Application Session y
  Map/World Rules. Movimiento por teclado/login/combate/gameplay de
  prototipo NO se certifican como aceptacion V2.
- Publicado el boundary `ParityFixtureV2` (`tvp3d.qa.parity_fixture/2.0.0`)
  para Phase 2, sin materializar el corpus completo, y el principio de que
  la paridad TVP es evidencia (`BUG|DEBT|DELIBERATE_CHANGE`), no
  especificacion V2 automatica.
- Documentada la distincion `QAReportV2.status=PASS` (ejecucion) vs
  veredicto `HECHO` de `revisar-carril` (Definicion de Hecho completa): no
  son identicos.
- QA 1.4.0 preservado integro bajo
  `HISTORICAL / SUPERSEDED — QA 1.4.0 y anteriores`, con cada seccion
  reclasificada explicitamente `LEGACY_PARITY` o `LEGACY_LIVE_MUTATING`.
- No se implemento ninguna prueba ejecutable, no se modifico
  `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni codigo de otro carril, no se
  inicio Docker y no se ejecuto ninguna prueba viva mutante este turno.

## Reclasificacion del bloqueo historico Docker/casas-camas

El bloqueo `Estado: BLOQUEADO` que encabezaba este archivo (retest de
`prueba_casa_cama_vivo.tscn` atascado por perdida de contexto Docker, con
`owner`/`premium` pendientes de confirmar en `0`) es un bloqueo de una
certificacion `LEGACY_LIVE_MUTATING` especifica (casas/camas TVP 7.72), NO
un bloqueo para publicar el contrato QA V2 de Architecture V2. Se reclasifica
aqui explicitamente sin borrar el texto original, que queda integro debajo
como evidencia operativa. La prueba de casas/camas SIGUE sin certificarse;
esta reclasificacion no reporta que paso.

## Verificacion de cierre Phase 1H

- 5 bloques JSON del contrato (`QACaseV2`, referencia de contrato,
  `QAReportV2`, `QAErrorV2`, `ParityFixtureV2`) parsean.
- Los eventos agregados son lineas JSON validas y solo se anexaron al final.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo contrato/estado de `qa` y el diario append-only forman parte del
  cierre; los cambios sucios ajenos detectados al inicio quedan intactos.
- No se modificaron `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni contratos de
  otro carril.
- Ninguna dependencia normativa apunta a un contrato futuro no publicado;
  su ausencia esta representada como `BLOCKED`.
- `FULL_NATIVE_PLAYABLE` queda declarado bloqueado, no aprobado.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Depende de

- `modelo-comun` 2.1.0: contrato publicado.
- `protocolo-red` 2.1.0: contrato publicado.
- `assets` 2.0.0: contrato publicado.
- `servidor` 2.1.0: contrato publicado.
- `cliente` 2.0.0: contrato publicado.
- `editor` 2.0.0: contrato publicado.
- `integracion` 2.0.1: contrato publicado.

## Le toca

Materializar progresivamente las 198 obligaciones especificadas (conteo
corregido en `2.0.1`; ver "Turno cerrado: QA 2.0.1" arriba)
(`SPECIFIED_NOT_MATERIALIZED -> MATERIALIZED`) a medida que exista
implementacion nativa que probar, y mantener `FULL_NATIVE_PLAYABLE` honesto
hasta que Authentication/Application Session y Map/World Rules se publiquen.

Para el corpus Phase 2 `LEGACY_PARITY`: el piloto de 4 fixtures
(muerte/corpse/reentrada/loot, ver "Turno cerrado: Phase 2A" arriba) valido
el flujo completo fixture+harness contra evidencia ya grabada, y
`qa 2.1.0` (ver "Turno cerrado: Phase 2B.0" arriba) publico el boundary
maquina-legible (`OracleObservationV1`/`ParityExpectationV1`) que faltaba
para comparar una observacion fresca sin hardcodear semantica en codigo.

Siguiente tarea exacta (no ejecutada en este turno): **Phase 2B.1** —
implementar captura/replay controlada de TVP contra el boundary recien
publicado, produciendo `OracleObservationV1` reales para
`PARITY-DEATH-CORPSE-001`, `PARITY-DEATH-REENTRY-001` y
`PARITY-MONSTER-CORPSE-001` (los tres `SINGLE_OBSERVATION`), y evaluandolas
con el comparador generico de la seccion 16C. `PARITY-LOOT-RANDOMNESS-001`
permanece `EVIDENCE_ONLY` hasta que exista una extension de comparacion
multi-muestra/estocastica. Por separado, investigar el caveat de
desalineamiento de mapa documentado en
`docs/qa/PARITY_PHASE2_PILOT_DEATH_CORPSE_LOOT.md`. Recien despues de
validar ese flujo conviene escalar al resto del corpus de paridad.

Nota de cierre historica (turno anterior): el commit local `31db317`
contiene aquel cierre; `git push` quedo bloqueado por falta de conexion a
`github.com:443`.

## Hecho

- Casas/camas: se inspecciono la casa 6 (Sunset Homes, Flat 01), con camas
  reales en `(32329,32230,7)` y entrada `(32333,32232,7)`. La prueba viva
  `prueba_casa_cama_vivo.tscn` deja el propietario y la cuenta premium
  restaurados, pero TVP responde `You cannot use this object` al usar la cama
  desde el interior. No se certifica dormir/despertar ni persistencia hasta
  resolver la condicion autoritativa de uso (zona PZ/permisos); queda como
  bloqueo reproducible, no como aprobado parcial.

- Cierre versionado en `24c9ab7` y publicado en `origin/main`; `git diff
  --check` pasa y los eventos JSON son validos.
- Correccion preparada en `servidor/src/iomap.cpp`: el cargador TVP ahora usa
  `House::addTile`, que registra camas y marca las casillas de casa como PZ.
  Commit `5dcdabc` publicado. Falta repetir la prueba viva cuando Docker
  Desktop vuelva a exponer su socket.
- Retest parcial tras reiniciar Docker: `/tileinfo 32328,32230,7` devuelve
  `flagPZ=true`, confirmando el efecto del arreglo. La corrida completa se
  atasco en login despues de multiples sesiones previas; owner y premium fueron
  restaurados a `0`. Accion concreta: ejecutar una corrida limpia con el servidor
  recien iniciado y sin sesiones residuales.
- Atención operativa: la última preparación de la prueba dejó pendiente
  confirmar/restaurar `houses.id=6.owner` y el `premium_ends_at` de la cuenta
  del `QA_GOD_OPERATOR`
  porque el motor Docker cayó antes de la limpieza. Restaurar ambos a `0` antes
  de cualquier otra prueba.

- Andamiaje creado.
- Publicado el contrato de QA v1.0.0.
- Ejecutada paridad IR vs estado vivo: 81 tiles coincidentes, 0 diferencias,
  1 criatura ignorada.
- Validada escalera real en TVP: z7 -> z6 -> z7, dos posiciones recibidas por
  0x64, personaje restaurado; `EstadoMundo` tambien expone 0xBE/0xBF si el
  servidor usa esos paquetes.
- Integrado inspector conectado en `mundo3d.gd`: seleccion por Shift+click,
  toggle F4, stack vivo y flags/metadatos IR por chunks; escena principal carga
  en headless sin errores.
- Runner local en `pruebas/matriz_qa_local.gd` ejecuta la checklist en procesos
  Godot separados y escribe `generated/reports/qa_matrix_local.json`.
- Matriz local ejecutada 6/6: coordenadas, controles, formas, chunks, modelo
  de proyecto y escena del editor pasan.
- Reporte versionado en `generated/reports/qa_matrix_local.json`.
- Regresion de spells y animaciones ejecutada 0 fallas: catalogo JSON, outfit
  multiframe, efectos/proyectiles importados, eventos `0x83`-`0x85`, cambio de
  outfit `0x8E`, alineacion del siguiente mensaje y lanzamiento por `0x96`.
- Matriz local ampliada y ejecutada 7/7 con `prueba_spells_animaciones.tscn`.
- Magic Wall de 3DTIBIA integrada con sus seis PNG originales, cubo 1x2x1 y
  animacion de tres fases a 5 FPS para los client ids 2128/2129.
- `prueba_magic_wall.tscn` verifica texturas, animacion y reemplazo seguro de
  una instancia dinamica; matriz local ejecutada 8/8.
- El picking de puertas simples usa la proyeccion vertical de la camara para
  uso/mirar; las variantes con llave, nivel, mision o sellado quedan fuera.
- Se agregaron regresiones para puertas simples/parametrizadas; la matriz local
  termina 9/9 y el login real contra TVP responde correctamente.
- El servidor reconstruido conserva la regeneracion otorgada por equipo dentro
  de proteccion: Guuille, con life ring en la ranura 9, paso de 157 a 160 de
  vida y de 1079 a 1082 de mana durante una medicion real de 7 segundos.
- Publicada `docs/qa/PARIDAD_772_2026-08-29.md`: matriz global basada en el
  servidor autoritativo que separa COMPROBADO, PARCIAL y AUSENTE.
- Validado el checkpoint actual en ocho procesos Godot: contenedores/canales,
  controles, eventos/trade, modelos authored, formas, spells, escena principal
  y escaneo de editor terminaron con codigo cero.
- `prueba_muerte_reentrada` adoptada en la matriz local: 10/10 OK y reporte
  regenerado.
- Prueba viva de muerte, corpse y loot ejecutada contra el servidor TVP:
  un demon invocado con `/m` mato al personaje, el servidor dejo el corpse
  `dead human`, el `0x6C` de `mi_id` con vida cero emitio la muerte, el
  logout `0x14` termino la sesion y el reingreso devolvio un personaje vivo
  en su templo.
- Mitad de corpse y loot repetible sola con `--solo-loot`: dos corridas
  independientes abrieron el corpse `dead rat` y leyeron loot distinto
  (`gold coin x3` y `x4`), que es el que decide el servidor.
- Evidencia, etapas, limites y efectos publicados en
  `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`; matriz global actualizada.
- La precondicion del duelo ya no es manual: el god va al campo y trae al
  personaje con `/c`, la talkaction del servidor. El cliente no camina ni
  simula intenciones, y la confirmacion la da la posicion autoritativa de la
  propia sesion del personaje.
- La prueba abre dos sesiones simultaneas (personaje y god) y respeta
  `Ban::acceptConnection`: un solo login por corrida y seis segundos entre
  sesiones nuevas.
- Modo `--solo-campo`: prueba solo la precondicion, retira el verdugo antes de
  que mate a nadie y devuelve el personaje a su templo con `omani`. Cinco
  comprobaciones en verde y codigo cero, repetible sin costo.
- `--solo-loot` sigue en verde y ahora distingue su propia rata por id nuevo y
  su corpse por casilla que no tenia corpse antes de la caza; el campo tiene
  ratas salvajes y restos de corridas viejas.
- `prueba_estado_criatura_ui` adoptada en `matriz_qa_local.gd`, que termina
  11/11 OK.
- La matriz local incorpora los self-tests de estado de criatura y mapa 7.72;
  termina 13/13 OK con codigo cero.
- Dos corridas vivas posteriores a `protocolo-red` 1.2.0 confirmaron muerte,
  logout `0x14`, cierre de sesion, reingreso vivo y corpse `dead rat` abierto
  con loot real (`cheese x1` y `gold coin x3`). La carrera de muerte queda
  cerrada.
- `pila: ?` queda corregido como diagnostico: no falta un nombre de assets. El
  `0x64` vivo deja al jugador fuera de `mi_pos` y reinterpreta bytes siguientes
  como ids imposibles. La prueba conserva el detalle y no acusa al servidor de
  omitir un corpse cuando `mapa_alineado` es falso.
- Prueba viva de VIP y trade ejecutada con dos sesiones reales. El god hizo
  remove/add de Valentino por nombre, recibio GUID 2 offline, online al entrar
  y offline al salir.
- El trade vivo preparo dos server id 2006/client id 2874, recibio oferta
  propia y contraparte en ambos clientes, acepto desde los dos sockets y
  comprobo las actualizaciones de inventario de la transferencia. Corrida
  final: codigo 0, 10 comprobaciones en verde.
- Publicado `docs/qa/PRUEBA_VIVA_TRADE_VIP.md` y contrato QA 1.2.0 con el
  comando, mutaciones, evidencia y limite de produccion encontrado.
- Repetida la certificacion con `Son Goku` (GUID 16) desde su otra cuenta:
  codigo 0, VIP y transferencia completos. La asociacion temporal a la cuenta
  de pruebas se restauro en `finally` y la prueba queda parametrizada sin
  imprimir claves.

- Party viva con dos clientes: `pruebas/prueba_party_viva.tscn` recorrio
  invitar, unirse, pasar liderazgo y salir contra el servidor, y los escudos
  de las dos sesiones contaron la misma party en cada paso. Ocho
  comprobaciones en verde y codigo cero, sin costo para ningun personaje.
- Evidencia y limites en `docs/qa/PRUEBA_VIVA_PARTY.md`; la fila de party de la
  matriz global pasa a COMPROBADO.
- La matriz local adopta `party_ui`, `party_protocolo` y `mapa_captura`, y
  termina 16/16 OK.
- La prueba viva de trade dejo de armar el `0x7D` a mano: usa el metodo que
  publico `protocolo-red` 1.5.0 y volvio a pasar entera contra el servidor.
- Depot probado en vivo: `pruebas/prueba_depot_vivo.tscn` guarda un objeto,
  cierra la sesion, vuelve a entrar y el objeto sigue en el `depot chest`.
  Seis comprobaciones en verde y codigo cero, sin tocar las cosas de nadie.
- Tres reglas de esta rama que no eran obvias quedaron escritas en
  `docs/qa/PRUEBA_VIVA_DEPOT.md`: hay que PISAR la baldosa para que el servidor
  cargue el depot del jugador, las cosas viven en el `depot chest` de adentro
  del locker, y la ventana de contenedor la elige el cliente en el `0x82`.
  Sin pisar la baldosa se abre el mueble del mapa, que acepta objetos y no es
  de nadie: es la trampa mas facil del recorrido.
- La fila de la matriz global se parte en dos: `Depot` pasa a COMPROBADO y
  `Mail/parcels` queda BLOQUEADO por el servidor.
- Correccion: el depot probado es el de **Thais**, no el de Rookgaard. Los
  personajes de prueba salen en el templo de Thais `(32369,32241,7)` y su
  depot esta a quince casillas. Rookgaard no tiene depot ni correo, igual que
  en el Tibia original.
- Prueba viva de parcel y mailbox escrita y corriendo en Thais. Se traba
  siempre en el mismo punto y con la causa localizada: al usar una etiqueta el
  servidor contesta `You cannot use this object` por la guarda de
  `game.cpp:2556-2560`. Evidencia en `docs/qa/PRUEBA_VIVA_PARCEL.md`.
- Correccion compensatoria: el servidor ya deja usar la etiqueta y el usuario
  confirmo que la parcel llega al depot del destinatario. Los archivos vivos
  conservan parcels dirigidas dentro de depot 1; mail/parcels pasa a
  COMPROBADO sin repetir la prueba mutante.
- `prueba_reacquisicion_monstruo.tscn` certifica el cambio compilado de
  `monster.cpp`: un `cave rat` identificado golpeo, el servidor movio al
  personaje 39 SQM fuera de vista y, al devolverlo, el mismo id retomo el
  ataque. Corrida final: vida 133 -> 131 -> salida/regreso -> 128, mismo id y
  limpieza confirmada, codigo 0.
- La prueba descarto una primera corrida donde los golpes eran de un `spider`
  silvestre y endurecio el oracle: solo cuenta dano cuyo mensaje nombra al
  monstruo invocado. Evidencia en
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`.
- La matriz local se repitio despues del cambio y termino 17/17 OK.

## Falta

- Completar matriz de red de todos los recorridos y errores contra un servidor
  legacy disponible.
- Repetir la checklist desde un clon limpio para la prueba de entrega.
- Probar en vivo el camino de produccion que inicia trade desde el menu de la
  criatura y luego selecciona el objeto.
- En la prueba viva de muerte, el unico fallo que queda es la limpieza del
  demon con `/killall`, que solo alcanza el cuadro alrededor de quien lo dice.
- Casas/camas: permisos, dormir/despertar y persistencia real contra la
  autoridad del servidor.
- Las corridas fallidas del depot dejaron dos parcels del god dentro del
  mueble del mapa en `(32354,32231,7)`. No rompen nada pero estan ahi.

## Bloqueos activos

- ATENDIDA el 2026-08-29: el `0x64` desalineado. `protocolo-red` 1.3.0
  encontro la causa con el OTBM como oraculo —una casilla que existe y se
  describe con cero bytes deja dos marcas pegadas— y dejo la captura real como
  regresion. El mapa vivo del campo entrega ahora las 356 casillas que dice el
  OTBM, con el jugador en la suya.
- ATENDIDA el 2026-08-29: el `0x7D` saliente. `protocolo-red` 1.5.0 lo publico
  con el atajo de inventario y la prueba viva ya lo usa en vez de armar los
  bytes. `cliente` 1.4.0 ya lo ofrece; falta la prueba viva que empieza en ese
  menu.
- La prueba manual de puertas y runas sigue pendiente; la prueba automatizada
  del life ring ya pasa contra el servidor reconstruido.
- ATENDIDA el 2026-08-29: reacquisicion de monstruos. El servidor ya estaba
  reconstruido y la prueba viva por salida/regreso de la ventana termino en
  codigo cero con el mismo id de criatura.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Las pruebas de fecha usan reloj fijado | Evita que fallen con el paso de los meses | si |
| La prueba viva no camina al personaje para salir del templo | Caminar a ciegas no sale de la zona de proteccion y un auto-walk inventado seria la intencion de cliente que la prueba no debe simular | si |
| Al personaje lo saca del templo el servidor con `/c`, no el cliente | Es una talkaction del propio servidor: mueve a la criatura a la casilla libre mas cercana al god y el cliente solo mira donde lo dejaron | si |
| La prueba mantiene dos sesiones simultaneas | El `/c` solo alcanza a un personaje conectado, y asi el duelo no necesita relogueos | si |
| El god no se teletransporta encima de un monstruo vivo | El empujon del teleport deja la casilla en un estado que la prueba lee mal; sobre un corpse si puede pararse | si |
| El duelo ocurre siempre en la misma casilla de campo | Es la unica comprobada fuera de zona de proteccion, y asi la corrida no depende de donde quedo nadie | si |
| La mitad de corpse y loot se hace siempre en `32082,32145,6` | Es una casilla comprobada fuera de zona de proteccion, asi la media prueba se repite sin depender de donde quedo nadie | si |
| El monstruo del corpse se remata con `/killall` si el cuerpo a cuerpo tarda | El personaje god es nivel 1 y la prueba mide corpse y loot, no el ritmo de combate | si |
| Una pila solo certifica un corpse si `mapa_alineado` es verdadero | Sin el jugador en `mi_pos`, los indices y objetos locales no representan el paquete del servidor | no |
| La prueba viva de trade normaliza las manos y usa dos server id 2006 | El servidor necesita dos ofertas reales para ejecutar `playerAcceptTrade`; el usuario autorizo alterar los personajes de prueba | si |
| QA usa el `0x7D` publicado, no bytes armados a mano | La prueba viva debe cubrir el mismo transporte que usa produccion | no |
| Un golpe de reacquisicion debe nombrar al monstruo invocado | El campo contiene criaturas silvestres; una bajada de vida sola produjo un falso positivo real con un spider | no |
| El fixture de experiencia compartida NO lleva observacion grabada | `PRUEBA_VIVA_PARTY.md:67-74` prueba que ese dominio nunca se ejercito en vivo antes; inventar la evidencia grabada seria fabricarla | no |
| El monstruo de la medicion se identifica por id NUEVO, no por nombre | El campo tiene fauna del mismo tipo; por nombre una rata silvestre llego a recibir una invitacion de party. Ademas evita tener que matar fauna preexistente | no |
| El god queda fuera de la party y nunca golpea al monstruo | Su parte proporcional del dano saldria del pozo de la party (`creature.cpp:375`) y el reparto dejaria de coincidir con la formula; ademas el grupo 6 no gana experiencia | no |
| El refuerzo de los personajes de QA es deliberadamente moderado | Si uno matara al monstruo de un solo golpe, el otro no registraria participacion y el reparto nunca se habilitaria | si |
| Se sube nivel a los personajes de QA pese a que el nivel da experiencia | Se aplica antes de la foto y la medicion es un delta; ademas cada avance cura y saca la vida baja de resaca. A los dos por igual para no romper la regla de nivel | si |
| `sharedExpEnabled` se prueba por comportamiento, no leyendo estado | No viaja por la red: sin habilitar cada atacante cobra proporcional al dano, asi que ganancias iguales y coincidentes con la formula son la evidencia | no |
| La orden de toggle rechazada en combate se registra como asercion | `game.cpp:5097` la descarta en silencio; aparecio como falso fallo y es una regla real del oracle que el servidor nativo debe reproducir | no |
| Una captura reutilizable no puede fabricar sus propias precondiciones | El `/addSkill` automatico servia una vez pero degradaba el entorno en cada corrida: los personajes de QA pasaron de nivel 1 a 25 por reintentos | no |
| El estado actual de los personajes de QA es precondicion, no algo a revertir | No existia instantanea transaccional previa al `+18/+12`; adivinar valores viejos habria sido inventar datos, peor que dejarlos donde estan | no |
| La holgura de vida del preflight es absoluta y no un porcentaje | El dano entrante no escala con el nivel: un porcentaje rechaza a un personaje grande con margen de sobra y acepta a uno chico que no aguanta un combate | si |
| Un requisito que no se cumple se reporta BLOCKED, nunca se fabrica | Es la inversion que define este turno: el harness verifica el entorno en vez de modificarlo para poder pasar | no |

## Notas para quien retome

- La revision cruzada debe hacerla un agente que no haya implementado el
  carril revisado.
- El runner local no arranca servidores ni toca datos persistentes; las
  pruebas de red siguen siendo explícitas y secuenciales.
- La prueba viva SI toca datos persistentes: una corrida completa le cuesta un
  nivel al personaje normal y deja sus objetos en el corpse. Para restaurarlo
  estan la semilla `servidor/docker/data/02-data.sql` y
  `servidor/gamedata/players/`. El 2026-08-29 se ejecutaron cuatro corridas
  completas, asi que Valentino quedo varios niveles abajo.
- Para probar la precondicion sin costo se usa `--solo-campo`. Solo la corrida
  completa mata al personaje.
- En este turno se ejecutaron dos corridas completas adicionales con permiso
  explicito del usuario; ambas terminaron con dos fallas de alineacion, no de
  muerte ni de loot.
- Si una corrida se cuelga y se la mata a mano, conviene esperar antes de la
  siguiente: el servidor todavia considera conectado al personaje y
  `Ban::acceptConnection` cuenta las conexiones de la IP.
- Si el CLI de Docker en Windows se cuelga, el motor suele seguir vivo: se lo
  mira por el socket de adentro de WSL y se arregla reiniciando Docker
  Desktop. El 2026-08-29 el contenedor `servidor-server-1` estaba caido y los
  puertos 7171/7172 seguian escuchando sin nadie detras.
- `prueba_trade_vip_vivo.tscn` es mutante y no entra a la matriz local. Vaciar
  slots ya vacios puede producir `Sorry, not possible.` antes del trade; esos
  mensajes son precondicion esperada. Cualquier error durante oferta o
  aceptacion si hace fallar la corrida.
- El 2026-08-29 Son Goku estaba offline antes de la prueba. No se cambio su
  clave: solo se cambio su asociacion de cuenta durante la corrida y se
  restauro inmediatamente despues, aun ante fallo.
- La prueba de reacquisicion mueve y dana temporalmente a Valentino. Tras la
  corrida final se restauraron exactamente los timestamps, posicion, vida y
  duracion de condicion que tenian sus archivos al abrir este turno; los
  depots y demas cambios previos del usuario quedaron intactos.
