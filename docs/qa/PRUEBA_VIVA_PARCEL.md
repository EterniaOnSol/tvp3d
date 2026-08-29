# Prueba viva de parcel y mailbox

Fecha: 2026-08-29
Carril: qa
Servidor: TVP 7.72 en Docker, puertos 7171/7172

Estado: **el fallo del servidor esta arreglado**; la prueba todavia no cierra
sola por su propio arnes.

## Que quiere probar

El correo de Tibia completo, sin simular nada: escribir la etiqueta con
destinatario y ciudad, meterla en una parcel, dejar la parcel sobre un mailbox
y comprobar que llega al depot del destinatario.

Archivo: `cliente3d/pruebas/prueba_parcel_vivo.tscn`.

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d ^
  pruebas/prueba_parcel_vivo.tscn
```

Corre en **Thais**, en el continente. En Rookgaard no hay correo, igual que en
el Tibia original. Los personajes de prueba salen en el templo de Thais
`(32369,32241,7)`; su depot esta en `(32354,32231,7)` y el mailbox del mapa en
`(32372,32253,7)`.

## El fallo que estaba y ya no esta

Al usar la etiqueta, el servidor contestaba:

```text
  [srv] You cannot use this object.
```

La causa estaba en `servidor/src/game.cpp:2556-2560`:

```cpp
if (!item->isUseable() && !item->getContainer() && !item->getDoor()
        && !g_actions->hasAction(item)) {
    player->sendCancelMessage(RETURNVALUE_CANNOTUSETHISOBJECT);
    return;
}
```

Un item **escribible** que no esta marcado `useable` en el OTB y no tiene una
action registrada se rechaza **antes** de llegar a
`Actions::internalUseItem` (`actions.cpp`), que es justo donde
`it.canReadText` abriria la ventana de texto:

```cpp
const ItemType& it = Item::items[item->getID()];
if (it.canReadText) {
    if (it.canWriteText) {
        player->setWriteItem(item, it.maxTextLen);
        player->sendTextWindow(item, it.maxTextLen, true);
    }
    ...
}
```

La etiqueta esta bien declarada en los datos
(`servidor/data/items/items.xml:6386-6390`: `writeable=true`, `maxtextlen=80`),
asi que el problema no es de datos sino de esa guarda.

El comentario de la propia guarda dice que se agrego para que contenedores,
puertas y comida siguieran funcionando pese a su flag del OTB. Los items de
leer y escribir quedaron afuera de esa lista.

## Que consecuencias tenia

- No se podia escribir una etiqueta ni una carta, ni leer un cartel.
- Sin etiqueta escrita, `Mailbox::getReceiver` no tenia a quien mandar la
  parcel, asi que el correo entero quedaba inutilizable.

Se probo desde la mochila y desde la mano, y en las dos el servidor respondia
lo mismo: no era un problema de indices ni de posicion.

## El arreglo, ya aplicado y compilado

La guarda ahora deja pasar tambien los items legibles:

```cpp
const ItemType& useItemType = Item::items[item->getID()];
if (!item->isUseable() && !item->getContainer() && !item->getDoor()
        && !useItemType.canReadText && !g_actions->hasAction(item)) {
```

El servidor se reconstruyo con ese cambio y desde entonces, contra el servidor
vivo:

```text
Ventana de texto: item 'label', maximo 80, texto ''.
  OK  usar la etiqueta abre la ventana de texto del servidor
Ventana de texto: item 'label', maximo 80, texto 'Valentino / Thais'.
  OK  el servidor guarda lo que se escribio en la etiqueta
  OK  la etiqueta escrita entra en la parcel
```

El texto se comprueba leyendolo de vuelta, no solo mandandolo.

## Lo que quedo verificado del correo

- La ventana de texto abre, guarda y devuelve lo escrito.
- La etiqueta escrita entra en la parcel.
- **El mailbox se lleva la parcel**: al dejarla encima desaparece de la
  casilla. Se comprobo con la talkaction de diagnostico `/tileinfo`, que
  mostro que la parcel recien dejada ya no estaba mientras una parcel vieja de
  otra corrida seguia ahi.

## Lo que NO esta probado todavia

Que la parcel aparezca dentro del depot del destinatario. Falta por el arnes de
la prueba, no por el servidor:

- El personaje de pruebas acumulo parcels y etiquetas de las corridas fallidas
  y llego a llenar su mochila; para eso se agrego `/limpiarpruebas`.
- Los indices de un contenedor se corren con cada cosa que entra o sale, asi
  que hay que trabajar con posiciones frescas y de a un paso.
- Dos `/i` seguidos en el mismo instante: el servidor se come el segundo.
- Un personaje normal no puede usar `/gotopos`, asi que para mirar SU depot
  hace falta la danza de dos sesiones que ya usan las pruebas de party y de
  trade.

## Lo que si quedo comprobado en el camino

- El mailbox del mapa esta donde dice el OTBM y el cliente lo ve.
- La ventana de texto del cliente: `protocolo-red` 1.6.0 publica el `0x96`
  entrante y el `0x89` saliente, con self-test de bytes exactos.
- El depot del destinatario funciona y guarda entre sesiones
  (`docs/qa/PRUEBA_VIVA_DEPOT.md`).

## Sobre la ciudad de la etiqueta

`Mailbox::sendItem` entrega al depot del **pueblo** que dice la etiqueta
(`town->getID()`). Thais es el pueblo 1 y sus lockers son depot 1, asi que
coinciden. Conviene saber que **ningun locker del mapa usa el depot 10**, que
es el numero de pueblo de Rookgaard: una parcel dirigida ahi caeria en un depot
que nadie puede abrir.
