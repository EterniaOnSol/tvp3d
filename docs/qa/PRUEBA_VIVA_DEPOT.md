# Prueba viva del depot

Fecha: 2026-08-29
Carril: qa
Servidor: TVP 7.72 en Docker, puertos 7171/7172

## Que prueba

Que el depot **guarda de verdad**: un objeto puesto ahi sigue estando despues
de cerrar la sesion y volver a entrar. No se simula nada; el objeto se crea con
`/i`, se guarda, se cierra la sesion, se vuelve y se lo saca.

Archivo: `cliente3d/pruebas/prueba_depot_vivo.tscn`.

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d ^
  pruebas/prueba_depot_vivo.tscn
```

No mata a nadie y no toca las cosas de nadie: al terminar, el objeto vuelve a
la mochila del god.

## Como funciona el depot en esta rama

Tres cosas que no son obvias y que costaron varias corridas encontrar.

**1. No alcanza con estar al lado del mueble: hay que pisar la baldosa.**

`data/scripts/movements/other/tiles.lua:7-45` carga el depot cuando el jugador
pisa una baldosa de las que se transforman (aca el item 426), dentro de una
zona de proteccion y con un item de tipo depot en el 3x3 de alrededor. Recien
ahi `Player::loadDepotLocker` deja `currentDepotItem` apuntando al locker de
ese jugador.

Si no se piso la baldosa, `actions.cpp:218-234` abre **el mueble del mapa como
un contenedor comun**. Se ve igual, deja meter cosas, y lo que se guarde ahi no
es de nadie. Es la trampa mas facil de este recorrido.

Ademas el evento es de **entrada**: si el personaje ya estaba parado en la
baldosa al conectarse, no se dispara. La prueba sale a la casilla de al lado y
vuelve a entrar.

**2. Las cosas no van en el locker, van en el `depot chest` de adentro.**

Al abrir el depot cargado, `actions.cpp:222-231` crea dentro del locker un
item `ITEM_DEPOT` (2594, `depot chest`) si no estaba. Ese cofre es el que
contiene lo guardado; el locker solo lo envuelve.

**3. La ventana de contenedor la elige el cliente.**

El ultimo byte del `0x82` dice en que ventana abrir el contenedor
(`parseUseItem` -> `Game::playerUseItem`). Con 0 el servidor reemplaza lo que
ya estuviera abierto ahi. La prueba usa la 0 para la mochila, la 1 para el
locker y la 2 para el cofre. Y volver a usar el mismo contenedor **lo cierra**,
asi que no sirve para "refrescar".

## Recorrido

| Paso | Que hace | Que comprueba |
|---|---|---|
| Baldosa | `/gotopos` afuera y despues a `(32354,32230,7)` | Que el locker abierto traiga el `depot chest`: eso solo pasa si el servidor cargo el depot de ese jugador |
| Objeto | `/i 2599` y se lo busca por nombre en mochila y equipo | Que exista algo entero que mover; un apilable mediria otra cosa |
| Guardar | `0x78` del equipo al cofre | El cofre pasa de N a N+1 |
| Reconectar | logout `0x14`, pausa y login | — |
| Comprobar | Se vuelve a abrir todo | **El objeto sigue en el cofre** |
| Devolver | `0x78` del cofre a la mochila | El cofre vuelve a N y la mochila suma uno |

El depot de Rookgaard salio del mapa del propio servidor: locker server id 2589
en `(32354,32231,7)`, baldosa 426 en `(32354,32230,7)`.

## Resultado del 2026-08-29

```text
Contenedor 2: 'depot chest' con 2 cosas.
  OK  pisar la baldosa carga el depot del jugador, con su cofre
Contenedor 2: 'depot chest' con 3 cosas.
  OK  el objeto entra al depot
Sesion cerrada. Se vuelve a entrar para ver si el depot guardo.
Contenedor 2: 'depot chest' con 3 cosas.
  OK  el depot vuelve a abrirse en la sesion nueva
  OK  EL OBJETO SIGUE EN EL DEPOT DESPUES DE RECONECTAR
  OK  el objeto sale del depot y vuelve a la mochila
Prueba viva del depot: OK
```

## Limites y suciedad conocida

- Solo se prueba el depot de Rookgaard y con un objeto entero. Guardar
  apilables, partir pilas y el tope de `getMaxDepotItems` quedan sin recorrido
  vivo.
- Las corridas fallidas de este mismo dia, antes de entender lo de la baldosa,
  dejaron **dos parcels del god dentro del mueble del mapa** en
  `(32354,32231,7)`. No son de nadie y no rompen nada, pero estan ahi.
- Las parcels y el mailbox son la otra mitad del bloque y todavia no tienen
  prueba viva. Necesitan escribir la etiqueta, que ahora es posible porque
  `protocolo-red` 1.6.0 publico la ventana de texto `0x96`/`0x89`.
