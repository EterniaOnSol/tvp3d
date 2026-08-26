# TVP3D - Rendering

## Implementacion actual

`cliente3d/mundo3d.gd` usa:

- MultiMesh para grupos de items repetidos.
- PlaneMesh para suelos.
- BoxMesh para elementos con bloqueo y altura.
- QuadMesh vertical con billboard fijo en Y para decoracion y criaturas.
- PlaneMesh horizontal para bordes de suelo y counters. Los perfiles
  `borde_suelo` vienen de `assets/items772_flags.json`; los counters se
  reconocen por su nombre y conservan el footprint 2x1 o 1x2 del sprite.
- Las casas separan sus piezas: paredes como volumen de altura fija por piso,
  muebles/counters como volumen bajo con footprint del sprite, pisos y techos
  como planos horizontales, y puertas/ventanas/rejas como piezas verticales.
- Las cajas estructurales tienen dos superficies de material: el sprite solo
  se usa en la cara util y los laterales/techos usan material limpio. Esto
  evita estirar una postal 2D sobre las seis caras del volumen.
- atlas de `sprites772` con UV por region.
- mapa de disco por chunks 64x64 y radio alrededor del jugador.

Esto ya demuestra volumen 3D y streaming basico, pero aun mezcla reglas de
forma, escala y coordenadas en el script de escena.

## Arquitectura objetivo

```text
IR de tile
  -> selector de perfil 3D
  -> resolver de adyacencia
  -> builder de chunk
  -> MultiMesh / MeshInstance / colision visual
  -> cache y streaming
```

Un chunk contiene datos y handles de render; no un Node por cada decoracion.
Las criaturas y objetos interactivos siguen siendo entidades separadas porque
necesitan actualizaciones en vivo.

## Escala

La conversion central define `SQM_WORLD_SIZE` y `FLOOR_WORLD_HEIGHT`. La
primera configuracion usa valores de prototipo, pero ninguna otra escena debe
repetirlos. `z=7` es la referencia de superficie y los pisos superiores tienen
altura positiva en mundo 3D, igual que la convencion actual.

## Rendimiento

Se mediran chunks de 32x32 y 64x64 antes de fijar tamano final. Las pruebas
deben registrar tiempo de parseo, construccion, memoria, instancias y FPS con
10k tiles visibles, varios pisos y criaturas.

## Debug obligatorio

El cliente debe poder mostrar Tibia X/Y/Z, id servidor/cliente, flags,
walkability, chunk, world position, item sin mapping, grid y bordes de chunk.
La colision visual nunca sustituye la validacion del servidor.

## Controles portados de 3DTIBIA

El cliente conectado usa ahora el mismo modelo de entrada que resulto mas
comodo en `3DTIBIA/motor3d/main.gd`:

- `WASD`, flechas y teclado numerico para las cuatro direcciones.
- `Q/E/Z/C` y `KP7/KP9/KP1/KP3` para diagonales explicitas.
- Las teclas son relativas a la camara y se redondean a octantes de 45 grados;
  girar la camara no cambia la semantica logica de X/Y.
- Clic izquierdo sobre el mundo calcula una ruta de hasta 128 pasos y envia
  el auto-walk 0x64 de 7.72. TVP valida cada paso.
- La busqueda usa la ventana de mapa cargada en memoria y una cola BFS con
  limite espacial; no lee el archivo de 48 MB por cada vecino del camino.
- El decorado no se reconstruye en cada paso: se conserva durante 12 SQM y
  solo se rearma al acercarse al borde de la ventana visible.
- El jugador se dibuja como entidad independiente con el outfit del servidor
  y se interpola durante el tiempo visual del paso; la posicion logica no se
  predice y solo cambia al llegar la confirmacion de TVP.
- La representacion de decoracion mantiene MultiMesh, pero cada instancia usa
  un solo plano vertical orientado a la camara; las cajas siguen reservadas
  para paredes y objetos que necesitan volumen.
- Los grupos se ordenan por capa antes de volcarse: suelo, planos, muebles,
  paredes y decoracion. El servidor sigue siendo la autoridad de bloqueo.
- Los bordes de pasto ya no usan ese plano vertical: se agrupan como forma
  `ACOSTADA`, con un pequeno offset sobre el ground para evitar z-fighting.
- Boton derecho arrastrado gira/inclina la camara; rueda acerca y aleja.
- Ctrl/Alt bloquean el movimiento para reservar atajos y texto.

La interpolacion visual base usa 0.26 s y multiplica por 3 los pasos
diagonales, siguiendo `3DTIBIA`; el cliente TVP sigue usando la posicion
confirmada por el servidor como fuente de verdad.
