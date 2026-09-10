# TVP3D - Decisions

Las decisiones se conservan por numero. Una decision marcada
`SUPERSEDED` sigue documentando el contexto historico, pero ya no gobierna
trabajo nuevo. Ante conflicto, `AGENTS.md`, `CARRILES.md` y
`ARCHITECTURE.md` V2 tienen precedencia.

## D-001: TVP permanece como servidor

Estado: DECISION HISTORICA. SUPERSEDED por D-007.

Decision original conservada: TVP ya poseia mapa, tiles, pathfinding, combate,
Lua, casas, spawns, persistencia y protocolo 7.72. Reescribirlo en la primera
vertical slice habria duplicado reglas y roto compatibilidad; Godot se integro
entonces como cliente 3D.

Esta razon sigue explicando el puente de migracion y las pruebas de paridad. No
define el runtime final.

## D-002: OTBM es la fuente del decorado estatico

Estado: ACEPTADA PARA IMPORTACION; ALCANCE REVISADO por D-007.

OTBM sigue siendo una fuente primaria para importar y auditar mapa estatico.
El runtime V2 consume datos propios versionados; no depende de leer OTBM ni de
que TVP invalide el cache durante la partida.

## D-003: Coordenadas absolutas no entran directamente al renderer

Estado: ACEPTADA.

Se usa una capa Tibia <-> mundo 3D con ancla, `SQM_WORLD_SIZE` y
`FLOOR_WORLD_HEIGHT`. Es reversible y evita deriva, perdida de precision y
magic numbers repartidos. Las coordenadas SQM siguen siendo dominio; las
transformaciones 3D son presentacion.

## D-004: Primera visualizacion con proxies

Estado: DECISION TRANSICIONAL.

La geometria proxy permite validar topologia y observabilidad antes de crear
assets finales. Un item no mapeado se ve como placeholder y se reporta. Esta
decision no establece billboards, cubos ni proxies como representacion final
de criaturas o monstruos.

## D-005: IR conserva ids y atributos originales

Estado: ACEPTADA Y AMPLIADA por Architecture V2.

Los formatos de cache pueden optimizarse o regenerarse. El intermedio propio
versionado conserva identidad, procedencia, coordenadas, atributos y errores
para que la migracion sea trazable.

## D-006: No tocar TVP core en la primera fase

Estado: DECISION HISTORICA DE LA PRIMERA VERTICAL SLICE.

Los primeros cambios se limitaron a herramientas, cliente y pruebas, y toda
carencia se demostro con fixtures. En V2 el core legacy sigue protegido como
oracle: no se modifica para convertirlo en el servidor final. La nueva
autoridad se implementara incrementalmente en el dominio servidor Godot,
despues de contratos y paridad.

## D-007: Godot headless es el servidor autoritativo final

Estado: ACEPTADA.

El runtime final usa un servidor Godot 4.7 `--headless` como unica autoridad.
TVP/TFS se conserva como oracle de comportamiento, referencia de compatibilidad
y puente temporal de migracion. El juego final no requiere ejecutar el runtime
legacy.

Consecuencias:

- posicion, movimiento, pathfinding, combate, dano, monstruos, spawns,
  inventario, drops, quests, houses, persistencia y reglas pertenecen al
  servidor Godot;
- el cliente solo envia intenciones y presenta estado confirmado;
- los datos se importan a esquemas propios versionados;
- el adaptador 7.72 no se convierte en el protocolo final.

## D-008: La geometria visual nunca define autoridad ni footprint

Estado: ACEPTADA.

Mallas, colliders de picking, skeletons, escalas, pivots y LODs pertenecen a
cliente/assets. La ocupacion logica, colision de gameplay, alcance y reglas SQM
pertenecen al dominio servidor. No existe una conversion implicita de
`visual_bounds` a `logical_footprint`.

## D-009: Monster3D requiere un contrato de assets versionado

Estado: ACEPTADA.

No se implementa un pipeline Monster3D nuevo ni una produccion masiva antes de
publicar `Monster3D Asset Contract`. El contrato debe fijar formato runtime,
escala, ejes, orientacion, pivot, nombres, skeleton archetypes, animaciones
semanticas obligatorias, materiales/PBR, LOD, validacion y requisitos Blender.

Los prototipos previos siguen siendo evidencia transicional. No se promueven a
estandar V2 por existir en el repositorio.

## D-010: La migracion es incremental y guiada por paridad

Estado: ACEPTADA.

La migracion de TVP/TFS al servidor Godot no es un big-bang rewrite. Cada
dominio se congela por contrato, obtiene fixtures contra la oracle, se
implementa en Godot y se compara antes de retirar su dependencia legacy.

Una diferencia de paridad debe clasificarse como bug, regla no migrada o cambio
deliberado. Ninguna de las tres se resuelve eligiendo silenciosamente una
fuente.

## D-011: Estados por capa y payloads de replicacion con owner neutral

Estado: ACEPTADA.

Architecture V2 separa maquinas que antes aparecian juntas bajo
`conexion y mundo`:

- `protocolo-red` posee `CONNECTED`, `NEGOTIATING`, `READY`, `SYNCING`,
  `CLOSING` y `CLOSED`, que describen solo transporte;
- `servidor` posee autorizacion de aplicacion mediante `SessionBindingV2` y
  el lifecycle del proceso/mundo autoritativo;
- `cliente` puede publicar estados de presentacion/UX, pero no convertirlos en
  autorizacion o verdad de gameplay.

La tabla historica `DESCONECTADO/CONECTANDO/EN_MUNDO` se conserva como perfil
1.x superseded. La tabla
`SOLICITADA/VALIDADA/RECHAZADA/APLICADA/EMITIDA` solo describe un lifecycle
interno historico de resolucion de comandos; no es estado de protocolo,
secuencia wire, autoridad cliente, `stream_id/sequence` ni revision de entidad.

Para la dependencia Client V2 se elige **Option B**:

1. Los schemas compartidos de payloads de replicacion pertenecen a
   `modelo-comun`.
2. El servidor es su productor autoritativo.
3. El cliente es su consumidor no autoritativo.
4. El protocolo los transporta sin poseer su semantica.
5. Autorizacion, `SessionBindingV2`, procesamiento de comandos, persistencia,
   seleccion del replication set, decisiones autoritativas, politica de
   `ServerErrorV2` y `COMMAND_REJECTED` permanecen en `servidor`.
6. `modelo-comun` debe publicar una revision antes de Client V2.

La revision recomendada es `modelo-comun 2.1.0`: agregar los schemas neutrales
es compatible con los tipos comunes 2.0.0 ya publicados y no reinterpreta sus
campos. Corresponderia `3.0.0` solo si al redactarlos se cambia de forma
incompatible un schema comun existente.

El siguiente turno contractual debe republicar bajo ownership neutral las
formas hoy publicadas por Server V2 como:

- `tvp3d.server.entity_spawned/2.0.0` (`ENTITY_SPAWNED`);
- `tvp3d.server.entity_core_state_changed/2.0.0`
  (`ENTITY_CORE_STATE_CHANGED`);
- `tvp3d.server.entity_despawned/2.0.0` (`ENTITY_DESPAWNED`);
- `tvp3d.server.core_entity_state/2.0.0` (`CORE_ENTITY_STATE`).

El contrato comun debe fijar los nuevos identificadores neutrales y su regla
de migracion sin cambiar silenciosamente los identificadores anteriores. El
contrato servidor posterior debe consumir esos schemas en vez de redefinirlos.
No se crea dependencia directa entre `servidor` y `cliente`.
