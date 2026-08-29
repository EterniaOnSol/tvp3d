# Estado: assets

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-29T09:30:50-06:00
Contrato publicado: SI

## Depende de

- Ninguno.

## Hecho

- Publicado `CONTRATO.md` v1.4.0 para el IR OTBM, paridad, chunks y sus
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
- `extraer_items772.py` cruza los 114 corpse roots que puede crear el servidor
  con sus 307 etapas `decayto`; aborta si alguna no resuelve OTB, client id o
  nombre en el catalogo.
- La cadena viva del rat queda probada con numeros: server ids
  `2813 -> 2814 -> 2815 -> 0`, client ids `3994 -> 3995 -> 3996`, todos con
  nombre `dead rat`. El server id 2816/client id 3997 tambien se llama
  `dead rat`, pero no es alcanzable desde esa cadena porque 2815 decae a 0.
- `cliente3d/assets/items772.json` fue regenerado con
  `py -3 herramientas\extraer_items772.py`; resulto byte a byte igual al
  versionado, confirmando que el hueco vivo no era un dato de corpse ausente.
- `test_corpse_decay_coverage.py` cubre la fuente real, fija la cadena del rat
  y demuestra con un caso sintetico que una etapa sin nombre hace fallar la
  auditoria. La suite completa queda en 18 pruebas Python verdes.

## Falta

- Añadir perfiles manuales y reglas de adyacencia, que pertenecen a fases
  posteriores del pipeline.
- El `pila: ?` de la prueba viva no queda explicado por assets: todos los ids
  producibles resuelven. Ese texto representa una entrada de pila vacia, no
  una ficha con nombre vacio; su instrumentacion corresponde a
  `protocolo-red`, que ya tiene el carril abierto. No se toco ese carril.
- La oracle estatica de `Tile::queryAdd(FLAG_PATHFINDING)` esta implementada
  en `herramientas/walkability.py` y se consume desde el exportador y el
  reporte.
- La muestra Rookgaard compara 20.240 tiles: 17.053 coincidencias, 3.187
  diferencias, 3.122 conservadoras y 65 permisivas para `walkable`; los
  20.240 `queryadd_walkable` coinciden con la oracle.
- La union de chunks conserva los 20.240 tiles y 25.272 items del JSON
  auditable.
- `test_ir_chunks` cubre clave espacial, separacion por piso y round-trip por
  posicion; con la regresion de corpses, herramientas termina con 18 pruebas
  OK.
- El reporte deja documentado que `walkable` historico usa `blockSolid`,
  mientras `queryadd_walkable` usa `blockPathFind`, floor changes, teleports y
  la presencia de suelo; no cambia el comportamiento existente
  silenciosamente.

## Bloqueos activos

- Ninguno. El bloqueo historico `GIT_NO_DISPONIBLE` queda compensado: existe
  repositorio Git en `main`, con remoto `origin` confirmado y push autorizado.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| `OTBM_ATTR_ITEM` inline se exporta sin atributos | `IOMap::parseTileArea` solo lee su id | si |
| Un atributo OTBM desconocido aborta la importacion | Saltar su ancho desconocido puede desalinear todo el mapa | si |
| `count` es efectivo y `subtype` conserva el valor crudo | Replica la normalizacion de `Item::getItemCount` sin perder auditoria | si |
| Los chunks se particionan por `floor(x/32)`, `floor(y/32)` y `z` | Permite carga bajo demanda sin perder el JSON completo | si |
| La generacion de items aborta ante un corpse/decay no resoluble | Evita publicar un catalogo que dejaria innombrable un corpse real | si |
| Un alias con nombre real completa un client id cuyo primer server id no tenia nombre | El protocolo solo conserva el client id compartido | si |

## Notas para quien retome

- El recorrido completo de `map.otbm` tarda aproximadamente 68--100 s en esta
  maquina; el fixture sintetico cubre errores y anchos sin releer el mapa.
- Los items del fixture real de Rookgaard no contienen atributos persistentes,
  por lo que la prueba de tipos usa un OTBM sintetico.
- El archivo generado es `cliente3d/generated/maps/rookgaard_100sqm.json` y
  ahora declara `version: 2`.
- Comando exacto del catalogo: `py -3 herramientas\extraer_items772.py`.
- `items772_flags.json` es un artefacto de render separado; este importador no
  lo genera ni lo modifico.
