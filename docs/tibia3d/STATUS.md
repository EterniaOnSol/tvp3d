# TVP3D - Status

Fecha: 2026-08-27

## Current Phase

Fase 2: primera vertical slice funcional sobre datos reales. La ruta validada
es `map.otbm -> IR JSON -> visor Godot` y, por separado, `TVP 7.72 -> cliente
Godot` para login, movimiento y estado vivo.

## Completed

- Mapa real localizado en `servidor/data/world/map.otbm`.
- Cabecera OTBM confirmada: 65000 x 65000, 439038 areas.
- Inspector real de SQM en `herramientas/tibia3d_map.py`.
- IR versionado en `cliente3d/generated/maps/rookgaard_100sqm.json`.
- IR v2 conserva `count`, `subtype`, atributos OTBM tipados y contenidos de
  items anidados; `OTBM_ATTR_ITEM` inline conserva su semantica de solo id.
- Catalogo e IR conservan tambien `block_pathfind`, separado de `blocking`.
- Cada tile exportado incluye `queryadd_walkable`, separado de `walkable`,
  con la regla estatica de pathfinding del servidor.
- Region exportada: x 32047..32146, y 32169..32268, z 6..8.
- 30000 SQM de volumen, 20240 tiles con datos y 25272 items.
- 432 ids unicos; 25271 ocurrencias con sprite y 1 ocurrencia unmapped.
- Item unmapped reportado: server id 459, client id 469, stairs, en
  (32093, 32235, 6). Se renderiza como cubo magenta en el cliente.
- Clasificacion automatica inicial de ground, water, wall, door, stairs,
  vegetation, furniture, containers y decoration.
- Transformacion reversible centralizada en `comun/coordenadas_tibia.gd`.
- Visor `pruebas/visor_region.tscn`: carga el IR real, crea 69 grupos por
  categoria/chunk, muestra HUD, rejilla, jugador, bloqueo y tile inspector.
- Cliente principal Godot renderiza el mapa real por chunks 64x64 con sprites
  DAT/SPR y placeholder visible para ids sin representacion.
- Camara inicial alineada con `3DTIBIA`: FOV 60, distancia 14 SQM,
  inclinacion 32 grados y giro 0.
- Jugador visual separado de `EstadoMundo`: conserva la casilla confirmada por
  TVP y anima el recorrido visual entre confirmaciones, con outfit 7.72 cuando
  el servidor lo informa.
- Decoracion `LAMINA` cambiada de cruces de planos a QuadMesh vertical con
  billboard fijo en Y; la captura visual ya no muestra la duplicacion de
  triangulos de la variante anterior.
- Bordes de pasto y counters corregidos: usan una forma `ACOSTADA` con
  `PlaneMesh` horizontal; los counters conservan el footprint 2x1/1x2 y su
  bloqueo logico.
- Construcciones en iteracion: counters, mesas, bordes y techos horizontales;
  paredes bloqueadoras como segmentos orientados por vecinos; montanas y
  acantilados separados de las paredes para no convertirlos en edificios.
- La vista jugable ahora filtra estrictamente el piso activo; `F6` muestra u
  oculta temporalmente `Z+1` solo para depuracion, evitando que paredes y
  escaleras del piso inferior invadan la escena.
- `435` sewer grate, `437` stairs y `1948` ladder tienen mapping horizontal;
  la reja y las escaleras descendentes se renderizan ligeramente por debajo
  del suelo. El cliente principal ya carga `assets/mappings/items.json`.
- Map Editor Godot inicial en `cliente3d/editor/editor3d.tscn`: region real,
  seleccion de SQM, inspector de sprite y mapping visual editable por itemId.
- TVP Docker activo: server en 7171/7172 y MariaDB healthy.
- Login, entrada al mundo y cuatro movimientos validados contra TVP 7.72.
- Controles portados de `3DTIBIA`: ocho direcciones relativas a camara,
  diagonales explicitas, clic izquierdo auto-walk 0x64, boton derecho para
  girar y rueda para zoom.
- `prueba_autowalk.tscn`: TVP confirmo un paso enviado por 0x64.
- Capturas visuales verificadas en `cliente3d/region_capture.png`,
  `cliente3d/captura_region_texturizada.png` y `cliente3d/captura_tvp.png`.
- Reporte estatico `walkability_parity.json`: 20.240 tiles comparados,
  17.053 coincidencias y 3.187 diferencias para el `walkable` historico;
  `queryadd_walkable` coincide en los 20.240 tiles.
- Paridad viva ejecutada contra TVP: ventana 9x9 en `(32097,32206,7)`,
  81/81 tiles coincidentes y 1 criatura excluida por ser estado dinamico.
- Streaming del IR de depuracion: indice y 39 chunks de 32x32 por piso;
  el visor carga los chunks bajo demanda y reconstruye los 20.240 tiles sin
  leer el JSON completo.
- Transicion de piso validada contra una escalera real: z7 -> z6 -> z7,
  posiciones `(32080,32202,6)` y `(32080,32204,7)`, personaje restaurado.
  La rama actual de TVP emitio 0x64 con mapa completo en ambas transiciones;
  el parser conserva observabilidad para 0xBE/0xBF cuando esa ruta aparezca.
- Inspector conectado integrado en la escena principal: `F4` muestra/oculta
  el panel y `Shift+click` fija un SQM; combina stack vivo de TVP con flags y
  metadatos del IR por chunks.
- Catálogo de spells 7.72 extraído de Lua en `assets/spells772.json`; el
  spellbook muestra requisitos y envía las palabras exactas por `0x96`, dejando
  la validación de reglas en TVP.
- Sprites de animación importados desde DAT/SPR: 25 efectos, 15 proyectiles y
  outfits multiframe. El cliente consume `0x83`-`0x85` para efectos, textos y
  proyectiles, y `0x8E` actualiza el outfit confirmado de una criatura.
- Magic Wall integrada desde la implementacion de 3DTIBIA: cubo 1x2x1,
  tres frames originales a 5 FPS para client ids 2128/2129 y reemplazo seguro
  de la instancia cuando TVP actualiza una casilla.

## In Progress

- Validar en vivo la vertical slice de items: runas, mana fluid, life ring,
  pilas de monedas y contenedores redimensionables.
- Recuperar el arranque de `server` después del reinicio de Docker; la imagen
  C++ ya recompiló y MariaDB responde en `3371`, pero `7171/7172` aún están
  pendientes de verificación.
- Continuar con puertas, fields, quest log y combate avanzado sobre el estado
  confirmado por TVP.

## Next P0

1. [x] Preservar atributos OTBM sin perder count, subtype, unique/action ids y
   referencias de puerta/house.
2. [x] Anadir prueba automatizada de paridad IR vs estado vivo para una
   ventana.
3. [x] Hacer streaming del IR de depuracion por chunks, manteniendo el JSON
   completo como artefacto auditable.
4. [x] Cerrar la validacion de piso; empezar combate/items dinamicos.

## Known Problems

- `assets/mapa772/mapa.bin` es un cache de render: no incluye flags, casas ni
  atributos completos; el IR JSON es la fuente de auditoria.
- El IR conserva los atributos conocidos por `servidor/src/iomap.h`; si el
  servidor incorpora un atributo OTBM nuevo, el importador falla de forma
  explicita hasta ampliar el contrato.
- El campo `walkable` historico todavia usa `blockSolid`; no debe tratarse como
  una decision final de pathfinding. `queryadd_walkable` es el campo estatico
  alineado con `Tile::queryAdd`; quedan 3.187 diferencias solo para migrar
  consumidores del campo historico.
- La clasificacion actual usa metadata de `items.otb` y nombres; necesita
  perfiles manuales y reglas de adyacencia para bordes y paredes conectadas.
- Algunos techos y piezas de borde siguen necesitando perfiles de forma propios;
  el billboard unico resolvio el artefacto general, pero no reemplaza las
  reglas de adyacencia del mapa.
- Las paredes proxy del piso activo todavía necesitan modelos/perfiles de
  construcción para dejar de verse como segmentos cafés genéricos.
- El build local de C++ no se ejecuta fuera de Docker; el servidor Docker si
  esta levantado y fue probado funcionalmente.

## Technical Debt

- Separar perfiles de item, resolver de adyacencia y renderer.
- Versionar formalmente el cache binario y las tablas de assets.
- Persistir metadata fuente en cada instancia de render para picking preciso.
- El directorio raiz TVP3D no tiene git; no se puede afirmar commit/push local.

## Tests

- `test_coordenadas.tscn`: round-trip, ancla, pisos y chunk; todo OK.
- `python -m unittest herramientas.test_tibia3d_map`: 5 pruebas, incluyendo
  atributos sinteticos, items anidados, atributo desconocido, parser real y
  fixture IR v2; todo OK.
- `python -m unittest herramientas.test_walkability`: 7 pruebas de la oracle
  estatica, direccion de mismatch y validacion de `queryadd_walkable`; todo
  OK.
- `pruebas/prueba_paridad_ventana.tscn`: TVP real, ventana 9x9, 81 tiles
  coincidentes, 0 diferencias y codigo de salida 0.
- `python -m unittest herramientas.test_ir_chunks`: 3 pruebas de clave
  espacial, separacion por piso, round-trip y archivos de indice; todo OK.
- `visor_region.tscn --headless --quit-after 2`: cargo 39 chunks, 20.240
  tiles y 69 grupos; todo OK.
- `test_ir_trozos.tscn`: dos ventanas cargadas bajo demanda y cache acotado a
  1 chunk al cambiar de zona; todo OK.
- `prueba_cambio_piso.tscn`: escalera real, z7 -> z6 -> z7, 2 transiciones
  recibidas por 0x64, 0xBE/0xBF directos 0, posicion restaurada y codigo 0.
- Reporte de piso: `cliente3d/generated/reports/floor_transition.json`.
- `main.tscn --headless --quit-after 1200`: escena conectada carga el panel
  del inspector sin errores de GDScript.
- `prueba_spells_animaciones.tscn`: catálogo, assets multiframe, eventos
  `0x83`-`0x85`, cambio de outfit `0x8E`, alineación y lanzamiento `0x96`; todo
  OK.
- `prueba_magic_wall.tscn`: cubo, texturas originales, animación, variante
  persistente y registro/ocultado del objeto dinámico; todo OK.
- Inspector puntual: `(32097,32219,7)` -> ground server 407/client 410,
  flag `REFRESH`, walkable `True`, blocking `False`.
- `prueba_login.tscn`: login, personaje, entrada al mundo, cuatro movimientos;
  resultado OK, 14 mensajes recibidos.
- `prueba_autowalk.tscn`: resultado OK, posicion confirmada por servidor.
- `test_controles.tscn`: octantes y opcodes diagonales; todo OK.
- `test_formas_render.tscn`: bordes de pasto planos, counters/mesas como
  piezas horizontales y pared estructural; todo OK.
- `editor/editor3d.tscn -- --self-test`: mapa real cargado, 7309 casillas
  visibles e inspector inicializado con item 870; todo OK.
- Captura visual del editor: `cliente3d/editor/captura_editor.png`, UI y
  region real inspeccionadas.
- La ruta de clic ahora trabaja sobre la ventana de mapa ya cargada en memoria,
  con BFS acotado a 8192 casillas; evita bloquear el hilo principal.
- La reconstruccion del decorado se espacia a 12 pasos para evitar tirones.
- Godot headless: `visor_region.tscn` carga 20240 tiles y 69 grupos sin errores.
- Godot grafico: `captura_tvp.png` inspeccionada; 13678 cosas, 335 grupos,
  FOV 60, distancia de camara 27.6 en captura conectada y 60 FPS medidos.
- Visor grafico controlado: `captura_region_texturizada.png` inspeccionada en
  (32091, 32187, 7), distancia 14.3, 60 FPS; construcciones sin picos
  triangulares de BoxMesh.

## Build Status

- Godot 4.7.2: escenas y scripts de la vertical slice cargan sin errores.
- TVP Docker: imagen de `server` recompilada; `mariadb` responde en `3371` y
  `server` aún debe quedar operativo en `7171/7172` tras el reinicio de Docker.
- Docker: `phpmyadmin` queda en el perfil opcional `admin` y no arranca por
  defecto; la web MyAAC permanece separada para crear y cargar personajes.
- C++: sin compilacion nativa separada; la imagen Docker existente es la que
  se esta usando.

## Important Decisions

Ver `DECISIONS.md`. TVP sigue siendo la autoridad. El visor IR es una
herramienta de validacion y el camino jugable es `cliente3d/main.tscn` contra
el protocolo 7.72, no el servidor Godot provisional.
