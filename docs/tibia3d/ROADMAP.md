# TVP3D - Roadmap

## P0 - Bloqueadores

- [x] Confirmar TVP 7.72 y flujo OTBM/protocolo.
- [x] Capa unica y reversible de coordenadas.
- [x] IR de mapa que conserva flags, house_id e ids desconocidos.
- [x] Fixture real de 50x50 o 100x100 con reporte de conversion.
- [x] Pruebas de round-trip y sincronizacion de posicion.

## P1 - Primera vertical slice

- [x] Cargar IR real y agruparlo por chunks.
- [x] Generar suelo, paredes, agua, vegetacion y placeholders.
- [x] Mostrar debug X/Y/Z, ids y chunk.
- [x] Conectar login/juego TVP y mover SQM por SQM.
- [x] Cambiar al menos un piso mediante escalera/rampa real.
- [x] Validar bloqueo contra el servidor mediante respuesta 0xB5.

## P2 - Juego clasico

- [ ] Criaturas, outfits, direcciones y animacion.
- [ ] Items dinamicos, puertas, containers, fields y efectos.
- [ ] Inventario, combate, spells, runes, NPC, trade y depot.
- [ ] Houses, quests, switches y acciones Lua.

## P3 - Calidad y escala

- [ ] Editor de tiles y perfiles 3D.
- [ ] Reglas de adyacencia para bordes, paredes, agua y roofs.
- [ ] Streaming, culling, LOD, MultiMesh y benchmarks.
- [ ] Reporte completo de unmapped items y conversion reproducible.

## P4 - Futuro

- [ ] Modelos 3D de alta calidad y materiales PBR.
- [ ] Camara de tercera persona y free camera de desarrollo.
- [ ] Assets asistidos por IA dentro del mismo mapping determinista.
