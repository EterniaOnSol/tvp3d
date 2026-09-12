# `PARITY-TRADE-RANGE-BOUNDARY-001` — Borde de alcance del comercio (TVP 7.72)

**CERTIFICADO EN VIVO.** Replay vivo **`PASS 10/10`**, byte-identico entre dos
corridas. **Dos intentos**: el primero fallo por un defecto **mio** del arnes,
nunca del oracle.

Fixture `LEGACY_PARITY` **dentro de Phase 2**. No abre fase ni sub-fase nueva y
**no toca** `docs/tibia3d/MASTER_PLAN.md`.

---

## 1. Que se certifica

> Con el **mismo jugador**, el **mismo objeto**, la **misma contraparte** y el
> **mismo piso**, moviendo **una sola casilla sobre un solo eje**:
>
> | Separacion | Resultado |
> |---|---|
> | `\|dx\|=2  \|dy\|=2  \|dz\|=0` | el comercio **se abre** |
> | `\|dx\|=3  \|dy\|=2  \|dz\|=0` | **rechazado por alcance** |
> | `\|dx\|=2  \|dy\|=3  \|dz\|=0` | **rechazado por alcance** |

Cierra el hueco que `PARITY-TRADE-EXCHANGE-001` habia declarado explicitamente
sin certificar (linea 429 de su documento: *"NO certifica el borde del alcance
de comercio (2 contra 3 casillas)"*).

---

## 2. La regla de origen, separada de la geometria certificada

Esta separacion es deliberada: **el codigo dice una cosa y la corrida viva
prueba otra, mas chica.**

### 2.1 Regla de origen (leida en HEAD)

`Game::playerRequestTrade` (`servidor/src/game.cpp:2888-2891`):

```cpp
if (!Position::areInRange<2, 2, 0>(tradePartner->getPosition(),
                                   player->getPosition())) {
    player->sendCancelMessage(RETURNVALUE_DESTINATIONOUTOFREACH);
    return;
}
```

`Position::areInRange` (`servidor/src/position.h:32-35`):

```cpp
return Position::getDistanceX(p1, p2) <= deltax
    && Position::getDistanceY(p1, p2) <= deltay
    && Position::getDistanceZ(p1, p2) <= deltaz;
```

con `getDistanceX(p1,p2) = abs(p1.x - p2.x)` (`position.h:51-59`).

| Propiedad | Que dice el codigo |
|---|---|
| Comparador | **`<=`**, asi que el borde es **INCLUSIVO**: 2 entra |
| Ejes | X e Y **por separado**, unidos por **AND** |
| Metrica | **rectangulo** (Chebyshev con lados iguales), **no** euclidea, **no** Manhattan |
| Signo | deltas **absolutos**: da igual hacia donde |
| Vertical | `deltaz = 0` es `abs(dz) <= 0`: **mismo piso exacto** |

**Por que la metrica importa y no es un detalle.** En la esquina `(2,2)` la
distancia euclidea es **2.83** y la Manhattan es **4**. Una regla euclidea
`<= 2` o una Manhattan `<= 2` habrian **rechazado** ese punto. Que el servidor
lo **acepte** es exactamente lo que distingue la geometria real de las dos
aproximaciones que uno escribiria por intuicion.

### 2.2 Geometria certificada en vivo

Solo lo que se midio: el borde **horizontal** sobre **los dos ejes**, con
`dz = 0` en las tres mediciones.

**No se certifica el borde vertical.** El parametro de origen es 0, pero la
corrida nunca cambio de piso, y afirmarlo por simetria del codigo seria
convertir una lectura en una observacion. Queda como limitacion explicita.

---

## 3. Por que la esquina es el positivo

Probar `(2,2)` —y no `(2,0)` o `(0,2)`— demuestra que **los dos ejes pueden
estar SIMULTANEAMENTE en su maximo inclusivo**. Es la unica geometria que
falsea de una sola vez las hipotesis euclidea y Manhattan.

Y cada negativo se aleja **una casilla sobre un solo eje**, dejando el otro en
su maximo, de modo que cada rechazo queda atribuido a un eje concreto en vez de
a "estar lejos" en general.

---

## 4. El control positivo no es decorativo

En el codigo, la comprobacion de alcance es la **segunda** guarda de la
funcion: **antes** de la linea de tiro y **antes** de validar el objeto.

Consecuencia dura: **un rechazo por alcance NO prueba que el objeto fuera
valido, ni que el transporte funcionara, ni que la contraparte existiera.** Sin
abrir el comercio en el borde inclusivo **con el mismo objeto**, un "no se
abrio" seria igualmente compatible con un objeto invalido, un transporte roto,
una sesion caida o una peticion perdida.

Por eso el positivo es obligatorio, y por eso se exige como prueba que el
**servidor devuelva al solicitante su propia oferta** (`0x7D`), no que el
paquete se haya enviado.

---

## 5. El discriminador, y su limite honesto

El mensaje es `"Destination is out of range."` (`tools.cpp:1015-1016`).

**No es univoco por si solo**: `RETURNVALUE_DESTINATIONOUTOFREACH` tiene
productores en mover criaturas, mover objetos, usar objetos y hechizos. A
diferencia del rechazo de casas —que tenia nueve productores, todos de acceso a
casas— aca el mensaje no alcanza.

Lo que lo vuelve univoco es la **accion**: en la ventana de medicion el arnes
manda **una solicitud de comercio y nada mas**, y dentro de
`playerRequestTrade` el unico origen posible de esa respuesta es la guarda de
`game.cpp:2889`.

**Ademas se vigila la guarda siguiente.** Si el terreno no tuviera linea de
tiro, el rechazo seria `"You cannot throw there."`; el adaptador lo detecta por
separado y en ese caso **invalida la medicion** en vez de contarla como exito.

---

## 6. Terreno, participantes y objeto

### 6.1 Terreno

Calificado **antes** de congelar, con la herramienta de solo lectura
`prueba_casa_reconocer_limite.gd` (`/tileinfo`): **102** casillas limpias y en
**zona de proteccion** alrededor del deposito de Thais, de las cuales **41**
servian de ancla para las tres geometrias.

Todas las casillas usadas: mismo piso, transitables, sin objetos encima, sin
escaleras ni teletransportes, y en **zona de proteccion** — asi que **0 combate
posible** y ningun monstruo puede interferir.

### 6.2 Participantes

| Rol | Quien |
|---|---|
| El que ofrece | jugador normal de QA, posicion **fija** en las tres mediciones |
| La contraparte | otro jugador normal de QA, **otra cuenta**; el unico que se mueve |
| Operador | **solo montaje**: convoca y se aparta. **No participa del comercio** |

Una cuenta normal no admite dos sesiones, asi que los participantes estan en
cuentas distintas; el adaptador lo verifica y aborta si no.

### 6.3 Objeto controlado

**`test_items_created = 0`.** El adaptador **no crea nada**: recorre el equipo
que el ofertante **ya tiene** y elige la primera ranura con un objeto
levantable y no contenedor, que es lo que exige `isPickupable()` del lado del
servidor. En la corrida certificada fue la ranura de armadura.

Que el objeto sirva de verdad **no lo decide esa heuristica**: lo prueba el
control positivo. Y es **el mismo objeto en las tres mediciones**.

---

## 7. El recorrido medido

| Paso | Que |
|---|---|
| montaje | el operador convoca a cada participante **por separado** y se aparta **antes** de que cada uno camine |
| colocacion | el ofertante va a su casilla fija; despues la contraparte a la esquina inclusiva |
| **positivo** | geometria autoritativa `2,2,0` verificada -> solicitud -> **el comercio se abre** |
| cancelacion | se cancela por la via ya certificada en `PARITY-TRADE-CANCEL-001`; **los dos** lados confirman el cierre |
| **negativo X** | geometria `3,2,0` verificada -> **`Destination is out of range.`**, sin sesion |
| **negativo Y** | geometria `2,3,0` verificada -> **`Destination is out of range.`**, sin sesion |
| integridad | el objeto sigue en la misma ranura del ofertante |

Duracion total: **46 segundos**, codigo de salida 0, exactamente una linea
`OBSERVATION_JSON`.

**Las tres separaciones se calculan de las posiciones AUTORITATIVAS** que
reporta el servidor, nunca de la prediccion local del cliente.

**Se cancela antes de medir los negativos, y eso es imprescindible**: con una
sesion de comercio abierta, una solicitud nueva seria rechazada por
*"You are already trading"*, que es otra razon y arruinaria la atribucion.

---

## 8. Este fixture no completa ningun comercio

Mide la **iniciacion**, no el intercambio. **Nunca se envia una aceptacion**,
asi que una transferencia es **imposible por construccion**, no solo
improbable.

Verificado ademas contra el estado persistido: el equipo de **los dos**
participantes quedo **byte-identico** a la linea base congelada.

| Concepto | Valor |
|---|---:|
| Comercios completados | **0** |
| Aceptaciones enviadas | **0** |
| Objetos transferidos | **0** |
| Objetos creados / borrados | **0** |
| Residuo persistente | **0** |
| Casas / listas de acceso / premium / camas | **0** |
| Muertes / combate / monstruos / comandos amplios | **0** |
| Cuentas creadas / progresion | **0** |

---

## 9. Controles de falso positivo

| Falso positivo | Como se cierra |
|---|---|
| el comercio nunca se abrio en el borde | se exige que el **servidor** devuelva la oferta propia del solicitante |
| la geometria no era la que se cree | las tres separaciones se leen del **estado autoritativo** y se comparan una por una |
| los participantes estaban en pisos distintos | `dz` se verifica en las tres mediciones |
| el objeto se invalido entre casos | es **el mismo** objeto y se comprueba al final que sigue en su ranura |
| el comercio del positivo quedo abierto | se exige **cierre confirmado en los dos lados** antes de seguir |
| el rechazo fue por linea de tiro | el mensaje de esa guarda se detecta **por separado** e invalida la medicion |
| el rechazo fue por otra razon | en la ventana de medicion se manda **una sola** solicitud de comercio y nada mas |
| no hubo respuesta por transporte roto | el positivo, con el mismo transporte, **si** obtuvo respuesta |
| se rechazo pero igual abrio sesion | se exige **ausencia** de oferta propia en los dos negativos |
| se uso otra contraparte | se resuelve por nombre contra las criaturas visibles, e igual en los tres casos |
| el cliente dibujo un paso que el servidor rechazo | todas las posiciones vienen del servidor |
| el operador influyo | se aparta antes de cada medicion y no participa del comercio |

---

## 10. Diez aserciones, y por que

| # | Asercion | Cierra |
|---|---|---|
| 1 | sesion conectada | leer resultados de una sesion caida |
| 2 | geometria `2,2,0` establecida | medir en otro punto del que se cree |
| 3 | comercio aceptado ahi | objeto invalido, transporte roto, contraparte ausente |
| 4 | geometria `3,2,0` establecida | idem, para el eje X |
| 5 | rechazo por alcance en X | rechazo por otra razon |
| 6 | sin sesion en X | rechazo anunciado pero sesion abierta igual |
| 7 | geometria `2,3,0` establecida | idem, para el eje Y |
| 8 | rechazo por alcance en Y | rechazo por otra razon |
| 9 | sin sesion en Y | idem |
| 10 | el objeto quedo con su dueno | transferencia inadvertida |

**La geometria se congela como asercion y no como guarda** porque es la
**variable independiente** de este fixture: lo que se afirma no es "hubo un
rechazo", sino "a ESTA separacion exacta hubo ESTE resultado". Publicarla es lo
que hace verificable la afirmacion.

**El mensaje y la ausencia de sesion se separan** porque vienen de **fuentes
distintas** —un texto del servidor y el estado de la sesion de comercio—, el
mismo criterio con el que `PARITY-HOUSE-ACCESS-001` separo el mensaje de
denegacion de la posicion que no cambio.

---

## 11. Sin `RECORDED_EVIDENCE`

Se busco antes de congelar. `PRUEBA_VIVA_TRADE_VIP.md` solo dice que el
servidor *"valida alcance"* y que los personajes fueron reunidos *"a alcance de
trade"*: **nunca midio un borde**. Y `PARITY_PHASE2G_TRADE_EXCHANGE.md:429`
declara el borde como hueco **no** certificado.

**El codigo no es evidencia grabada**, y convertir `areInRange<2,2,0>` en una
observacion habria sido inventarla. **`LIVE_ORACLE` unicamente**; el corpus
grabado queda en **9**.

---

## 12. Intentos, y el fallo fue mio

| # | Clasificacion | Que paso |
|---:|---|---|
| 1 | **defecto del arnes (mio)** | el ofertante no llegaba a su casilla: `Sorry, not possible.` |
| 2 | **EXITO** | 46 s, codigo 0, una sola linea `OBSERVATION_JSON` |

### Intento 1: otra vez una criatura, no el terreno

`Tile::queryAdd` (`tile.cpp:581-588`) devuelve `RETURNVALUE_NOTPOSSIBLE` cuando
hay **una criatura** en la casilla destino. El operador se habia quedado
**justo en el camino** del ofertante despues de convocarlo.

Es **exactamente la misma causa** que costo un intento en
`PARITY-HOUSE-GUEST-ACCESS-001`. Que se repitiera significa que la leccion
anterior se habia aplicado solo a ese adaptador, no al metodo. Por eso esta vez
la correccion fue en **dos niveles**:

1. **estructural**: el operador se aparta **antes** de que cada participante
   camine, y las convocatorias se serializan;
2. **de recuperacion**: el caminante detecta que su posicion autoritativa no
   avanza y mete **un paso lateral** para rodear, alternando el lado. Asi un
   bloqueo por ocupacion se resuelve solo en vez de costar un intento entero.

Esto es mecanica del arnes, no del fixture: lo que se afirma es la geometria
**autoritativa verificada despues**, no como se llego a ella.

**La expectativa nunca se modifico**, verificado por hash en los dos intentos:
fixture `e619b6f5…` y `QACase` `364152bf…` byte-identicos antes del primer
lanzamiento y despues del ultimo. Lo unico recongelado fue el adaptador.

---

## 13. Seguridad de procesos

La leccion del turno anterior, donde se mataron dos procesos ajenos por filtrar
por **nombre**:

- cada proceso lanzado por este turno registro su **PID exacto**;
- el unico proceso terminado a mano fue una herramienta de analisis **propia**
  que entro en bucle, identificada por **PID exacto** tras confirmar su linea
  de comandos;
- **procesos ajenos terminados: 0.**

---

## 14. Hashes congelados

Se congelaron **12** antes del primer intento, incluidos a proposito los tres
archivos de origen que fijan la semantica (`game.cpp`, `position.h`,
`tools.cpp`), el transporte y el parser de produccion, y las dos herramientas
genericas.

Despues de la corrida, del wrap y de los dos replays: **todos identicos salvo
el adaptador**, recongelado tras la correccion del arnes. Los **siete**
artefactos certificados previos —los dos de comercio y los tres de casas—
quedaron byte-identicos.

---

## 15. Limitaciones

1. **Sin borde vertical.** Todo ocurrio en `dz = 0`.
2. **Sin AMBOS O NINGUNO** ante un fallo de transferencia, ni rollback.
3. **Sin cancelacion implicita** por desconexion ni por alejarse despues de
   abrir.
4. **Sin cancelacion despues de que un participante acepto.**
5. **Solo la razon de rechazo por alcance entre participantes**; las demas
   razones del comercio siguen sin certificar.
6. **Nada sobre la distancia permitida entre el jugador y el objeto** cuando
   ese objeto no esta en su propio equipo: aca siempre se ofrecio desde el
   equipo.
7. **Una sola direccion por eje.** Los deltas son absolutos en el codigo, pero
   lo observado fue con la contraparte al sureste.

---

## 16. Reproducir

```text
TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER    jugador que ofrece
TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER   contraparte
TVP772_GOD_ACCOUNT / _PASSWORD / _GOD_CHARACTER   operador (solo montaje)
TVP772_RANGE_A         "x,y,z" casilla fija del que ofrece
TVP772_RANGE_OPERATOR  "x,y,z" casilla de convocatoria del operador

Godot --headless --path cliente3d \
    pruebas/prueba_parity_trade_range_boundary_capture.tscn
```

Las tres posiciones de la contraparte se derivan solas de la casilla fija, asi
que no hay forma de configurar una geometria incoherente con lo que el fixture
afirma.

Ningun valor de credencial aparece en el codigo, en el log, en la observacion ni
en este documento.
