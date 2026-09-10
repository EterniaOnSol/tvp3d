# CARRILES.md

Cada carril es asignable a un solo agente por turno. Las rutas listadas son de
propiedad exclusiva salvo las rutas compartidas que aparecen abajo.

## Carriles

### modelo-comun

Objetivo: definir las entidades, coordenadas, tiles, acciones, transiciones y
payloads neutrales de replicacion que comparten servidor, cliente, editor y
pruebas.

Depende de: ninguno.

Contrato: `worklog/modelo-comun/CONTRATO.md`, con esquemas concretos y tablas
de dominio.

Rutas: `cliente3d/comun/modelo_*.gd`, `cliente3d/comun/mapa_*.gd`.

Cierre: una prueba carga el vocabulario y rechaza un estado, tile o transicion
fuera de la tabla publicada.

### protocolo-red

Objetivo: transportar mensajes versionados entre cliente y servidor sin que el
cliente pueda mutar estado autoritativo.

Depende de: `modelo-comun`.

Contrato: `worklog/protocolo-red/CONTRATO.md`, con framing, mensajes, errores y
compatibilidad.

Rutas: `cliente3d/comun/protocolo_*.gd`, `cliente3d/red/` y los adaptadores de
red dentro de `cliente3d/servidor_propio/protocolo/`.

Cierre: prueba de fragmentacion, concatenacion, paquete invalido y round-trip
de cada mensaje del contrato.

### servidor

Objetivo: ejecutar el mundo autoritativo en Godot headless, incluyendo
movimiento, reglas, entidades, persistencia y servicios de partida.

Depende de: `modelo-comun`, `protocolo-red`, `assets`.

Contrato: `worklog/servidor/CONTRATO.md`, con comandos aceptados, eventos,
errores, autoridad y persistencia.

Rutas: `cliente3d/servidor_propio/`, `servidor_godot/`,
`cliente3d/data/servidor/`.

Cierre: dos clientes reciben el mismo estado; un cliente no puede atravesar un
tile bloqueado ni inventar un resultado; el proceso arranca con `--headless`.

### cliente

Objetivo: presentar el mundo jugable en 3D, enviar intenciones y representar
solo el estado confirmado por el servidor.

Depende de: `modelo-comun`, `protocolo-red`, `assets`.

El cliente no depende de `servidor`. Los schemas de estado replicado que
ambos necesitan pertenecen a `modelo-comun`: servidor los produce con
autoridad, cliente los consume sin autoridad y `protocolo-red` solo los
transporta. Si un payload compartido aparece primero en el contrato servidor,
debe publicarse en `modelo-comun` antes de convertirlo en dependencia cliente.

Contrato: `worklog/cliente/CONTRATO.md`, con estados visuales, input,
reconexion y limites de autoridad.

Rutas: `cliente3d/propio/`, `cliente3d/ui_propio/`,
`cliente3d/escenas/cliente/`.

Cierre: un usuario conecta, ve un mapa 3D, camina con teclado, observa otro
jugador y no puede consolidar un movimiento rechazado.

### assets

Objetivo: importar mapa, sprites, items y metadatos de Tibia a formatos
versionados que puedan consumir el servidor, cliente y editor.

Depende de: ninguno para publicar el contrato; de `modelo-comun` para
implementar exportadores.

Contrato: `worklog/assets/CONTRATO.md`, con formatos de entrada, salida,
versionado, ids y errores de importacion.

Rutas: `herramientas/`, `cliente3d/assets/propios/`, `assets/importados/`.
Los datos originales de `servidor/data/` son referencia de solo lectura.

Cierre: importar un fixture pequeno y reproducir la misma salida byte a byte o
con una regla de normalizacion documentada.

### editor

Objetivo: editar el mapa y asignar a cada id 2D un perfil 3D exportable sin
romper coordenadas ni ids originales.

Depende de: `modelo-comun`, `assets`.

Contrato: `worklog/editor/CONTRATO.md`, con formato de proyecto, operaciones,
guardado, undo/redo y exportacion.

Rutas: `cliente3d/editor/`, `herramientas/editor/`, `assets/proyectos/`.

Cierre: abrir un fixture, cambiar un tile y un perfil 3D, guardar, recargar y
obtener exactamente el mismo resultado.

### integracion

Objetivo: ensamblar escenas, configuracion, comandos de arranque y empaquetado
del servidor y cliente.

Depende de: `servidor`, `cliente`, `editor`, `assets`.

Contrato: `worklog/integracion/CONTRATO.md`, con comandos, puertos, rutas de
datos y perfiles de ejecucion.

Rutas: `cliente3d/project.godot`, `*.bat`, `config/`,
`cliente3d/escenas/arranque/`.

Cierre: una maquina limpia puede arrancar servidor, cliente y editor con los
comandos documentados; los perfiles no imprimen secretos.

### qa

Objetivo: probar contratos y recorridos completos, y bloquear regresiones de
autoridad, red, assets, editor y arranque.

Depende de: todos los contratos anteriores; implementacion de cada carril para
las pruebas de integracion.

Contrato: `worklog/qa/CONTRATO.md`, con matriz de pruebas, fixtures y reporte.

Rutas: `cliente3d/pruebas/`, `qa/`, `docs/qa/`.

Cierre: checklist automatizado con codigo de salida distinto de cero ante
fallos y un reporte reproducible para una revision cruzada.

## Rutas reservadas y compartidas

| Ruta | Propietario | Regla |
|---|---|---|
| `AGENTS.md`, `CARRILES.md`, `PROMPTS.md`, `PLANTILLAS.md` | Orquestacion | Solo cambia al actualizar el sistema de gobierno |
| `worklog/` | Todos, con append-only en `EVENTS.jsonl` | Cada carril escribe solo su `STATE.md` y `CONTRATO.md` |
| `cliente3d/project.godot` | Integracion | Otros carriles solicitan cambios en su worklog |
| `cliente3d/comun/` | Modelo comun y protocolo, por archivo | Ningun carril cambia el archivo del otro |
| `cliente3d/assets/` | Assets | Cliente y editor consumen; no editan fuentes |
| `servidor/data/` | Ningun carril de produccion | Solo lectura, referencia externa del TVP actual |

## Fuente de verdad del dominio

Las tablas que un contrato vigente califica como normativas son datos de
dominio: el codigo debe cargarlas/validarlas y las pruebas deben generarse
desde ellas, sin duplicarlas en condicionales. Las tablas marcadas historicas
se conservan como evidencia y no se cargan como autoridad V2.

### Ownership de estados Architecture V2

No existe una maquina unica que mezcle transporte, autorizacion de aplicacion
y presentacion del mundo. Cada estado tiene un solo owner contractual:

| Capa | Owner | Estados vigentes | Regla |
|---|---|---|---|
| Transporte Protocol V2 | `protocolo-red` | `CONNECTED`, `NEGOTIATING`, `READY`, `SYNCING`, `CLOSING`, `CLOSED` | `READY` solo significa transporte negociado; no concede autorizacion ni entrada al mundo |
| Autorizacion de aplicacion/sesion | `servidor` | `UNBOUND`, `AUTHORIZED`, `REVOKED` en `SessionBindingV2` | Solo `AUTHORIZED` puede habilitar comandos para el actor ligado; el servidor decide la transicion |
| Lifecycle del proceso y mundo autoritativo | `servidor` | `BOOTING`, `LOADING_DATA`, `VALIDATING_DATA`, `READY`, `DRAINING`, `STOPPED`, `FAILED` | No es el `READY` de transporte y no es estado de UI |
| Presentacion/UX del mundo | `cliente` | Lo que publique su contrato V2, si lo necesita | Describe pantalla e interaccion local; nunca autoriza sesion, actor ni estado de gameplay |

La coincidencia textual de `READY` entre dos contratos no une sus maquinas:
siempre debe calificarse como `ProtocolConnectionStateV2.READY` o
`ServerLifecycleStateV2.READY`.

### Perfil historico de conexion/mundo 1.x

La tabla siguiente se conserva como significado historico del prototipo
propio y de su UX. Esta `SUPERSEDED` para Architecture V2: no es autoridad de
`protocolo-red` 2.0.0, no sustituye `SessionBindingV2` y ningun agente debe
usarla para validar una sesion o payload V2.

| Estado | Evento valido | Siguiente |
|---|---|---|
| `DESCONECTADO` | `CONECTAR` | `CONECTANDO` |
| `CONECTANDO` | `BIENVENIDA` | `EN_MUNDO` |
| `CONECTANDO` | `ERROR_RED` | `DESCONECTADO` |
| `EN_MUNDO` | `CERRAR` | `DESCONECTADO` |
| `EN_MUNDO` | `ERROR_RED` | `DESCONECTADO` |

### Lifecycle interno historico de resolucion de comandos

La tabla siguiente se conserva como concepto interno para describir como la
autoridad resolvia una accion. No es la maquina de conexion de Protocol V2,
no es una secuencia de eventos wire y no concede autoridad al cliente.
Tampoco sus estados son valores de `CommandEnvelopeV2.type` o
`AuthoritativeEventEnvelopeV2.type`, ni equivalen a
`stream_id/sequence` o a la `revision` de una entidad.

Si una implementacion V2 conserva este lifecycle para diagnostico interno,
pertenece al procesamiento de comandos del `servidor`. Hacia la red solo se
publican el evento autoritativo o el rechazo cuyo schema haya sido contratado.

| Estado | Evento valido | Siguiente |
|---|---|---|
| `SOLICITADA` | `VALIDAR` | `VALIDADA` o `RECHAZADA` |
| `VALIDADA` | `APLICAR` | `APLICADA` |
| `APLICADA` | `EMITIR` | `EMITIDA` |
| `RECHAZADA` | `NOTIFICAR` | `EMITIDA` |

### Vocabulario inicial de tiles

`SUELO`, `PARED`, `AGUA`, `ARBOL`, `ROCA`, `DECORACION`, `ESCALERA`.

Un importador que reciba otro valor debe fallar con el id y el archivo de
origen; no debe convertirlo silenciosamente en `SUELO`.

## Grafo y olas

```text
modelo-comun ----+----> protocolo-red ----+----> servidor
                 |                        `----> cliente
                 +----> servidor
                 +----> cliente
                 `----> editor

assets ----------+----> servidor
                 +----> cliente
                 `----> editor

servidor + cliente + editor + assets ----> integracion

qa depende de todos los contratos publicados.
```

No existe arista `servidor -> cliente` ni `cliente -> servidor`. Los payloads
compartidos de replicacion se publican una vez en `modelo-comun`; el servidor
es su productor autoritativo, el cliente su consumidor no autoritativo y
`protocolo-red` conserva solo framing, transporte, roles y orden de stream.

Para Architecture V2, `ENTITY_SPAWNED`, `ENTITY_CORE_STATE_CHANGED`,
`ENTITY_DESPAWNED` y el snapshot `CORE_ENTITY_STATE` requieren schemas
neutrales en `modelo-comun`. Sus formas actuales
`tvp3d.server.entity_spawned/2.0.0`,
`tvp3d.server.entity_core_state_changed/2.0.0`,
`tvp3d.server.entity_despawned/2.0.0` y
`tvp3d.server.core_entity_state/2.0.0` quedan como publicacion inicial del
servidor que debe migrarse, no como dependencia del cliente. Autorizacion,
`SessionBindingV2`, procesamiento de comandos, persistencia, seleccion del
replication set, decisiones autoritativas, `ServerErrorV2` y
`COMMAND_REJECTED` permanecen en `servidor`.

El siguiente turno contractual obligatorio es `modelo-comun 2.1.0`, antes de
publicar Client V2. Es una ampliacion minor porque agrega schemas compartidos
sin cambiar forma ni significado de los tipos comunes 2.0.0; una version
`3.0.0` solo seria necesaria si ese turno rompe o reinterpreta una forma V2
existente.

Gate vigente de Architecture V2: despues de `modelo-comun 2.1.0`, el
contrato `servidor` debe alinearse para consumir los schemas neutrales y solo
entonces puede publicarse Client V2 contra ellos. Las olas iniciales siguientes
se conservan como secuencia historica del andamiaje; no levantan este gate.

Ola 0: publicar contratos de `modelo-comun` y `assets` en paralelo.

Ola 1: publicar `protocolo-red`; con ese contrato, preparar contratos de
`servidor`, `cliente` y `editor`.

Ola 2: implementar servidor, cliente, assets y editor respetando contratos;
servidor y cliente pueden avanzar en paralelo despues de sus dependencias.

Ola 3: integrar arranque y datos.

Ola 4: ejecutar QA y revision cruzada.
