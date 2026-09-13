# PARITY-TRADE-DISCONNECT-CANCEL-001

Estado: **LIVE CERTIFIED** contra TVP 7.72.

Contrato QA: `2.1.1`. Fase gobernante: **Phase 2 â€” build parity
fixtures against TVP**, que permanece **EN CURSO**.

## Afirmacion congelada

Cuando dos jugadores normales tienen un comercio realmente abierto, ninguno
acepta ni cancela explicitamente y el socket de juego de A se cierra por la
via de produccion auditada, TVP 7.72 elimina a A por perdida de conexion,
cierra implicitamente el comercio para B y no transfiere ninguno de los
objetos ofrecidos. Una sesion nueva de A confirma que los objetos conservan
sus duenos originales y que el comercio anterior no se restaura.

No se afirma nada sobre desconexion despues de una aceptacion,
`TRADE_TRANSFER`, rollback, fallo de destino, crash, timeout, perdida de
paquetes, muerte, rango vertical ni otro mecanismo de desconexion.

## Auditoria de fuente

### Estado y apertura

- `servidor/src/player.h:46-52` define `TRADE_NONE`,
  `TRADE_INITIATED`, `TRADE_ACCEPT`, `TRADE_ACKNOWLEDGE` y
  `TRADE_TRANSFER`.
- Cada jugador conserva `tradeItem`, `tradePartner` y `tradeState` en
  `player.h:1015`, `:1021` y `:1064`.
- `Game::playerRequestTrade` valida jugador, alcance, linea de lanzamiento y
  objeto en `game.cpp:2875-2990`.
- `Game::internalStartTrade` (`game.cpp:2993-3020`) enlaza las dos
  contrapartes, guarda la referencia del objeto, lo reserva en
  `Game::tradeItems`, fija `TRADE_INITIATED/TRADE_ACKNOWLEDGE` y manda las
  ofertas propia y contraparte.

### Aceptacion y limite de este fixture

`Game::playerAcceptTrade` esta en `game.cpp:3024-3135`. Solo cuando ambos
estan en `TRADE_ACCEPT` los cambia a `TRADE_TRANSFER`
(`:3058-3059`) y entra a las pruebas/movimientos. Este harness no llama
`Conexion772.enviar_aceptar_comercio()` y congela un contador de
aceptaciones igual a cero.

### Cierre comun

La cancelacion explicita entraria como `0x80` en
`protocolgame.cpp:514`, luego `Game::playerCloseTrade`
(`game.cpp:3204-3211`) y `internalCloseTrade`. Esa ruta **no se usa**.

`Game::internalCloseTrade` esta en `game.cpp:3214-3260`:

1. retorna si alguno esta en `TRADE_TRANSFER` (`:3217`);
2. quita el objeto de `tradeItems`, libera su referencia, ejecuta
   `ON_TRADE_CANCEL` y borra `tradeItem` (`:3222-3229`);
3. pone al jugador en `TRADE_NONE` y borra `tradePartner`;
4. hace lo mismo con la contraparte (`:3240-3253`);
5. manda a la contraparte el texto y `sendTradeClose()`
   (`:3256-3258`).

Para los items comunes `Item::onTradeEvent` es un no-op
(`item.h:1006`); la especializacion de documento de casa queda fuera del
fixture. `ProtocolGame::sendCloseTrade` serializa `0x7F` en
`protocolgame.cpp:1504-1509`.

### Corte de conexion certificado

`Conexion772.cerrar()` (`cliente3d/red/conexion772.gd:119-123`) llama
unicamente `StreamPeerTCP.disconnect_from_host()` y descarta el socket.
No llama `enviar_logout()` (`:290`), aceptar (`:537`) ni cancelar
trade (`:542`).

La cadena de servidor observada por este mecanismo es:

```text
StreamPeerTCP.disconnect_from_host()
  -> Connection::parseHeader(error)                  connection.cpp:116-123
  -> Connection::close(FORCE_CLOSE)                  connection.cpp:48-68
  -> ProtocolGame::release()                         protocolgame.cpp:134-145
  -> Player queda sin client
  -> Player::sendPing() detecta hasLostConnection    player.cpp:803-833
  -> Game::executeRemoveCreature()
  -> Game::processRemovedCreatures()
  -> Game::removeCreature()
  -> Player::onRemoveCreature(this, true)             player.cpp:1079-1117
  -> Game::internalCloseTrade(this)                  player.cpp:1094-1095
  -> IOLoginData::savePlayer(this)                   player.cpp:1116
```

El cierre de trade ocurre antes de la persistencia. El socket bruto y el
logout ordenado terminan usando la baja del jugador y el mismo primitivo de
limpieza, pero este fixture congela **solo el corte bruto del socket**. El
cliente no manda `0x14` ni `0x80`.

Un jugador desconectado no puede dejar a B trabado en este caso: ambos estan
fuera de `TRADE_TRANSFER`, por lo que `internalCloseTrade` limpia
simetricamente los dos punteros, estados y objetos reservados. El caso
`TRADE_TRANSFER` queda expresamente sin certificar.

## Transporte y participantes

Se reutilizo `Conexion772.enviar_solicitar_comercio()`, transporte de
produccion `0x7D`, con parser de produccion `EstadoMundo`.
`estado_mundo.gd:453-476` activa el comercio y separa oferta propia y de
contraparte; `:478-482` consume el cierre autoritativo, deja
`comercio.activo=false` y emite `comercio_cerrado`.

Roles normalizados:

- A: jugador QA normal, iniciador y participante desconectado;
- B: jugador QA normal distinto y sobreviviente;
- operador: solo posicionamiento, fuera del area medida.

Los dos jugadores usan cuentas distintas. Nombres, cuentas y claves existen
solo en variables de entorno y no aparecen en artefactos ni comandos.

## Estrategia de items y control de falso positivo

No se creo ni movio ningun item para montar el caso. El harness abre las
mochilas y elige un par de objetos ya existentes que sean levantables, no
contenedores, de nombres distintos y cuya propiedad basal no sea ambigua.
La corrida eligio un item de A desde mochila y un item de B ya existente; la
especie se considera metadata del harness y no entra al payload.

Antes del corte se exigieron cuatro seÃ±ales independientes del servidor:

- A vio su propia oferta;
- A vio la oferta de B;
- B vio su propia oferta;
- B vio la oferta de A.

Solo despues de las cuatro seÃ±ales se llamo `_con_a.cerrar()`. Por eso
"ningun item se movio" no puede ser el falso positivo trivial de un comercio
que nunca abrio. Dos contadores del harness quedaron en cero y una auditoria
de llamadas confirma cero invocaciones a aceptar y cero a cancelar.

Tras el corte:

- B recibio el evento autoritativo de cierre y su estado quedo inactivo;
- B conservo su propio objeto y no recibio el de A;
- A abrio una sesion nueva y una mochila nueva;
- A conservo su propio objeto y no recibio el de B;
- la sesion nueva de A no tenia el comercio anterior activo.

## Ocho aserciones

1. participantes dentro del alcance valido;
2. cada participante ofrecio un item real;
3. las dos sesiones vieron oferta propia y contraparte;
4. no se envio aceptacion ni cancelacion explicita;
5. se cerro el socket de juego de produccion sin solicitud de gameplay;
6. el cierre autoritativo de B lo dejo sin trade activo;
7. ambos items conservaron sus duenos tras reconectar A;
8. el trade anterior no se restauro en la nueva sesion de A.

La asercion 6 combina evento e inactividad porque ambos salen del mismo
handler de `0x7F`; separarlos duplicaria una sola observacion. La propiedad
se mantiene separada del cierre porque se mide desde inventarios
autoritativos y persistencia, no desde el paquete de cierre.

## Evidencia historica

No se agrego `RECORDED_EVIDENCE`. La busqueda completa solo encontro
menciones del hueco y de la existencia de APIs; ningun documento historico
observa en runtime un trade abierto terminado por desconexion. Fuente,
capacidad de API y recomendacion futura no son observacion grabada.

## Intentos

- preflight 1: no llego a abrir trade; los nombres residuales configurados no
  estaban equipados;
- preflight 2: no llego a abrir trade; la primera seleccion automatica
  consideraba solo equipo y no encontro un par no ambiguo;
- intento completo 1: **EXIT 0**, una linea `OBSERVATION_JSON`, todas las
  observaciones esperadas verdaderas;
- fallos de oracle: 0;
- fallos de harness durante comportamiento medido: 0;
- fallos ambientales previos al live: API Docker sin respuesta; se uso un
  runtime WSL aislado.

Los preflights no consumen el presupuesto de tres intentos porque nunca
abrieron un comercio y nunca ejecutaron la desconexion medida.

## Runtime aislado

El checkout tenia un cambio ajeno en
`servidor/gamedata/players/1/1.tvpp`, perteneciente al operador. Para no
reescribirlo, el oracle se ejecuto sobre una copia en Temp. Docker Desktop
dejo de responder a su API despues de iniciar MariaDB, aunque el puerto 3371
quedo disponible. Se compilo la copia con Ubuntu WSL y dependencias locales.

Boost 1.90 requirio en la copia temporal un shim de compilacion exclusivamente
en `ServiceManager::stop`: `post(handler)` paso a
`post(system_executor, handler)`. Esa funcion de apagado no participa en
login, juego, trade, perdida de conexion ni persistencia. Ningun archivo de
`servidor/src` del checkout cambio.

## Hashes congelados SHA-256

| Artefacto | SHA-256 |
| --- | --- |
| fixture nuevo | `71176e10cf79261472797114cfa6231e7ff2d5a9e71012c41a882ba5c42c6696` |
| QACase nuevo | `4bfe143fa8a90685931e7119190e247e92c0f58fabd26b3b1331b740e7c399a2` |
| adapter final, recongelado tras preflights | `cd0e9bacb4a6a00d13b3f40ef3f3041413ffbca3598b876afd558d7a24261b65` |
| escena | `f2e40bc0e152ae3b5869bdacae7aa3c73921061af1e2f80994f6b08f23f31bbb` |
| replay.py | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| wrap_live_observation.py | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| fixture exchange | `c9880a536e5213b011f036803d2bbb3bf4a521bc7eb88ec92adf896728558aae` |
| case exchange | `1ac79ee19d2dc5c06fb9e5fa88745f987cf8ae9f47dff7521fd0274e07d643e7` |
| fixture cancel | `16061e12bd72d2ddfe2730d55bab082a5e68f4cb6869cae36f4c2a820a458d60` |
| case cancel | `222ec51648faab25fcc0f034f4bcfde881f47f9b90c7fe154351f699c93dd88a` |
| fixture range | `e619b6f5a8a831dccd2c822db1d9d2c59275d57dc1abee05270b37eb758c4478` |
| case range | `364152bf23320cbc76128721ff006032fc6dd140a2ba39715937156457cbe736` |

Fixture y QACase nunca cambiaron despues de observar el live. El adapter se
recongelo tras cada defecto de preflight, antes del intento completo.

## Replay y corpus

Comando exacto del caso nuevo:

```powershell
python qa/parity/tools/replay.py --cases-dir qa/parity/cases/tvp772/trade_disconnect_cancel --observations-dir qa/parity/observations/tvp772/trade_disconnect_cancel/live --case-id PARITY-TRADE-DISCONNECT-CANCEL-001 --report qa/parity/reports/replay_live_trade_disconnect_cancel_report.json
```

Resultado: `PASS PARITY-TRADE-DISCONNECT-CANCEL-001`,
`exit=0 pass=1 fail=0 blocked=0 not_run=0`, es decir **PASS 8/8**.
El reporte versionado se regenero en Temp y fue byte-identico:
`408c35b12043e92eb4d15d0c178b160fddc1fe8f568f19a3f7b085e8fc196862`.

Para el corpus completo se aplanaron en Temp los 19 QACases porque
`replay.py` consume un solo directorio no recursivo. Se prefirieron las 16
observaciones `LIVE_ORACLE`; los dos casos sin live usaron su
`RECORDED_EVIDENCE`. Las dos corridas dieron:

```text
exit=0 pass=18 fail=0 blocked=0 not_run=1
```

Los reportes y stdout fueron byte-identicos. SHA-256 de ambos reportes:
`c0cadc9c3bba9c6262f426f178fbf4d433cf284dcfd75587f84fd29dc7271ddc`.
El unico `NOT_RUN` es `PARITY-LOOT-RANDOMNESS-001`, cuyo QACase publicado
define deliberadamente `mode: EVIDENCE_ONLY` y cero aserciones. Por eso la
realidad contractual no permite afirmar `PASS 19/19`: los **18 casos
ejecutables pasan**, incluido el nuevo, y el caso documental conserva su
estado correcto. Ningun caso fallo ni quedo bloqueado.

Todos los 89 JSON bajo `qa/parity` parsearon.

Inventario final recontado: 19 fixtures `LEGACY_PARITY`, 19 QACases,
9 `RECORDED_EVIDENCE` y 16 `LIVE_ORACLE`. Architecture V2 permanece
198 especificadas / 0 materializadas.

## Mutacion, residuo y procesos

Resultado medido: 0 items creados, 0 borrados, 0 transferidos, 0 consumidos,
0 cuentas, 0 personajes, 0 muertes, 0 combate, 0 monstruos, 0 casas, 0
listas, 0 camas, 0 premium y 0 progresion. Las posiciones necesarias de los
roles QA fueron la unica preparacion permitida. Residuo persistente atribuible:
0.

Procesos propios relevantes: Godot parse PID 35716; preflight PIDs 25524 y
19048; live exitoso PID 22708; WSL oracle PID Windows 34948 / Linux 402.
Consultas Docker propias bloqueadas fueron terminadas por PID exacto 31812,
30736 y 33524. El configure temporal agotado fue terminado por PID 34096.
Procesos ajenos terminados: **0**.

## Diferencia con PARITY-TRADE-CANCEL-001

`PARITY-TRADE-CANCEL-001` manda una cancelacion explicita `0x80` desde un
participante conectado. Este fixture no manda `0x80): corta el socket de A
y observa la limpieza implicita del servidor durante la baja. Comparten
`internalCloseTrade` como primitivo interno, pero la causa externa y la
ruta hasta ese primitivo son independientes.

## Huecos que permanecen

- BOTH_OR_NONE bajo un fallo real de transferencia;
- aceptar un lado y luego cancelar/desconectar;
- cualquier comportamiento durante `TRADE_TRANSFER`;
- borde vertical del alcance;
- invalidacion o movimiento del item ofrecido;
- otros tipos de desconexion, timeout, perdida de paquetes y crashes.
