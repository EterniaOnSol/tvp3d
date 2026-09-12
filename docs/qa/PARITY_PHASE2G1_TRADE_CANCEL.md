# Phase 2G.1 — Paridad de cancelacion de comercio (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**. Replay vivo **`PASS 7/7`**, byte-identico
entre dos corridas, con el comparador generico sin modificar.

`PARITY-TRADE-CANCEL-001` es el **negativo** de `PARITY-TRADE-EXCHANGE-001`,
certificado en Phase 2G. Aquel fixture **no se toca**.

## 1. Que se certifica

Que una cancelacion **unilateral** de un comercio abierto:

1. termina el comercio para **los dos** participantes, no solo para el que
   cancelo;
2. **no mueve ningun objeto**: cada participante conserva exactamente lo que
   ofrecia.

## 2. El control es lo que hace honesto al fixture

**"No se movio nada" es una afirmacion trivialmente cierta** si el comercio
nunca llego a abrirse. Tambien se cumpliria si el alcance hubiera fallado, si
el objeto hubiera sido rechazado, o si el pedido simplemente no hubiera
llegado.

Por eso el control es **obligatorio y previo**: se exige que las **dos**
sesiones hayan recibido su **oferta propia** y la de la **contraparte** antes
de cancelar nada. Sin ese control este fixture no probaria absolutamente nada,
y seria el tipo de prueba que pasa siempre sin medir el comportamiento.

## 3. La regla, leida del codigo vigente del oracle

Entrante `0x80` → `Game::playerCloseTrade` (`servidor/src/game.cpp:3204-3212`),
que solo llama a `internalCloseTrade(player)` con `sendCancel = true`.

`Game::internalCloseTrade` (`game.cpp:3214-3260`) es **simetrico**: actua sobre
el que cancela **y** sobre su contraparte. Para **cada uno** de los dos:

- libera la reserva del objeto en el mapa global `tradeItems`;
- dispara `ON_TRADE_CANCEL` sobre el objeto;
- pone `tradeItem` y `tradePartner` en `nullptr` y el estado en `TRADE_NONE`;
- manda el aviso de cancelacion;
- manda el cierre de ventana.

**Alcanza con que uno cancele** para que los dos queden cerrados. Y en ningun
punto se mueve un objeto: la funcion **solo libera reservas**.

### 3.1 La guarda que delimita el alcance de este fixture

```cpp
if ((tradePartner && tradePartner->getTradeState() == TRADE_TRANSFER)
        || player->getTradeState() == TRADE_TRANSFER) {
    return;
}
```

El servidor **se niega a cancelar** si alguno de los dos ya esta
transfiriendo. Es decir que en la cancelacion explicita **nunca hay una
transferencia en curso que revertir**.

Esto importa mucho para no sobre-reclamar: este camino **no demuestra nada
sobre deshacer**. Certifica que cancelar antes de transferir no transfiere, que
es una propiedad real y util, pero **distinta** de AMBOS O NINGUNO ante un
fallo de transferencia.

## 4. Sin `RECORDED_EVIDENCE`, a proposito

Este fixture **no tiene observacion `RECORDED_EVIDENCE`**, y es una decision,
no un olvido.

Se busco antes de decidir, en todo `docs/qa/`. La **unica** mencion de
cancelacion en la evidencia historica es
`docs/qa/PRUEBA_VIVA_TRADE_VIP.md:70`:

> `Conexion772` expone aceptar, cancelar y mirar trade, pero no expone la
> solicitud inicial `0x7D` ...

Eso es un hecho sobre **la API del cliente**, no una observacion de
comportamiento del servidor. **Ninguna corrida historica cancelo un comercio
abierto ni midio que no se transfiriera nada.**

Fabricar una observacion grabada a partir de esa linea seria **inventar
evidencia**. El corpus `RECORDED_EVIDENCE` queda en **8**, sin cambio, igual
que en Phase 2D.1 y 2D.2, que tambien son negativos sin historia.

## 5. Roles, participantes y objetos

| Rol | Quien | Que hace |
|---|---|---|
| `TRADE_A` | jugador **normal** dedicado de QA, cuenta 1 | **inicia** el comercio y despues **no hace nada** |
| `TRADE_B` | jugador **normal** dedicado de QA, **cuenta 2** | presenta su objeto y **cancela** |
| `OPERADOR` | personaje con permisos, **fuera** del comercio | solo posiciona |

**Cancela el que NO inicio.** La funcion del servidor es simetrica, asi que
cualquiera serviria; se elige el no-iniciador porque es el caso levemente mas
fuerte —prueba que cancelar no es un privilegio de quien abrio— y porque deja
explicito que el otro lado no hizo nada. **Cual de los dos cancela no entra al
payload.**

### 5.1 `test_items_created = 0`

Este es el unico fixture del corpus que **no crea ni mueve nada**.

Los dos participantes **ya poseen** un objeto propio y distinguible del otro:
son precisamente los dos objetos que quedaron **cruzados** como residuo
declarado de Phase 2G. Aquel residuo se convierte aca en la linea base ideal,
sin duplicados y sin necesidad de aprovisionar.

Y como una cancelacion correcta **no transfiere**, al terminar el entorno queda
**exactamente como estaba**: el resultado correcto de este fixture es **cero
mutacion**.

### 5.2 Ninguno acepta, y es auditable

En todo el adaptador hay **cero** llamadas a la aceptacion del transporte y
**una** sola a la cancelacion. Se puede comprobar contando ocurrencias seguidas
de parentesis: la unica mencion del nombre de la aceptacion esta dentro de un
comentario, que es texto y no codigo.

## 6. Artefactos

| Artefacto | Ruta |
|---|---|
| Fixture | `qa/parity/fixtures/tvp772/trade_cancel/parity-trade-cancel-001.json` |
| `QACase` | `qa/parity/cases/tvp772/trade_cancel/parity-trade-cancel-001.case.json` |
| Captura | `cliente3d/pruebas/prueba_parity_trade_cancel_capture.gd` + `.tscn` |
| Observacion viva | `qa/parity/observations/tvp772/trade_cancel/live/parity-trade-cancel-001.observation.json` |
| Reporte vivo | `qa/parity/reports/replay_live_trade_cancel_report.json` |

`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, `MATCH_EXPECTED`.
`tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`,
`case_id == fixture_id`. **Sin cambios de schema.**

### 6.1 Las siete aserciones

| # | Puntero | Rol |
|---:|---|---|
| 1 | `/open_trade/participants_within_trade_range` | control |
| 2 | `/open_trade/each_participant_offered_a_real_item` | control |
| 3 | `/open_trade/both_participants_saw_own_and_counterpart_offer` | **el control decisivo** |
| 4 | `/cancellation/no_participant_accepted` | aislamiento |
| 5 | `/cancellation/trade_closed_for_cancelling_participant` | efecto |
| 6 | `/cancellation/trade_closed_for_other_participant` | **el efecto interesante** |
| 7 | `/no_transfer/offered_items_kept_original_owners` | **el negativo decisivo** |

Las tres primeras existen para que la septima signifique algo. La sexta es la
que prueba que la cancelacion es **bilateral** aunque la peticion sea de uno
solo.

## 7. Congelamiento previo a la corrida viva

| Artefacto | SHA-256 |
|---|---|
| fixture | `16061e12bd72d2ddfe2730d55bab082a5e68f4cb6869cae36f4c2a820a458d60` |
| `QACase` | `222ec51648faab25fcc0f034f4bcfde881f47f9b90c7fe154351f699c93dd88a` |
| captura `.gd` (final, la que produjo la observacion) | `3ad7c018fe2fcc9be995db575798f106321356dc425a975e92ebf0950d8f375e` |
| helper de credenciales | `edf69015380ee78bc05ff6966e6978665d45caebf60c34431e039cb4f24ef896` |
| `replay.py` | `97e3c7e4c1b6cadb65e096999f875f2eaa28b69cbea74e4fef7d5fdf14a26837` |
| `wrap_live_observation.py` | `920783f023be775696df34e360343e3a38749137a13123bc8ec40cfd735769b1` |
| `conexion772.gd` | `3767bf53ab900df713373adb8e1f89035522277487151e036d4e1b5b6026fc24` |
| `estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |

Los cuatro ultimos son **byte-identicos** a los congelados en Phase 2D, 2D.1,
2D.2, 2E, 2F y 2G.

Verificacion previa sin tocar el oracle: el adaptador **compila**
(`--check-only`, codigo 0), la escena corta limpio en la guarda de credenciales
(codigo **2**, con **0** lineas de conexion), y la auditoria de llamadas da
**0 aceptaciones / 1 cancelacion**.

El adaptador se **recongelo una vez** tras el primer intento completo
(`ed4fca52…` → `3ad7c018…`). El **fixture** y el **`QACase`** quedaron
**byte-identicos** de punta a punta: lo que cambio fue una guarda del arnes,
nunca lo que se afirma sobre el oracle.

## 8. Resultado en vivo — **CERTIFICADO**

Codigo de salida 0 y exactamente **una** linea `OBSERVATION_JSON`.
**2 intentos completos de 3, 0 salidas de preflight.**

### 8.1 El primer intento fallo por un defecto MIO, no del oracle

Vale la pena contarlo con precision, porque el oracle hizo **exactamente** lo
que el fixture predice y aun asi la corrida dio `FAIL`.

Observado en el intento 1, despues de que B cancelara:

```text
  [A] Trade cancelled.
  [B] Trade cancelled.
FAIL el comercio se cerro antes de que nadie cancelara
```

La cancelacion **funciono perfecto**: un solo participante cancelo y los dos
recibieron el aviso. Lo que fallo fue **mi guarda**: la comprobacion de "no
debe haber ningun cierre previo" estaba al **principio** de la funcion, sin
condicion, asi que tambien se evaluaba en el frame siguiente — y ahi capturaba
el cierre que producia **mi propia cancelacion exitosa**.

Es un error de **ordenamiento del arnes**. Se corrigio moviendo la guarda
adentro de la rama que corre **una sola vez, antes** de mandar la orden.

**La expectativa nunca se modifico**, verificado por hash: fixture
`16061e12…` y `QACase` `222ec516…` byte-identicos en los dos intentos. Lo unico
que cambio fue el adaptador (`ed4fca52…` → `3ad7c018…`).

Auditoria del intento fallido: la cancelacion se habia completado bien, asi que
**no dejo ningun residuo** y la linea base del intento 2 quedo intacta.

### 8.2 Cronologia observada (intento 2)

| Etapa | Observacion |
|---|---|
| Linea base | A tiene lo suyo y **no** lo del otro; B igual. Sin duplicados |
| Alcance | Recalculado sobre las posiciones reportadas: **holgadamente dentro** |
| Oferta de A | B recibe el aviso de que A quiere comerciar |
| Oferta de B | Recien ahi cada uno recibe la oferta del otro |
| **Control** | Las **dos** sesiones ven su oferta propia **y** la de la contraparte |
| Cancelacion | **B, que NO inicio, cancela. A no hace nada** |
| Aviso | `Trade cancelled.` en **las dos** sesiones |
| Cierre | Una sola cancelacion cerro el comercio en **las dos** sesiones |
| **Propiedad final** | A conserva lo suyo y **no** tiene lo del otro; B igual |

Duracion total: **~29 s**.

### 8.3 Cero mutacion, verificado en la persistencia

Este es el unico fixture del corpus cuyo resultado correcto es **no cambiar
nada**, y se comprobo en los archivos persistidos despues de la corrida:

| Participante | Objeto propio | Objeto del otro |
|---|---:|---:|
| `TRADE_A` | **1** | **0** |
| `TRADE_B` | **1** | **0** |

Identico a antes de abrir la fase. **Ningun objeto cambio de dueno.**

### 8.4 Mutaciones y residuos

| Concepto | Valor |
|---|---|
| Objetos de prueba creados | **0** |
| Objetos movidos | **0** |
| Objetos del usuario tocados | **0** |
| Equipo preexistente desplazado | **0** |
| Personajes del usuario usados | **0** |
| Cuentas / personajes creados | **0** |
| Credenciales cambiadas | **0** |
| Combate / ataques / monstruos / muertes / `/killall` | **0** |
| Aceptaciones enviadas | **0** |
| `OBSERVATION_JSON` emitidos | **1** |

**Sin residuo nuevo.** Los dos objetos que estaban cruzados como residuo
declarado de Phase 2G siguen exactamente donde estaban; esta fase los uso como
linea base y los dejo intactos.

### 8.5 Replay y congelamiento

- Replay contra **observacion viva**: **`PASS 7/7`**, byte-identico entre dos
  corridas
  (`sha256 a55faf7ab83e6499d6bdb15f748235651d6019b8a82d6b8d43af8271f7d5bacc`).
- **Sin replay grabado**, porque no hay `RECORDED_EVIDENCE` (seccion 4).
- Los **8 hashes congelados** de la seccion 7 se recalcularon despues de la
  corrida, del wrap y de los dos replays: **identicos los ocho**.
- `replay.py` y `wrap_live_observation.py` **no se modificaron**: aceptaron un
  **octavo** dominio de comportamiento sin ningun cambio.

## 9. Lo que este fixture NO afirma

- **NO** certifica la propiedad **AMBOS O NINGUNO** ante un fallo de
  transferencia. Ver seccion 3.1: el servidor se niega a cancelar durante la
  transferencia, asi que este camino nunca tiene nada que revertir.
- **NO** certifica la cancelacion **implicita**: por desconexion, por alejarse
  del alcance, por soltar el objeto ofrecido ni por ninguna otra invalidacion
  sobrevenida.
- **NO** certifica que pasa si cancelan **los dos** a la vez.
- **NO** certifica la cancelacion despues de que **uno** haya aceptado.
- **NO** congela cual de los dos participantes cancela.
- **NO** congela ningun numero de opcode legacy.
- **NO** afirma nada sobre VIP.
