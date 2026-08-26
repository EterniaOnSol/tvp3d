# Estado: assets

Estado: HECHO
Ultimo agente: codex
Ultima actualizacion: 2026-08-25T16:14:54-06:00
Contrato publicado: SI

## Depende de

- Ninguno.

## Hecho

- Publicado `CONTRATO.md` v1.3.0 para el IR OTBM, paridad, chunks y sus
  errores.
- `leer_otbm.py` conserva el callback antiguo y ofrece callback detallado.
- El parser lee count/subtype, action/unique ids, atributos de puerta, casa,
  quests, textos, destinos, duracion, cama y cargas con sus anchos OTBM.
- Los items anidados de contenedores se conservan en `contents`.
- Los atributos desconocidos producen `OTBM_UNSUPPORTED_ATTRIBUTE`; no se
  saltan bytes silenciosamente.
- El exportador produce IR version 2 y la region `rookgaard_100sqm` fue
  regenerada con 20.240 tiles y 25.272 items.
- El IR distingue `ground` real de objetos sin suelo y agrega
  `queryadd_walkable` con la oracle estatica del servidor.
- El exportador conserva el JSON completo y genera indice mas 39 chunks
  espaciales de 32x32 por piso; el visor los carga bajo demanda.
- La suite Python termina en verde: 7 pruebas de walkability, además del
  sintetico con item inline, nodo con atributos, contenido anidado y error de
  atributo desconocido.

## Falta

- Añadir perfiles manuales y reglas de adyacencia, que pertenecen a fases
  posteriores del pipeline.
- La oracle estatica de `Tile::queryAdd(FLAG_PATHFINDING)` esta implementada
  en `herramientas/walkability.py` y se consume desde el exportador y el
  reporte.
- La muestra Rookgaard compara 20.240 tiles: 17.053 coincidencias, 3.187
  diferencias, 3.122 conservadoras y 65 permisivas para `walkable`; los
  20.240 `queryadd_walkable` coinciden con la oracle.
- La union de chunks conserva los 20.240 tiles y 25.272 items del JSON
  auditable.
- `test_ir_chunks` cubre clave espacial, separacion por piso y round-trip por
  posicion; la regresion completa de herramientas termina con 15 pruebas OK.
- El reporte deja documentado que `walkable` historico usa `blockSolid`,
  mientras `queryadd_walkable` usa `blockPathFind`, floor changes, teleports y
  la presencia de suelo; no cambia el comportamiento existente
  silenciosamente.

## Bloqueos activos

- `GIT_NO_DISPONIBLE`: la raiz `TVP3D` no contiene `.git` ni remoto confirmado;
  no se puede hacer commit/push ni inventar una URL.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| `OTBM_ATTR_ITEM` inline se exporta sin atributos | `IOMap::parseTileArea` solo lee su id | si |
| Un atributo OTBM desconocido aborta la importacion | Saltar su ancho desconocido puede desalinear todo el mapa | si |
| `count` es efectivo y `subtype` conserva el valor crudo | Replica la normalizacion de `Item::getItemCount` sin perder auditoria | si |
| Los chunks se particionan por `floor(x/32)`, `floor(y/32)` y `z` | Permite carga bajo demanda sin perder el JSON completo | si |

## Notas para quien retome

- El recorrido completo de `map.otbm` tarda aproximadamente 68--100 s en esta
  maquina; el fixture sintetico cubre errores y anchos sin releer el mapa.
- Los items del fixture real de Rookgaard no contienen atributos persistentes,
  por lo que la prueba de tipos usa un OTBM sintetico.
- El archivo generado es `cliente3d/generated/maps/rookgaard_100sqm.json` y
  ahora declara `version: 2`.
