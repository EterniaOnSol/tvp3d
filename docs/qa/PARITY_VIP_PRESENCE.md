# `PARITY-VIP-PRESENCE-001` — Presencia en la lista de contactos (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay grabado **`PASS 5/5`** y replay vivo
**`PASS 5/5`**, los dos byte-identicos entre corridas, con el comparador
generico sin modificar.

Fixture `LEGACY_PARITY` dentro de **Phase 2 — build parity fixtures against
TVP**. No abre ninguna fase ni sub-fase nueva y no toca
`docs/tibia3d/MASTER_PLAN.md`.

## 1. Que se certifica

Que un personaje existente puede ser agregado a la lista de contactos de otro
jugador **indicando solo su nombre**, que el servidor **resuelve ese nombre a
la identidad real** del personaje, que la entrada nace marcada como
**desconectada**, y que el observador recibe las **transiciones de presencia**
cuando ese personaje se conecta y se desconecta.

Este fixture es **presencia de contactos**, no el dominio completo de la lista
de contactos. La seccion 10 enumera lo que queda explicitamente sin certificar.

## 2. Evidencia historica

`docs/qa/PRUEBA_VIVA_TRADE_VIP.md` (2026-08-29) es una corrida viva genuina
contra TVP 7.72 que ejercito **dos** areas: contactos y comercio. El comercio
ya quedo cubierto por `PARITY-TRADE-EXCHANGE-001` y
`PARITY-TRADE-CANCEL-001`; este fixture toma **solo** la parte de contactos.

### 2.1 Auditoria linea por linea

| # | Hecho congelado | Respaldo textual |
|---:|---|---|
| 1 | `target_entry_created` | `OK: VIP agrega por nombre y devuelve GUID real` |
| 2 | `target_identity_resolved` | misma linea: **devuelve GUID real**, verificado contra un GUID conocido |
| 3 | `target_initially_offline` | `OK: VIP agregado aparece offline` |
| 4 | `online_transition_observed` | recorrido paso 3: *"Valentino entra por otro socket; el god recibe `0xD3` online"* |
| 5 | `offline_transition_observed` | recorrido paso 8: *"Valentino sale limpiamente; el god recibe `0xD4` offline"*, y `OK: VIP informa online -> offline` |

**Cinco** aserciones. Todas son observaciones de **runtime**, no capacidades de
API, asi que **si** califican como `RECORDED_EVIDENCE`.

### 2.2 Por que 4 y 5 van separadas, y en Phase 2G no

En `PARITY-TRADE-EXCHANGE-001` se rechazo partir el assert combinado de ofertas
en cuatro, por no fabricar granularidad. Aca las dos transiciones **si** se
congelan por separado, y la diferencia es estructural, no de conveniencia:

- en aquel fixture el recorrido registraba **un solo paso** que mencionaba las
  dos ofertas juntas;
- aca el recorrido registra **dos pasos numerados distintos** —el 3 y el 8—,
  separados por todo el bloque de comercio, y **cada uno con su propio opcode**
  (`0xD3` y `0xD4`).

Son dos eventos observados en momentos distintos del recorrido historico, no
una conjuncion escrita de corrido.

### 2.3 Lo que NO se congelo

- **Que la entrada sobreviva** al ciclo de presencia. La evidencia historica no
  lo afirma; se deduciria de recibir `0xD4`, pero deducir no es observar. Queda
  como **guarda viva**.
- **Que el nombre devuelto sea el canonico.** El codigo lo canoniza, pero la
  evidencia historica no lo midio. Queda como **guarda viva**.
- La baja, el duplicado, el auto-agregado y la persistencia entre sesiones del
  observador: ver seccion 10.

## 3. Semantica de origen, verificada en el codigo vigente

### 3.1 Alta por nombre y resolucion de identidad

`Game::playerRequestAddVip` (`servidor/src/game.cpp:3417-3456`):

```cpp
Player* vipPlayer = getPlayerByName(name);
if (!vipPlayer) {                                   // objetivo DESCONECTADO
    uint32_t guid; bool specialVip; std::string formattedName = name;
    if (!IOLoginData::getGuidByNameEx(guid, specialVip, formattedName)) {
        player->sendCancelMessage(RETURNVALUE_PLAYERDOESNOTEXIST);
        return;
    }
    if (specialVip && !player->hasFlag(PlayerFlag_SpecialVIP)) { ... return; }
    player->addVIP(guid, formattedName, VIPSTATUS_OFFLINE);
} else { ... VIPSTATUS_ONLINE / OFFLINE segun modo fantasma ... }
```

| Propiedad | Valor verificado |
|---|---|
| Objetivo desconectado | **valido**: se resuelve contra la persistencia |
| Identidad | `getGuidByNameEx` devuelve la identidad **real** del personaje |
| Nombre | se **canoniza** (`formattedName` se reescribe por referencia) |
| Inexistente | responde "el jugador no existe" y **no crea nada** |
| Estado inicial | **`VIPSTATUS_OFFLINE`** para un objetivo desconectado |
| `SpecialVIP` | un personaje con esa bandera **no** puede ser agregado por quien no la tiene |

La bandera `specialvip` aparece en `servidor/data/XML/groups.xml` **solo en los
grupos elevados**. Por eso el objetivo de esta captura es un **jugador normal**
y nunca el operador: usar al operador como objetivo seria rechazado.

### 3.2 Duplicado y capacidad

`Player::addVIP` (`player.cpp:2043-2060`) rechaza por tope y por duplicado
**antes** de mandar nada al cliente. `Player::getMaxVIPEntries`
(`player.cpp:3867-3874`) usa el limite del grupo **solo si no es 0**, y en
`groups.xml` los jugadores normales lo tienen en `0`, asi que caen al limite de
`servidor/config.lua`, que es holgado. **No hay bloqueo de capacidad** para dos
participantes.

### 3.3 Propagacion de presencia — y por que refuerza la prueba de identidad

`Player::addList()` (`player.cpp:1996-2003`) al conectarse y
`Player::removeList()` (`player.cpp:1987-1994`) al desconectarse recorren a
**todos** los jugadores conectados y llaman a `notifyStatusChange`, que es:

```cpp
auto it = VIPList.find(loginPlayer->guid);
if (it == VIPList.end()) { return; }
client->sendUpdatedVIPStatus(loginPlayer->guid, status);
```

El observador recibe la transicion **solo si la identidad del que entra o sale
esta en SU lista**. Eso convierte a la transicion en una **prueba independiente
de que el nombre se resolvio al personaje correcto**: si hubiera resuelto a
otro, la busqueda fallaria y no llegaria nada.

Tambien implica que la presencia **no depende de la posicion**: por eso esta
captura no mueve a nadie y **no usa operador**.

## 4. Semantica de transporte, por direccion

Aca la trampa de los opcodes es **mas filosa** que en comercio:

| Numero | **Entrante** (cliente → servidor) | **Saliente** (servidor → cliente) |
|---|---|---|
| `0xD2` | pedir **apariencia** | **entrada de contacto** (guid, nombre, estado) |
| `0xD3` | fijar **apariencia** | contacto se **conecto** |
| `0xD4` | — | contacto se **desconecto** |
| `0xDC` | **agregar** contacto | — |
| `0xDD` | **quitar** contacto | — |

Fuentes: `protocolgame.cpp:548-551` (entrante) y `protocolgame.cpp:2206-2224`
(saliente). `0xD2` y `0xD3` entrantes **no tienen nada que ver con contactos**.

**Ningun numero de opcode entra al payload.**

### 4.1 Transporte de produccion, sin rearmar paquetes

`cliente3d/red/conexion772.gd` ya publica `enviar_agregar_vip(nombre)` (`0xDC`)
y `enviar_quitar_vip(guid)` (`0xDD`), y
`cliente3d/red/estado_mundo.gd:803-826` ya parsea `0xD2`/`0xD3`/`0xD4` a un
diccionario `vip` con senal `vip_actualizado`. QA **usa el transporte y el
parser de produccion** y **no rearma ningun paquete**.

Detalle relevante del parser: una transicion `0xD3`/`0xD4` solo se aplica
**si la entrada existe** (`if vip.has(guid)`), lo que refuerza el control.

## 5. Participantes

| Rol | Quien | Que hace |
|---|---|---|
| **Observador** | jugador **normal** dedicado de QA, cuenta A | dueno de la lista; **unica** fuente de las aserciones |
| **Objetivo** | jugador **normal** dedicado de QA, **cuenta B** | se lo agrega, despues entra y sale |

Cuentas **distintas** para que las dos sesiones puedan solaparse. **No se usa
operador ni god**, porque la presencia no depende de la posicion: nadie queda
"fuera de la relacion VIP" porque simplemente no hay un tercero.

**0 cuentas creadas. 0 personajes del usuario.** Credenciales **solo por
entorno**; sin la variable requerida la captura corta con `BLOCKED` y codigo 2
**antes** de abrir ningun socket (verificado: 0 lineas de conexion).

## 6. Identidad: resuelta, no eco de un texto

No alcanza con que aparezca una entrada con el nombre tecleado: eso lo
produciria cualquier implementacion que devolviera lo que se le mando.

Se exige que la **identidad** que trae la entrada sea la del personaje objetivo
real, comparandola contra la identidad esperada, que se configura por entorno y
se obtuvo de forma **solo lectura**. Ese valor es **metadata del harness**: se
usa para comparar y **nunca se serializa**; la observacion publica unicamente
el booleano.

Como refuerzo independiente, la seccion 3.3 muestra que las transiciones solo
pueden llegar si la identidad resuelta es la correcta.

## 7. Controles de falso positivo

El fixture **no puede pasar** si:

| Riesgo | Como se cierra |
|---|---|
| El alta fue rechazada / no se creo entrada | se exige la entrada recibida por el observador |
| La entrada es una preexistente | linea base: se exige que el objetivo **no** este ya en la lista |
| Se echo el texto sin resolver identidad | se compara la identidad recibida contra la esperada |
| El objetivo entro pero el observador no se entero | la transicion se lee de la lista **del observador** |
| El arnes dedujo la presencia de conocer la otra sesion | **ninguna** asercion consulta el estado del objetivo |
| Una entrada ajena contamino la medicion | toda actualizacion con otra identidad se descarta y marca la corrida |
| El "offline" inicial se confundio con la transicion final | la transicion a desconectado **solo** cuenta despues de haber visto la conexion |

El ultimo punto es una fuente real de falso positivo: la entrada **nace**
desconectada, asi que un `offline` suelto no prueba nada. Se exige el orden.

Auditoria del adaptador: hay exactamente **3** usos de la sesion del objetivo, y
los tres son plumbing —responder al latido, manejar el rechazo y parsear
paquetes—. **Ninguna asercion** la consulta.

## 8. Congelamiento previo a la corrida viva

| Artefacto | SHA-256 |
|---|---|
| fixture | `96be2b10fe75e94daecbd867759b9f7f40e6a0bf826be41dab089d373f0da251` |
| `QACase` | `0ca0f12ea1a82c1246c3e49a0e1b0f8c8f11a436ad90d20c5f827bed5798f134` |
| observacion grabada | `599b2ff9a485460d51e5dc64656510582c2f1b955731116a1b2747d2e19e8ca8` |
| captura `.gd` (final, la que produjo la observacion) | `c29f7adda1b0d3186d82a7c38bdc0a9a7fa6a5da62c1d46a00cc129d032c629d` |
| helper de credenciales | `edf69015380ee78bc05ff6966e6978665d45caebf60c34431e039cb4f24ef896` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en todos los
fixtures anteriores de Phase 2.

Replay contra evidencia grabada con `replay.py` **sin modificar**:
**`PASS 5/5`**, byte-identico entre dos corridas
(`sha256 fbec1137c54d35c58f2db7b593d606f9811b60be037c92b2c24e0b6a23135f1d`).

## 9. Resultado en vivo — **CERTIFICADO**

Codigo de salida 0 y exactamente **una** linea `OBSERVATION_JSON`.
**3 intentos completos de 3 permitidos, 0 salidas de preflight.**

### 9.1 Los tres intentos, sin maquillaje

| # | Hasta donde llego | Causa | Naturaleza |
|---:|---|---|---|
| 1 | observo los **tres** hechos del alta | el login del objetivo fue rechazado con `Server is currently closed.` | **entorno**: el servidor se estaba reiniciando |
| 2 | linea base | mi reparacion esperaba una confirmacion de baja **que el protocolo no emite** | **defecto mio** |
| 3 | **completo** | — | **exito** |

**Intento 1 — entorno, no fixture.** El log del servidor con marcas de tiempo
lo confirma: el observador entro a las `10:29:55`, el objetivo fue rechazado a
las `10:30:07`, y el servidor volvio a arrancar a las `10:37:43`
(`>> TVP3D Server Online!`). La guarda que produjo el rechazo es
`protocolgame.cpp:182-183`, que exige `GAME_STATE_CLOSED`. No fue un fallo del
arnes ni del oracle: el servidor estaba bajando mientras corria la captura.
Ese intento **si dejo residuo**, porque el alta ya habia ocurrido y la fase de
limpieza nunca llego a correr.

**Intento 2 — defecto mio, y de los utiles.** Al reparar la linea base sucia
que dejo el intento 1, esperaba ver desaparecer la entrada del espejo local. No
desaparece nunca, y no por un error de red: **la baja es silenciosa por
diseno**. Verificado en el codigo: `Game::playerRequestRemoveVip`
(`game.cpp:3458-3466`) llama a `Player::removeVIP` (`player.cpp:2034-2041`),
que borra de la lista y **no manda nada al cliente**, y no existe **ningun**
opcode saliente de baja.

La correccion no fue solo esperar menos: se reemplazo la comprobacion por una
**mas fuerte y autoritativa**. `Player::addVIP` rechaza los duplicados y en ese
caso **no emite la entrada**, asi que **recibir una entrada fresca tras el alta
demuestra por si solo que el objetivo no estaba ya en la lista**. Se dejo de
mirar el espejo del cliente y se paso a deducirlo del comportamiento del
servidor.

Que la baja efectivamente funciona quedo probado de rebote: el intento 3
arranco con la lista **limpia**, o sea que la baja silenciosa del intento 2 si
se habia aplicado del lado del servidor.

**La expectativa nunca se modifico.** Verificado por hash en los tres intentos:
fixture `96be2b10…`, `QACase` `0ca0f12e…` y observacion grabada `599b2ff9…`
byte-identicos de punta a punta. Lo unico que cambio fue el adaptador
(`846d066b…` → `c29f7add…` → `dc973d6e…`).

### 9.2 Un defecto mas que la corrida 1 dejo al descubierto

Al preparar el intento 2 aparecio un problema que **no** se habia manifestado
antes por casualidad: al conectarse, el servidor le manda al observador las
entradas que **ya** tenia (`sendVIPEntries`, `protocolgame.cpp:1922`), y cada
una dispara **la misma senal** que una entrada nueva. Con la lista vacia del
intento 1 eso no se noto; con lista sucia habria hecho que una entrada
preexistente se confundiera con la creada por la captura.

Se cerro con una **puerta de medicion**: la senal solo cuenta **despues** de
pedir el alta. Es exactamente el tipo de falso positivo que este fixture
declara querer evitar.

### 9.3 Cronologia observada (intento 3)

| Etapa | Observacion |
|---|---|
| Linea base | El observador **no** tiene al objetivo; **0** contactos preexistentes |
| Alta | Se agrega indicando **solo el nombre**, con el objetivo **desconectado** |
| Entrada | Recibida con **identidad esperada** y presencia **desconectado** |
| Guarda viva | El servidor devolvio el **nombre canonico**: `true` |
| Conexion | El **observador** recibe la transicion a **conectado** |
| Desconexion | El **observador** recibe la transicion a **desconectado** |
| Guarda viva | La entrada **sigue** en la lista tras el ciclo: `true` |
| Limpieza | Se quita **solo** la entrada creada por la captura |

Duracion total: **~15 s**.

### 9.4 Limpieza verificada, cero residuo

Comprobado en el archivo persistido del observador despues de la corrida:

```
VIP = ()
```

La lista volvio **exactamente** a su estado original. **0 contactos ajenos
tocados**, **0 residuo de QA**. La baja se hizo con el mecanismo normal de
produccion y **no** es una asercion de este fixture.

### 9.5 Mutaciones

| Concepto | Valor |
|---|---|
| Cuentas creadas | **0** |
| Personajes creados | **0** |
| Personajes del usuario usados | **0** |
| Mutaciones de progresion | **0** |
| Contactos ajenos modificados | **0** |
| Muertes / combate / monstruos / `/killall` | **0** |
| Objetos creados o movidos | **0** |
| Movimiento de personajes | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

### 9.6 Replay y congelamiento

- Replay contra **evidencia grabada**: **`PASS 5/5`**, byte-identico entre dos
  corridas
  (`sha256 fbec1137c54d35c58f2db7b593d606f9811b60be037c92b2c24e0b6a23135f1d`).
- Replay contra **observacion viva**: **`PASS 5/5`**, byte-identico entre dos
  corridas
  (`sha256 648f0c7b4e29813862e9b2a07fc8df7b77ed0111e44e42919824dd0d3f0379a2`).
- Los **9 hashes congelados** de la seccion 8 se recalcularon despues de la
  corrida, del wrap y de los cuatro replays: **identicos los nueve**.
- `replay.py` y `wrap_live_observation.py` **no se modificaron**: aceptaron un
  **noveno** dominio de comportamiento sin ningun cambio.

### 9.7 Nota de entorno

Durante este turno el usuario estaba trabajando sobre el mismo servidor: hubo
un reinicio a las `10:37` y una sesion de un personaje del usuario a las
`10:53`. La captura **no toca** personajes del usuario y no interfiere con
ellos, pero el reinicio si invalido el primer intento. Queda anotado porque
explica un fallo que de otro modo pareceria del fixture.

## 10. Propiedades del dominio de contactos que NO se certifican

- limites de capacidad de la lista;
- alta **duplicada**;
- **baja** de un contacto (se usa como limpieza, **no** como asercion);
- **auto-agregado**;
- alta de un personaje **inexistente**;
- presencia **por cuenta** en vez de por personaje;
- visibilidad de personajes **ocultos** o en modo fantasma;
- listas de **bloqueo**, grupos o comentarios;
- garantias de **orden** de las entradas;
- comportamiento entre **mundos**;
- migracion ante **renombrado**;
- **persistencia** de la lista entre sesiones del observador o reinicios del
  servidor;
- formas de desconexion **distintas del cierre limpio**.

La persistencia se dejo deliberadamente fuera: presencia y persistencia son
propiedades distintas y mezclarlas habria ampliado el alcance sin necesidad.
Merece su propio fixture si alguna vez hace falta.
