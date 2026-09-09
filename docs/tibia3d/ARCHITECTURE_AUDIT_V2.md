# TVP3D - Architecture V2 Audit

Fecha: 2026-09-09

Alcance: declaraciones que podian implicar que TVP/TFS es el servidor final,
que Godot es solo cliente, que `servidor/src` conserva autoridad permanente o
que las criaturas deben seguir como billboards/proxies.

## Clasificacion

- **CURRENT:** coincide con Architecture V2 y gobierna trabajo nuevo.
- **TRANSITIONAL:** describe un adaptador, fixture o runtime legacy que sigue
  util durante la migracion, sin convertirlo en destino final.
- **HISTORICAL:** registra una decision o estado pasado. Se conserva y se marca
  como superseded cuando antes parecia vigente.
- **CONTRADICTORY:** afirmaba como vigente un destino incompatible con
  `AGENTS.md`/`CARRILES.md`. Phase 0 lo reemplaza o reclasifica
  explicitamente.

## Declaraciones CURRENT

| Ocurrencia | Clasificacion | Motivo |
|---|---|---|
| `AGENTS.md`, Proyecto y tabla de decisiones fijas | CURRENT | Define Godot 4.7 headless como servidor autoritativo final y TVP como referencia, no runtime final. |
| `AGENTS.md`, reglas 1, 2, 7 y 8 | CURRENT | Contrato antes de codigo, autoridad servidor, dominio como datos y ownership de rutas. |
| `CARRILES.md`, carriles `servidor`, `cliente` y `assets` | CURRENT | Separa autoridad, presentacion e importacion; asigna el servidor propio a Godot. |
| `CARRILES.md`, ruta reservada `servidor/data/` | CURRENT | Declara los datos TVP como referencia externa de solo lectura. |
| `worklog/modelo-comun/CONTRATO.md`, Posicion/Entidad/Intencion | CURRENT | Posicion y acciones pertenecen al servidor; assets visuales quedan fuera del dominio. |
| `worklog/servidor/CONTRATO.md`, Proposito/perfil propio | CURRENT | Ya especifica una autoridad Godot `--headless`, aunque el mismo archivo acumula deuda legacy indicada abajo. |
| `worklog/protocolo-red/CONTRATO.md`, perfil propio v1 | CURRENT | Mantiene separado el protocolo JSON propio del adaptador 7.72. |
| `cliente3d/servidor_propio/main.gd` y `servidor.tscn` | CURRENT | Son el andamiaje existente del servidor Godot; Phase 0 no los modifica ni afirma que esten completos. |

## Declaraciones que eran CONTRADICTORY

| Ocurrencia antes de Phase 0 | Clasificacion previa | Reconciliacion |
|---|---|---|
| `docs/tibia3d/ARCHITECTURE.md`, “Se conserva TVP como servidor autoritativo y Godot como cliente 3D” | CONTRADICTORY | Documento reescrito como Architecture V2; TVP queda como oracle/puente. |
| `docs/tibia3d/ARCHITECTURE.md`, diagrama TVP -> cliente y lista “TVP decide...” sin horizonte de retiro | CONTRADICTORY | Reemplazado por importadores/IR -> servidor Godot + cliente Godot. |
| `docs/tibia3d/ARCHITECTURE.md`, “no cambian servidor/src” como regla futura | CONTRADICTORY | Conservado solo como proteccion del oracle; la autoridad nueva vive en dominio Godot. |
| `docs/tibia3d/DECISIONS.md`, D-001 aceptada: “TVP permanece como servidor” | CONTRADICTORY | D-001 se conserva como historica y queda SUPERSEDED por D-007. |
| `docs/tibia3d/MASTER_PLAN.md`, mision/alcance: autoridad, persistencia y reglas permanecen en TVP | CONTRADICTORY | Plan reemplazado por las fases 0..10 de Architecture V2. |
| `docs/tibia3d/MASTER_PLAN.md`, “no crear un segundo servidor” como prohibicion permanente | CONTRADICTORY | Sustituido por migracion incremental al servidor Godot; se mantiene la prohibicion de big-bang. |
| `docs/tibia3d/STATUS.md`, “TVP sigue siendo la autoridad... no el servidor Godot provisional” | CONTRADICTORY | Archivo marcado como snapshot historico superseded; no gobierna trabajo nuevo. |
| `docs/tibia3d/AGENTS.md`, “Un rol no reescribe el servidor TVP por conveniencia” sin contexto V2 | CONTRADICTORY/AMBIGUOUS | Se limita a no mutar el oracle legacy; el carril servidor si migra reglas a Godot con contrato/paridad. |
| `docs/tibia3d/REPOSITORY_AUDIT.md`, conclusion “servidor/src ... quedan como autoridad” | CONTRADICTORY | Auditoria marcada historica; esa frase describe el estado observado en 2026-08-25, no el destino. |
| `docs/tibia3d/NETWORK_PROTOCOL.md`, “Direccion futura” que mantenia 7.72 y solo preveia extended opcode | CONTRADICTORY | Reclasificado como contrato legacy transicional; el protocolo final es propio/versionado. |
| `LEEME.md`, introduccion “el servidor es TVP tal cual viene y el cliente es ... Godot” | CONTRADICTORY | Introduccion reemplazada por el objetivo V2; las instrucciones TVP quedan como operacion transicional/historica. |
| `LEEME.md`, “Relevo inmediato ... Cyclops” y orden de integrar monstruos antes de contratos V2 | CONTRADICTORY | Handoff marcado superseded; no autoriza pipeline ni implementacion antes de Phases 5 y 6. |
| `LEEME.md`, “TVP sin tocar” / “Nada del servidor se modifica” | CONTRADICTORY si se lee como destino | La nota superior lo clasifica como snapshot operativo legacy; no limita el nuevo servidor Godot. |

## Declaraciones TRANSITIONAL

| Ocurrencia | Clasificacion | Tratamiento |
|---|---|---|
| `servidor/`, `ARRANCAR SERVIDOR.bat`, `PARAR SERVIDOR.bat`, `web/docker-compose.yml` | TRANSITIONAL | Mantienen el entorno TVP/Docker de paridad y no se modifican en Phase 0. |
| `cliente3d/red/conexion772.gd` y comentarios que llaman a TVP autoridad | TRANSITIONAL | Correctos dentro del adaptador: TVP es la oracle/autoridad de esa sesion legacy, no del producto final. |
| `docs/tibia3d/NETWORK_PROTOCOL.md`, detalles RSA/XTEA/opcodes | TRANSITIONAL | Contrato de compatibilidad para fixtures y vertical slices; no es el protocolo V2. |
| `docs/qa/PRUEBA_VIVA_*.md` y `docs/qa/PARIDAD_772_2026-08-29.md` | TRANSITIONAL | Evidencia de paridad contra TVP; mencionar servidor TVP es parte de la precondicion de prueba. |
| `worklog/qa/CONTRATO.md`, servidor TVP como fuente viva | TRANSITIONAL | La fuente viva es la oracle de esa suite; Phase 1 debe evitar que se interprete como autoridad final. |
| `worklog/integracion/CONTRATO.md`, perfiles legacy y propio | TRANSITIONAL | Los dos perfiles permiten migracion incremental; el criterio legacy no es criterio de retiro final. |
| `worklog/protocolo-red/CONTRATO.md`, “Compatibilidad TVP 7.72” | TRANSITIONAL | Mantiene frontera separada, coherente con D-007. |
| `worklog/cliente/CONTRATO.md`, secciones del runtime TVP 7.72 | TRANSITIONAL | Describen el cliente actual y fallbacks; deben consumirse como puente, no como destino. |
| `worklog/servidor/CONTRATO.md`, “Sala del pergamino de Demon” legacy junto al perfil Godot | TRANSITIONAL / CONTRACT DEBT | Mezcla una regla legacy con el contrato nativo. Se conserva publicado y se separa en Phase 1, sin reescribir historia en Phase 0. |
| `cliente3d/project.godot`, etiqueta “el cliente 3D” | TRANSITIONAL | Nombre del proyecto cliente existente, no prohibicion de un servidor Godot. |

## Billboards y proxies

| Ocurrencia | Clasificacion | Motivo |
|---|---|---|
| `docs/tibia3d/DECISIONS.md`, D-004 | TRANSITIONAL | Los proxies validan la primera visualizacion; no son el destino. |
| `docs/tibia3d/RENDERING.md`, Implementacion actual y “QuadMesh ... para criaturas” | TRANSITIONAL | Describe el renderer existente. Se agrega una nota explicita de que no fija Monster3D. |
| `docs/tibia3d/STATUS.md`, billboard/proxy | HISTORICAL | Snapshot fechado de la primera vertical slice. |
| `LEEME.md`, billboard para criaturas y checkpoints de monsters | HISTORICAL/TRANSITIONAL | Evidencia del prototipo pre-V2; no es un contrato futuro. |
| `cliente3d/mundo3d.gd`, `_crear_billboard_jugador`, comentarios y material billboard | TRANSITIONAL | Implementacion/fallback actual. Phase 0 no refactoriza el archivo. |
| `cliente3d/propio/personajes3d/LEEME.md`, fallback billboard | TRANSITIONAL | Fallback para outfits no soportados, no requisito permanente. |
| `worklog/cliente/CONTRATO.md` y `STATE.md`, transiciones billboard <-> volumen | HISTORICAL/TRANSITIONAL | Contrato y evidencia del renderer existente; no sustituyen Monster3D Asset Contract V2. |
| `cliente3d/propio/monstruos3d/*`, tests “sin billboard” y notas de fallback | TRANSITIONAL | Prototipos precontrato conservados; no se amplian en Phase 0. |
| Billboards de UI/FX en `dialogo_3d.gd`, `numero_dano_3d.gd` y etiquetas del visor | CURRENT/NOT APPLICABLE | Son tecnicas de presentacion para texto/FX, no autoridad ni representacion permanente de monstruos. |

## Registros HISTORICAL

| Ocurrencia | Clasificacion | Tratamiento |
|---|---|---|
| `worklog/EVENTS.jsonl`, todas las entradas previas de TVP, world-render y monsters | HISTORICAL | Append-only. No se reescriben; el evento de Phase 0 se agrega al final. |
| `worklog/*/STATE.md`, secciones fechadas y checkpoints | HISTORICAL con estado operativo actual | No se borran. Sus pendientes legacy alimentan paridad y deuda contractual. |
| `docs/tibia3d/STATUS.md` (2026-08-27) | HISTORICAL | Se conserva completo con aviso superseded. |
| `docs/tibia3d/REPOSITORY_AUDIT.md` (2026-08-25) | HISTORICAL | Conserva el inventario observado; su conclusion de autoridad no es normativa. |
| `docs/tibia3d/ROADMAP.md` pre-V2 | HISTORICAL | Se marca superseded por `MASTER_PLAN.md` V2. |

## Resultados que no son contradiccion

Las menciones operativas a “servidor TVP” en pruebas, scripts de arranque,
CMake, Docker y herramientas no afirman permanencia: identifican el proceso
contra el que corre una prueba o el origen que se extrae. Del mismo modo,
“servidor” sin “TVP” en reglas de autoridad es compatible con V2 cuando se
refiere al rol y no a la implementacion C++.

## Deuda que queda para Phase 1

- Separar en contratos vigentes lo nativo, lo legacy y lo puramente visual.
- Versionar identidad y dominio comun sin depender de looktype o ids de
  archivo como identidad canonica.
- Definir el protocolo V2 mas alla del framing propio inicial.
- Publicar reglas de logical footprint independientes de la geometria.
- Resolver el `modelo-comun` aun marcado `EN_CURSO` y reclasificar el
  bloqueo QA legacy sin borrar sus registros.
