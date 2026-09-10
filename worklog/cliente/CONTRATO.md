# Contrato: cliente

Version: 2.0.0
Estado: PUBLICADO
Propietario: cliente
Depende de: modelo-comun 2.1.0, protocolo-red 2.1.0, assets 2.0.0

Cliente V2 NO depende de `servidor`. Los payloads de replicacion compartidos
vienen de modelo-comun; la politica de implementacion del servidor no se
importa. Historial: Client 1.30.0 dependia de modelo-comun 1.0.0,
protocolo-red 1.1.0 y assets 1.3.0 (ver HISTORICAL mas abajo). Esta es una
revision **major** deliberada: 1.x usa `WELCOME`/`STATE`, ids uint32,
comportamiento TVP 7.72 y renderizado dirigido por looktype; ningun objeto de
1.x se reinterpreta silenciosamente como V2.

## 0. Proposito y alcance normativo (Client V2)

```text
Godot 4.7 3D client
        |
        | Protocol V2
        |
Authoritative Godot headless server
```

El cliente presenta estado autoritativo, envia intenciones y mantiene
presentacion/interpolacion/UI locales. Nunca decide verdad de gameplay. Las
palabras `DEBE`, `NO DEBE`, `PUEDE` y `SOLO` son normativas en esta seccion y
en las secciones 1-24. El material anterior a esta revision queda clasificado
como `HISTORICAL / SUPERSEDED` mas abajo y no es normativo V2.

## 1. Perfil de aplicacion nativo (common domain)

Protocol V2 2.1.0 sabe negociar common domain `2.0.0` y `2.1.0`, pero esa es
capacidad de transporte, no politica de aplicacion. El perfil nativo Client V2
ofrece exactamente:

```json
{
  "schema": "tvp3d.cliente.common_domain_offer",
  "version": "2.0.0",
  "common_domain_versions": ["2.1.0"]
}
```

Motivo: el store de replica autoritativa nativo (seccion 4) y el consumo de
eventos/snapshot (secciones 6-8) dependen de los registros neutrales que solo
existen desde modelo-comun 2.1.0. No hay requisito concreto de compatibilidad
2.0.0 para este perfil; ofrecerla ademas de 2.1.0 pertenece a un adaptador de
compatibilidad explicito, no al perfil nativo final.

Reglas de aceptacion de `SERVER_WELCOME` para este perfil:

- `protocol_version` debe ser exactamente `{major:2, minor:0}`;
- `common_domain_version` debe ser exactamente `"2.1.0"`; cualquier otro
  valor (incluido `"2.0.0"`) se rechaza sin pasar a mundo activo, aunque
  Protocol V2 haya completado su propia negociacion con otro perfil de
  servidor;
- `SERVER_WELCOME.runtime_scope_id` fija el scope de la sesion (seccion 3).

Protocol `READY` sigue siendo exclusivamente un estado de transporte de
`protocolo-red`; no se redefine aqui y no implica fase de mundo `ACTIVE`
(seccion 2) ni autorizacion de aplicacion.

## 2. Fase de mundo del cliente (`ClientWorldPhaseV2`)

Es un estado de aplicacion/presentacion propio del cliente, ortogonal a
`ProtocolConnectionStateV2` (que sigue siendo exclusivo de `protocolo-red`:
`CONNECTED`, `NEGOTIATING`, `READY`, `SYNCING`, `CLOSING`, `CLOSED`). Este
contrato NO publica otra maquina de conexion competidora.

Enum cerrado:

```text
EMPTY
BASELINE_PENDING
ACTIVE
RECOVERING
```

```json
{
  "schema": "tvp3d.cliente.world_phase",
  "version": "2.0.0",
  "phase": "ACTIVE"
}
```

| Fase | Significado |
|---|---|
| `EMPTY` | ningun mundo runtime autoritativo es utilizable actualmente |
| `BASELINE_PENDING` | la negociacion Protocol tuvo exito, pero ningun baseline autoritativo fue aceptado todavia |
| `ACTIVE` | existe un baseline autoritativo valido; replicacion incremental puede presentarse |
| `RECOVERING` | el baseline anterior no puede aceptar mas estado incremental con seguridad; se requiere un snapshot autoritativo fresco |

Reglas:

- `Protocol READY` NO implica `ACTIVE`; tras `SERVER_WELCOME` aceptado
  (seccion 1) el cliente entra en `BASELINE_PENDING`, nunca directo a
  `ACTIVE`;
- `ACTIVE` NO implica autorizacion del jugador (seccion 13);
- el estado de presentacion nunca autoriza gameplay;
- ningun `CommandEnvelopeV2` de gameplay se emite en `BASELINE_PENDING` ni en
  `RECOVERING`;
- una desconexion o un `runtime_scope_id` incompatible retira el mundo
  autoritativo actual de `ACTIVE` (vuelve a `EMPTY` o `BASELINE_PENDING`
  segun si ya hay sesion Protocol nueva);
- un snapshot de recuperacion valido transiciona `RECOVERING -> ACTIVE`.

## 3. Store de replica autoritativa (`ClientReplicaStoreV2`)

Concepto: una copia local exacta del estado autoritativo del servidor. NO es
autoridad por si mismo.

```text
ClientReplicaStoreV2
key:   RuntimeInstanceRefV2
value: AuthoritativeEntityStateV2
```

```json
{
  "schema": "tvp3d.cliente.replica_store_entry",
  "version": "2.0.0",
  "runtime_id": {
    "scope_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "42"
  },
  "state": {
    "schema": "tvp3d.entity_state",
    "version": "2.0.0",
    "runtime_id": {
      "scope_id": "550e8400-e29b-41d4-a716-446655440000",
      "instance_id": "42"
    },
    "definition": {
      "canonical_id": "tvp3d:entity_type:player",
      "definition_version": "1.0.0"
    },
    "position": {"x": 32097, "y": 32219, "z": 7},
    "direction": "NORTH",
    "revision": "0"
  }
}
```

`state` es `AuthoritativeEntityStateV2` exacto de modelo-comun 2.1.0; el
cliente no lo redefine ni le agrega campos.

Reglas NO DEBE, sin excepcion:

- el cliente NUNCA crea una entidad autoritativa localmente;
- el cliente NUNCA inventa un `RuntimeInstanceRefV2`;
- el cliente NUNCA edita posicion/direccion/revision confirmadas en base al
  renderer;
- la interpolacion visual NO escribe en el store de replica;
- el estado de camara NO escribe en el store de replica;
- el input del usuario NO escribe en el store de replica;
- un GLB/sprite faltante NO elimina estado de dominio del store.

Una capa de presentacion separada (seccion 9) consume el store; nunca al
reves.

## 4. Runtime scope

`SERVER_WELCOME.runtime_scope_id` define el epoch runtime de la sesion.

Reglas:

- todo estado replicado aceptado debe pertenecer a ese scope;
- un `runtime_scope_id` nuevo invalida todo `RuntimeInstanceRefV2` anterior;
- ninguna ref de entidad del scope anterior sobrevive al nuevo store
  autoritativo;
- las intenciones pendientes (seccion 14) que refieran al scope anterior se
  descartan;
- los nodos de presentacion del scope anterior se retiran o se convierten a
  un estado de desmontaje no autoritativo;
- el cliente espera un baseline fresco (seccion 5) antes de volver a
  `ACTIVE`.

Un `runtime_id` nunca se mapea a identidad persistente; es transitorio por
definicion de modelo-comun.

## 5. Baseline inicial

Tras una negociacion aceptada (seccion 1), el cliente entra en
`BASELINE_PENDING`. El mundo V2 nativo se vuelve `ACTIVE` solo tras aceptar un
Protocol SNAPSHOT valido con:

```text
payload_type    = CORE_ENTITY_STATE
payload_version = 1.0.0
payload schema  = tvp3d.replication.core_entity_state/1.0.0 (modelo-comun)
```

El snapshot DEBE validarse completo antes de reemplazar el store de replica
activo. No hay aplicacion parcial.

## 6. Aplicacion atomica del snapshot

Para un snapshot `CORE_ENTITY_STATE` candidato, el orden obligatorio es:

1. validar el envelope Protocol SNAPSHOT;
2. validar el payload comun neutral (`tvp3d.replication.core_entity_state/1.0.0`);
3. validar `runtime_scope_id`;
4. validar cada `AuthoritativeEntityStateV2` del array `entities`;
5. validar que cada `definition` referenciada sea resoluble por el dataset
   del cliente;
6. construir el store de reemplazo completo en staging;
7. intercambiarlo atomicamente al estado activo;
8. actualizar el baseline de protocolo segun lo defina `protocolo-red`
   (`last_accepted_sequence = last_sequence`);
9. entrar en `ACTIVE`.

Si la validacion falla en cualquier paso:

- no se conserva ningun reemplazo parcialmente aplicado;
- el cliente entra o permanece en `RECOVERING` o `BASELINE_PENDING` segun
  corresponda;
- el cliente solicita recuperacion autoritativa (`SYNC_REQUEST` segun
  `protocolo-red`);
- el cliente NUNCA parchea datos invalidos localmente.

### Membresia del snapshot != despawn

El snapshot representa el replication set completo que el productor
autoritativo selecciono para esa sesion. Si una entidad existia en el store
anterior pero esta ausente del snapshot nuevo:

- se retira del store/presentacion **del cliente**;
- pero el cliente NO DEBE afirmar `ENTITY_DESPAWNED`;
- y NO DEBE inferir que la entidad fue destruida globalmente.

Membresia de replication set y despawn autoritativo son conceptos distintos
(igual que en modelo-comun/servidor); este contrato no los mezcla.

## 7. Consumo de eventos neutrales

Consumidos directamente de modelo-comun 2.1.0, sin copiar ni redefinir su
forma:

| Event type | Payload (modelo-comun) |
|---|---|
| `ENTITY_SPAWNED` | `tvp3d.replication.entity_spawned/1.0.0` |
| `ENTITY_CORE_STATE_CHANGED` | `tvp3d.replication.entity_core_state_changed/1.0.0` |
| `ENTITY_DESPAWNED` | `tvp3d.replication.entity_despawned/1.0.0` |

Todos viajan en `AuthoritativeEventEnvelopeV2`; el cliente los acepta solo
para el `stream_id` activo con `sequence == last_accepted + 1`, segun las
reglas de `protocolo-red`.

### `ENTITY_SPAWNED`, en `ACTIVE`

1. validar envelope + payload neutral;
2. `runtime_scope_id` del `state` debe coincidir con el scope activo;
3. `envelope.subject` debe coincidir con `state.runtime_id`;
4. `state.revision` debe ser `"0"` (invariante comun de spawn);
5. `definition` debe ser resoluble;
6. el `runtime_id` NO DEBE existir ya en el store autoritativo.

Solo tras la insercion autoritativa exitosa la presentacion puede instanciar
o resolver un nodo visual. Si la resolucion visual falla, el cliente conserva
el estado de dominio replicado y usa un fallback/diagnostico de presentacion
(seccion 16); NUNCA descarta el estado autoritativo por un modelo faltante.

### `ENTITY_CORE_STATE_CHANGED`, en `ACTIVE`

1. la entidad debe existir en el store;
2. el payload contiene el estado completo, nunca un patch;
3. `runtime_id` y scope deben coincidir;
4. `revision` debe ser estrictamente mayor que la conocida, segun la regla
   comun de modelo-comun; el cliente no inventa una regla adicional de
   renderer/world-space para aceptarla o rechazarla.

El cliente reemplaza el estado autoritativo atomicamente; nunca lo convierte
en un modelo de patch. Si la validacion comun/protocolo indica una secuencia
insegura (revision repetida/decreciente, gap de stream), el cliente entra en
`RECOVERING` y sigue `SYNC_REQUEST -> snapshot autoritativo`.

### `ENTITY_DESPAWNED`, en `ACTIVE`

1. validar el evento neutral;
2. el `subject` debe existir en el store;
3. la revision terminal debe ser valida (mayor que la conocida);
4. remover la entidad del store autoritativo;
5. remover o retirar el nodo de presentacion asociado;
6. el `RuntimeInstanceRefV2` retirado NUNCA se reutiliza.

Este evento significa retiro autoritativo del runtime. NO se usa para camera
culling, streaming de chunks ni desaparicion ordinaria de un replication set
(ver seccion 6, membresia != despawn).

## 8. Capas: autoridad, presentacion e intencion

Tres capas estrictamente separadas:

1. **AuthoritativeReplica** — estado logico confirmado exacto recibido por
   replicacion comun (seccion 3). Es la unica que representa verdad de mundo
   confirmada.
2. **PresentationState** — transforms, interpolacion, fase de animacion,
   camara, UI, fallback visual. Puede ser suave y de apariencia predictiva,
   pero NUNCA se convierte en autoridad.
3. **PendingIntent** — registro local de comandos enviados o en preparacion
   (seccion 14). NUNCA muta `AuthoritativeReplica`.

## 9. Interpolacion

La presentacion puede interpolar entre estados logicos confirmados:

```text
PosicionTibia confirmada A
      ->
transform de presentacion entre A y B
      ->
PosicionTibia confirmada B
```

Reglas:

- la interpolacion es exclusivamente visual;
- `PosicionTibiaV2` autoritativa sigue siendo estado SQM entero;
- el transform de presentacion puede usar floats;
- un transform world-space NUNCA sobrescribe `PosicionTibiaV2`;
- completar una interpolacion NO confirma movimiento;
- el siguiente evento autoritativo siempre gana sobre cualquier interpolacion
  en curso;
- ningun root motion puede crear movimiento de gameplay.

## 10. Adaptador de coordenadas

El cliente convierte `PosicionTibiaV2` + `DirectionV2` a coordenadas de
presentacion Godot mediante el adaptador de coordenadas centralizado de
Architecture V2 (`docs/tibia3d/ARCHITECTURE.md`, "Arquitectura de
coordenadas"). Se preservan como configuracion de presentacion centralizada,
donde Architecture ya los ubica:

- `SQM_WORLD_SIZE`;
- `FLOOR_WORLD_HEIGHT`.

Reglas:

- NO se congela una escala de malla arbitraria dentro de estado de dominio;
- NO se introduce `Vector3` de Godot en estado autoritativo comun;
- la conversion debe ser reversible para diagnostico donde sea practico, pero
  los floats del renderer nunca son verdad de dominio.

## 11. Entrada del usuario / comandos

El cliente emite solo `CommandEnvelopeV2` registrados por el contrato de
dominio propietario. Para el `MOVE` comun:

```text
direccion de input
    -> DirectionV2
    -> CommandEnvelopeV2(type=MOVE)
```

El cliente propone la intencion de movimiento. NO envia:

- la posicion autoritativa resultante;
- la revision resultante;
- las celdas ocupadas;
- "el movimiento tuvo exito".

El servidor decide esos resultados; el cliente solo los recibe despues via
`ENTITY_CORE_STATE_CHANGED`.

## 12. Frontera de autorizacion / actor controlado

Critico: `SessionBindingV2` es interno del servidor y NO se importa al
cliente. Client V2 NO DEBE inventar su propia autoridad de autorizacion.

Un `CommandEnvelopeV2` de gameplay solo puede emitirse cuando:

- la sesion Protocol es usable (`READY`, no `SYNCING`/`CLOSING`/`CLOSED`);
- la fase de mundo del cliente es `ACTIVE` (seccion 2);
- no esta en `RECOVERING` ni `BASELINE_PENDING`;
- un `RuntimeInstanceRefV2` de actor controlado, valido para el scope activo,
  fue suministrado a traves de un contrato FUTURO de
  sesion-de-aplicacion/autenticacion que **todavia no existe**.

Ese contrato futuro no existe hoy. Por lo tanto este contrato:

- define esto como un boundary de binding externo requerido, sin publicar su
  forma final;
- NO define username, password, token ni OAuth;
- NO inventa como se prueba la autorizacion de un actor;
- NO afirma que Client V2 pueda autorizarse a si mismo.

Conocer o adivinar un `RuntimeInstanceRefV2` no concede control (misma regla
que modelo-comun/servidor). Mientras ese contrato futuro no exista, el
cliente nativo V2 no tiene ninguna via legitima para obtener un actor
controlado y por lo tanto NO DEBE emitir ningun `CommandEnvelopeV2` de
gameplay en produccion real; solo puede prepararlos/simularlos localmente en
modo diagnostico sin enviarlos.

## 13. Registro de intencion pendiente (`PendingIntentV2`)

Registro transitorio, solo-cliente:

```json
{
  "schema": "tvp3d.cliente.pending_intent",
  "version": "2.0.0",
  "command_id": "7b1d9ad4-5d72-4b95-a00b-a6d83b302d7f",
  "actor": {
    "scope_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "42"
  },
  "type": "MOVE",
  "local_state": "SENT"
}
```

`local_state` es un enum cerrado `PREPARING|SENT`; puede llevar metadata
adicional solo de presentacion (por ejemplo un timestamp local de UX). NO
DEBE contener estado autoritativo resultante (posicion, revision, "exito").

Se descarta cuando:

- cambia el `runtime_scope_id` (seccion 4);
- hay desconexion;
- ocurre invalidacion/recuperacion y la causalidad ya no es confiable
  (`RECOVERING`).

Una intencion pendiente puede impulsar feedback local de UX (por ejemplo, un
indicador "enviado, esperando confirmacion"), pero nunca autoridad.

## 14. Frontera COMMAND_REJECTED / evento servidor-owned

D-011 deja intencionalmente `COMMAND_REJECTED` y `ServerErrorV2` en
`servidor`. Client V2 NO DEBE crear una dependencia oculta de `servidor` para
parsearlos. El contrato core de Client V2 permanece correcto incluso sin
importar `tvp3d.server.command_rejected` ni `tvp3d.server.error`: la
correctitud del estado autoritativo depende solo de los eventos/snapshot de
replicacion comun reconocidos (secciones 5-7).

### Analisis de la frontera (obligatorio este turno)

`AuthoritativeEventEnvelopeV2` (modelo-comun 2.1.0) es generico:
`event_id`, `stream_id`, `sequence`, `type`, `subject`, `subject_revision` y
`causation_command_id` son campos comunes, sin importar el `type`. Esto
permite, sin importar el contrato `servidor`:

- **recibir** el frame EVENT y avanzar la contabilidad de `stream_id/sequence`
  igual que para cualquier otro evento, aunque el `type` no este en el
  registro que el cliente interpreta;
- **ignorar** con seguridad el contenido de `payload` cuando su `type` (por
  ejemplo `COMMAND_REJECTED`) no pertenece al registro neutral que este
  contrato consume;
- **correlacionar** el evento con un `PendingIntentV2` local usando
  `causation_command_id`, que es `uuid_v4|null` generico y no requiere
  conocer la forma de `tvp3d.server.command_rejected`;
- **enrutar** ese resultado a una UX generica ("la intencion `command_id` fue
  rechazada") basandose solo en la correlacion anterior, sin decodificar
  `error.code`, `message` ni `retryable`.

Conclusion: la frontera **es posible** sin contradiccion arquitectonica. No
se agrega `cliente -> servidor` y no se copia `ServerErrorV2` a `cliente`.

Deuda downstream explicita: una UX de rechazo enriquecida (motivo exacto,
reintentable, mensaje) requiere un futuro contrato neutral de
command-outcome/error, o un adaptador explicito y declarado que importe
`servidor` solo para diagnostico. Ninguno de los dos se publica en este
turno.

## 15. Resolucion de definicion/asset

La identidad de dominio del cliente proviene de `CanonicalDomainId` +
`definition_version`, nunca de client id, server id, looktype, numero de
sprite, filename ni filename de GLB.

Un resolver de presentacion puede mapear mas adelante identidad canonica de
dominio a assets visuales; ese mapping visual NO se congela en este turno.
Assets 2.0.0 es dueno de datos de asset/importacion; el cliente consume, no
reescribe fuentes de assets.

Si una entidad canonica existe pero falta el mapping de presentacion:

- se preserva el estado de replica autoritativa;
- se usa una representacion de diagnostico/fallback local clara;
- NUNCA se sustituye por otra identidad canonica;
- NUNCA se usa looktype como identidad nativa V2.

## 16. Gate de contrato Monster/Visual

El Client 1.x historico (ver HISTORICAL mas abajo) contiene trabajo extenso
sobre Demon 35, TVPVOL01/TVPVOL02, 41/144 monsters, outfits, ArrayMesh,
fallback billboard, renderizado dirigido por looktype y animacion/escalas de
prototipo. Ese trabajo se preserva como evidencia historica/prototipo y se
reclasifica explicitamente como:

**HISTORICAL / SUPERSEDED CLIENT 1.x VISUAL PROTOTYPE EVIDENCE**

No es el contrato final Monster3D. No autoriza:

- nuevos monsters;
- decisiones de formato GLB;
- estandares de rig;
- estandares de animation clip;
- pipeline Blender;
- mappings finales looktype -> asset;
- footprint de gameplay derivado de AABB;
- Monster Domain.

No se borra trabajo util; no permanece como texto normativo V2.

## 17. `mundo3d.gd`

`mundo3d.gd` es deuda tecnica/runtime legacy transicional. Este turno NO lo
modifica. La implementacion futura descompondra responsabilidades de
presentacion incrementalmente, siguiendo la descomposicion ya documentada en
`docs/tibia3d/ARCHITECTURE.md` ("Evolucion de `mundo3d.gd`":
`WorldStreamer`, `ChunkRenderer`, `StaticMapRenderer`, `CreatureManager`,
`PlayerManager`, `EffectManager`, `CameraController`, `DebugOverlay`), en vez
de convertir `mundo3d.gd` en la nueva arquitectura. Este contrato no prescribe
archivos de refactor de produccion mas alla de las rutas que `CARRILES.md` ya
asigna a `cliente`.

## 18. Legado TVP 7.72

Todo el conocimiento util de Client 1.x / TVP 7.72 (muerte/reentrada, party,
trade, camas, ventanas de texto, skulls/shields, modos de combate, looktypes,
renderizado legacy de monsters, etc., preservado integramente en HISTORICAL
mas abajo) se reclasifica como:

**LEGACY ADAPTER / PARITY / HISTORICAL CLIENT PROFILE**

No es el protocolo nativo nativo Client V2. No se borra. `conexion772.gd` NO
forma parte del perfil nativo V2.

## 19. Perdida de conexion / reconexion

El cliente no inventa continuidad autoritativa entre conexiones. Ante perdida
de transporte/sesion:

- la emision de comandos de gameplay se detiene;
- las intenciones pendientes atadas a la sesion/scope vieja se invalidan
  (seccion 13);
- el mundo autoritativo actual deja de considerarse vivo;
- puede conservarse temporalmente un frame visual congelado, solo por UX y
  claramente marcado como no autoritativo;
- la reconexion debe negociar Protocol/common domain de nuevo (seccion 1);
- un `runtime_scope_id` nuevo invalida las refs runtime viejas (seccion 4);
- el cliente requiere un baseline autoritativo fresco antes de volver a
  `ACTIVE` (seccion 5).

Host, puerto y tiempos de backoff no se especifican aqui: pertenecen a
`integracion` si su contrato los publica.

## 20. Errores propios del cliente

El cliente consume, sin redefinir, `ProtocolErrorV2` y los errores comunes de
replicacion/dominio de modelo-comun. Define solo los codigos necesarios para
su propio estado de aplicacion/presentacion:

```json
{
  "schema": "tvp3d.cliente.error",
  "version": "2.0.0",
  "code": "CLIENT_CONTROL_BINDING_REQUIRED",
  "path": null,
  "message": "no controlled actor binding supplied for this scope"
}
```

| Codigo | Mutacion de world state | Mutacion de replica | Accion de presentacion | Accion de sync/reconexion |
|---|---|---|---|---|
| `CLIENT_BASELINE_REQUIRED` | ninguna | ninguna | bloquear UI de gameplay | permanecer/entrar en `BASELINE_PENDING`, esperar SNAPSHOT |
| `CLIENT_SCOPE_CHANGED` | ninguna | vacia el store del scope anterior | retirar/desmontar nodos del scope anterior | esperar baseline fresco del nuevo scope |
| `CLIENT_REPLICA_MISSING` | ninguna | ninguna (rechaza la operacion) | no aplicar el evento a un nodo inexistente | solicitar recuperacion (`RECOVERING`) |
| `CLIENT_PRESENTATION_UNRESOLVED` | ninguna | ninguna | usar fallback/diagnostico visual | ninguna |
| `CLIENT_CONTROL_BINDING_REQUIRED` | ninguna | ninguna | bloquear emision de comandos de gameplay | ninguna (espera contrato futuro de sesion) |
| `CLIENT_RECOVERY_REQUIRED` | ninguna | descarta el store activo hacia staging | mostrar estado "sincronizando" | `RECOVERING` -> `SYNC_REQUEST` -> snapshot |

Ninguno de estos codigos duplica `ProtocolErrorV2`, un error comun de
modelo-comun o un error `servidor`.

## 21. No se inventan reglas de Map/World

Map / World Rules sigue siendo un contrato de dominio especializado
faltante. Client V2 NO DEBE definir con autoridad final:

- caminabilidad de tile;
- ocupacion dinamica;
- teleports;
- cambios de piso;
- permisos de casa;
- reglas de pathfinding.

Datos de mapa/render importados legacy pueden seguir siendo input
visual/paridad. El servidor/dominio especializado sera dueno de las reglas
finales de mundo. Se reporta como dependencia downstream (ver seccion 24)
para jugabilidad nativa completa.

## 22. Fixtures contractuales (especificacion, sin produccion)

| Fixture | Caso minimo | Resultado obligatorio |
|---|---|---|
| `CLIENT-OFFER-001` | perfil nativo | `common_domain_versions=["2.1.0"]` |
| `CLIENT-WELCOME-REJECT-001` | `SERVER_WELCOME.common_domain_version="2.0.0"` | rechazado por el perfil nativo, no entra a mundo activo |
| `CLIENT-PHASE-001` | Protocol `READY` sin baseline aceptado | fase de mundo permanece `BASELINE_PENDING`, nunca `ACTIVE` |
| `CLIENT-SNAPSHOT-EMPTY-001` | snapshot `CORE_ENTITY_STATE` valido, `entities=[]` | fase pasa a `ACTIVE` |
| `CLIENT-SNAPSHOT-MULTI-001` | snapshot valido multi-entidad | fase pasa a `ACTIVE`, store poblado exacto |
| `CLIENT-SNAPSHOT-INVALID-001` | snapshot invalido (schema/scope/orden) | cero mutacion parcial del store; fase permanece `BASELINE_PENDING`/`RECOVERING` |
| `CLIENT-SCOPE-001` | `runtime_scope_id` nuevo | refs runtime viejas se limpian del store |
| `CLIENT-SPAWN-001` | `ENTITY_SPAWNED` valido | crea entrada en el store autoritativo |
| `CLIENT-SPAWN-DUP-001` | spawn de `runtime_id` ya existente | rechazado localmente; se solicita recuperacion |
| `CLIENT-CHANGED-001` | `ENTITY_CORE_STATE_CHANGED` valido | reemplaza el estado completo en el store |
| `CLIENT-CHANGED-STALE-001` | revision igual/decreciente | cero mutacion del store |
| `CLIENT-DESPAWN-001` | `ENTITY_DESPAWNED` valido | remueve la entrada del store |
| `CLIENT-MEMBERSHIP-001` | entidad ausente en snapshot de reemplazo | se retira del store local; NO se interpreta como `ENTITY_DESPAWNED` |
| `CLIENT-INTERP-001` | interpolacion en curso | `PosicionTibiaV2` en el store no cambia por la interpolacion |
| `CLIENT-RENDER-001` | transform de renderer alterado manualmente | no puede sobrescribir estado autoritativo |
| `CLIENT-ASSET-MISSING-001` | asset de presentacion faltante | el store autoritativo se preserva integro |
| `CLIENT-IDENTITY-001` | intento de usar looktype/client id como identidad | rechazado; no reemplaza `CanonicalDomainId` |
| `CLIENT-CMD-PENDING-001` | comando durante `BASELINE_PENDING` | rechazado localmente, no se envia |
| `CLIENT-CMD-RECOVERING-001` | comando durante `RECOVERING` | rechazado localmente, no se envia |
| `CLIENT-CMD-NOBINDING-001` | comando sin actor controlado suministrado externamente | rechazado localmente, no se envia |
| `CLIENT-MOVE-INTENT-001` | `CommandEnvelopeV2(type=MOVE)` emitido | contiene solo intencion (`dx,dy`); ningun campo de resultado |
| `CLIENT-SCOPE-INTENT-001` | cambio de `runtime_scope_id` con intentos pendientes | los `PendingIntentV2` viejos se invalidan |
| `CLIENT-DISCONNECT-001` | desconexion de transporte | el mundo autoritativo deja de considerarse vivo |
| `CLIENT-NO-SERVIDOR-001` | analisis de dependencias del contrato `cliente` | no referencia `worklog/servidor/CONTRATO.md` como dependencia normativa |
| `CLIENT-HISTORICAL-001` | secciones HISTORICAL de Client 1.x/TVP | no contienen palabras normativas V2 (`DEBE`/`NO DEBE`/`SOLO` en sentido de contrato vigente) |
| `CLIENT-NOVISUAL-001` | intento de agregar campo visual a `AuthoritativeEntityStateV2`/eventos comunes | rechazado por modelo-comun; el cliente no lo reintroduce localmente |

Estas son especificaciones de contrato; ningun test/produccion se implementa
en este turno.

## 23. Consumidores y exclusiones

Consumidores: cliente Godot 3D, QA, integracion.

Client V2 no expone credenciales, tokens, secretos, autoridad de servidor,
`SessionBindingV2`, `ServerErrorV2`/`COMMAND_REJECTED` redefinidos, reglas
finales de Map/World, ni mapping visual final looktype->asset. No autoriza
modificar `mundo3d.gd`, red, servidor, Monster Domain o Monster3D.

## 24. Dependencias downstream faltantes para jugabilidad nativa completa

Para que Client V2 sea completamente jugable de forma nativa (sin adaptador
legacy) faltan, como minimo, estos contratos especializados que este turno no
publica:

| Capacidad faltante | Contrato requerido |
|---|---|
| autenticacion, sesion de aplicacion y actor controlado | Authentication / Application Session (seccion 12) |
| caminabilidad, ocupacion dinamica, pathfinding, pisos, casas | Map / World Rules Domain |
| combate, dano, condiciones | Combat Domain |
| inventario, items dinamicos, drops | Item / Inventory Domain |
| monstruos, IA, spawns, loot | Monster Domain + Spawn Domain |
| UX de rechazo enriquecida sin adaptador servidor | Command Outcome / Error neutral (seccion 14) |
| mapping final canonical id -> asset visual | resolver de presentacion (fuera de este turno) |

## Historial de contrato de cliente

| Version | Publicacion |
|---|---|
| `1.0.0` .. `1.30.0` | perfil propio JSON, adaptador TVP 7.72 y prototipos visuales (ver HISTORICAL) |
| `2.0.0` | Client V2 nativo: perfil de common domain 2.1.0 exclusivo, fase de mundo propia, store de replica autoritativa, consumo neutral de eventos/snapshot, capas autoridad/presentacion/intencion, boundary de autorizacion externo, frontera COMMAND_REJECTED analizada sin dependencia servidor |

## HISTORICAL / SUPERSEDED — Client 1.30.0 y anteriores

Estado: `SUPERSEDED` por Client V2 2.0.0 (secciones 0-24 arriba).

Todo el contenido siguiente describe el perfil propio JSON 1.x
(`WELCOME`/`STATE`, ids uint32) y el cliente jugable de la rama TVP 7.72
(`mundo3d.gd`), incluyendo prototipos visuales de monstruos/outfits. Se
preserva integramente como evidencia historica y fixture de paridad. NO es
normativo para Client V2: ninguna palabra `DEBE`/`NO DEBE`/`SOLO` en las
secciones siguientes gobierna el contrato vigente. Dependencias originales de
este material: modelo-comun 1.0.0, protocolo-red 1.1.0/1.4.0/1.6.0,
assets 1.3.0.

## Demon 35 reutilizado y animado

- Postura solicitada: torso mas erguido y brazos relajados a los costados.
- Cola: pesos propios hasta la punta y balanceo suave desde la raiz.
- Proporciones originales: conservar muslos y piernas sin remodelado; solo ajustar torso y brazos por solicitud final del usuario.

- Pedido expreso: reutilizar el Demon de 3DTIBIA con su textura y animaciones.
  Sustituye el prototipo procedural 1.28.0 rechazado por el usuario.
- Fuente inmutable: motor3d/assets/modelos/monstruos/35_demon/modelo.glb de
  3DTIBIA; copiar y limpiar restos de pedestal preservando anatomia y UV.
- Fuente editable Blender con esqueleto y clips Reposo/Caminar; GLB animado
  exportable. Reposo respira; caminar alterna piernas, brazos y cola.
- Cliente conserva ArrayMesh y picking volumetrico. Poses horneadas con UV
  y textura original, interpoladas por blend shapes compartidos en GPU.
- Extension TVPVOL02 solo para mallas texturadas: header 8 bytes, uint32
  frames/vertices/indices, UV float32x2 y indices uint32, luego posiciones
  y normales float32x3 por frame. TVPVOL01 sigue compatible.
- Ficha declara formato, textura, clips y fps; escala uniforme por huella
  maxima 2.0 casillas, origen apoyado y transformacion comun a todas poses.
  Se conserva anatomia original con postura mas erguida solicitada.
- Reposo/caminar se seleccionan por cambios de posicion confirmada; sin
  root motion, autoridad, da?o, colision ni movimiento inventado.
- Visor ofrece los dos clips y pausa; runtime limpia blend shapes al cambiar
  apariencia. Integracion local de mundo3d incluida en pedido del usuario.
- Catalogo conserva 41/144; outfit 35 sigue compartido con sus variantes.

## No regresion de volumen a billboard

- Todo monster publicado con anatomia=true conserva ArrayMesh durante
  creacion, animacion, giro, reutilizacion de nodo y regreso desde una
  apariencia 2D. Nunca hereda QuadMesh ni material billboard de un estado
  anterior.
- Todo jugador con outfit 128-134 o 136-142 conserva su jerarquia humana 3D
  durante creacion, cambio de direccion, pose y reconstruccion por colores.
- Las apariencias todavia no convertidas mantienen su sprite 2D. Demon 35
  se publica como anatomia en esta version.
- Las transiciones limpian mesh, material_override, rotacion, escala y
  metadatos incompatibles antes de aplicar el renderer correspondiente.
- Las pruebas recorren todas las fichas 3D publicadas y exigen tambien la
  transicion explicita billboard -> volumen para impedir la lamina roja.

## Visor de catalogo 3D

- El runtime legacy consume personajes3d para el jugador local y para
  jugadores remotos con ID positivo menor que 0x40000000 cuya apariencia sea
  uno de los outfits 128-134 o 136-142. Monsters, NPCs y cualquier apariencia
  humana no soportada conservan su renderer o billboard 2D como fallback.
- La identidad visual se deriva solo del estado confirmado: apariencia
  int, colores Array[head, body, legs, feet] con indices 0..132 y direccion
  0..3. Un cambio confirmado de apariencia o colores reemplaza la geometria;
  un cambio de direccion solo rota el contenedor.
- El movimiento del jugador local aplica las tres poses de personajes3d
  durante la interpolacion confirmada y vuelve a fase 0 al detenerse. Las
  criaturas remotas usan el mismo reloj de animacion que los monsters.
- Los personajes 3D se apoyan en el origen de su casilla, mantienen el
  picking por volumen y no cambian posiciones, ocupacion, hitbox, colisiones,
  velocidad, combate, red ni persistencia.
- El modelo local conserva prioridad de orden, pero todas sus piezas mantienen
  depth test activo. Desactivar profundidad por pieza aplana torso, ropa,
  brazos y cabeza en una lamina por superposicion; ningun requisito de
  visibilidad sobre techos puede romper el volumen 3D.
- El componente local personajes3d modela los 14 outfits humanos clasicos:
  128-134 masculinos y 136-142 femeninos, nombres Citizen, Hunter, Mage,
  Knight, Noble, Summoner y Warrior. Cada uno expone cuatro facings y tres
  fases de paso, con silueta diferenciada por ropa/equipo.
- crear(tipo, colores, direccion, fase) acepta colores [head, body, legs,
  feet], cada indice entero 0..132 confirmado por el servidor. La conversion
  usa la paleta HSI del cliente de 3DTIBIA/OTClient; valores ausentes o fuera
  de rango usan cero de forma local sin mutar el estado recibido.
- La base humana mide aproximadamente 0.95 casillas hasta la cabeza; sombreros,
  cascos y accesorios pueden llegar a 1.15. El outfit 128 sustituye la antigua
  referencia de 0.67 casillas dentro del visor.
- Los outfits humanos se listan como referencias separadas de los 41 monsters;
  no pasan por es_monstruo, no entran en mallas/catalogo.json y no alteran el
  conteo anatomico 41/144.
- Este turno publica componente y visor en rutas propias de cliente. Conectar
  personajes3d al runtime legacy mundo3d.gd queda para un turno de integracion
  porque esa ruta no pertenece al carril cliente publicado en CARRILES.md.
- La jerarquia de escala usa maxima extension horizontal y altura del AABB:
  Giant Spider 2.55 casillas, The Old Widow 2.80, Dragon 3.20 y Dragon Lord
  3.55 de extension horizontal objetivo. Dragon y Dragon Lord deben superar
  los 1.57 de altura del Frost Troll; las aranas gigantes conservan perfil
  bajo, pero superan ampliamente su huella y aumentan masa vertical.
- Las etiquetas de Todos muestran ancho x alto x largo del AABB para comparar
  volumen completo sin confundir altura con tamano general.
- La vista Todos incluye los 14 outfits humanos 128-134 y 136-142. El 128
  sustituye la referencia antigua de capsula a escala 0.5. Ninguno se registra
  como monster ni altera el conteo de fichas anatomicas.
- El visor local descubre todas las fichas con `anatomia=true`; una nueva
  apariencia generada aparece sin mantener otra lista manual.
- Modo `Todos`: cuadricula comun, animacion por fases, etiqueta de nombre/id,
  seleccion con clic y arrastre individual sobre el plano X/Z.
- Camara ortogonal: orbita con boton derecho, paneo con boton central o WASD,
  zoom con rueda y enfoque de la criatura seleccionada.
- Flechas mueven la criatura seleccionada; Q/E la giran. `Ordenar` restaura la
  cuadricula sin alterar mallas, catalogo ni estado del juego.
- El visor es una herramienta local: no envia acciones, no cambia colisiones
  y no participa en la autoridad del servidor.
- La referencia del jugador se puede seleccionar, mover, girar y enfocar como
  los elementos de comparacion; el modo detalle sigue reservado a monsters
  con ficha y sprite del catalogo.

## Aves

- 111 Chicken, 212 Flamingo, 217 Parrot y 218 Terror Bird: torso emplumado,
  alas plegadas, pico, patas articuladas y dedos; tres poses, salvo las cuatro
  fases originales de Parrot, y RGB del atlas.
- Flamingo conserva cuello largo y patas altas; Parrot cola larga; Terror Bird
  patas robustas, pico grande y alas reducidas. No se comparten siluetas.
- Extension horizontal maxima artistica: .62, .88, .72 y 1.25 casillas.
- Catalogo previsto 40/144, 104 pendientes. Lion, Tiger, Badger y Skunk siguen
  aplazados. Formato TVPVOL01, cache, autoridad y colisiones no cambian.

## Trolls

- 15 Troll, 53 Frost Troll y 76 Swamp Troll: cuerpo encorvado, brazos pesados,
  rostro, manos y pies articulados; tres poses y RGB del atlas original.
- Extension horizontal maxima artistica: .90, 1.00 y .94 casillas respectivamente.
- Catalogo previsto 36/144, 108 pendientes. Lion, Tiger, Badger y Skunk siguen pendientes.
- Mismo formato, cache, autoridad y colisiones; prototipos sujetos a revision visual.

## Skeleton y Demon Skeleton

- 33 Skeleton y 37 Demon Skeleton: craneo con orbitas, mandibula, caja toracica
  abierta, columna, pelvis y extremidades oseas. Sin armas ni cuernos inventados.
- Tres poses, RGB originales marfil/rojo y escala uniforme por apariencia:
  Skeleton .70, Demon Skeleton .82 casillas de extension horizontal maxima.
- Catalogo actual 33/144, 111 pendientes. Lion, Tiger, Badger y Skunk permanecen
  pendientes por preferencia explicita del usuario. Misma cache y autoridad.

## Dog y Hyaena

- 32 Dog: perro castano, orejas cortas caidas, cola fina y cuatro patas.
- 94 Hyaena: hombros elevados, grupa baja, orejas redondeadas y pelaje moteado.
- Tres poses, RGB originales y escala uniforme: Dog .85, Hyaena 1.20 casillas.
- Catalogo actual 31/144 apariencias, 113 pendientes; formatos y autoridad intactos.

## Fauna de bosque

- 31 Deer: cuatro patas largas, pezunas, cornamenta ramificada y cola clara.
- 74 Rabbit / The Halloween Hare: apariencia compartida, orejas largas,
  patas traseras robustas y tres poses. Se cuenta un outfit, no dos especies.
- RGB originales y escala comun: Deer 1.50, Rabbit .55 casillas de extension.
- Catalogo actual 29/144 apariencias, 115 pendientes; autoridad intacta.

## Animales de granja

- 13 Black Sheep y 14 Sheep: lana con relieve, cuatro patas y pezunas partidas.
- 60 Pig: torso bajo, hocico con narinas, orejas y cola rizada.
- Tres poses, RGB originales, escala comun: ovejas .95 y Pig 1.00 casillas.
- Catalogo: 27/144 apariencias, 117 pendientes. No cambia red ni colisiones.

## Artropodos adicionales

- 43 Scorpion: ocho patas, dos pinzas y cola segmentada con aguijon.
- 45 Bug: seis patas, antenas y cuerpo compacto con elitros.
- 124 Centipede: cuerpo segmentado, un par de patas por segmento y antenas.
- Tres poses y RGB del atlas original; escalas artisticas uniformes en casillas:
  Scorpion 1.10, Bug 0.42 y Centipede 1.30. Se suman al catalogo de apariencias habilitadas.
- Misma cache, giros y TVPVOL01; no cambia autoridad ni colisiones.

## Refinamiento y escala relativa

- Scarab 83 y Ancient Scarab 79 se refinan con elitros separados, surcos,
  bordes de quitina, patas articuladas y mandibulas diferenciadas.
- `escalas.json` define por outfit `longitud_casillas` positiva: mayor extension
  horizontal de todas las poses (incluye cola/patas/mandibulas). Es criterio
  artistico editable, no una medida fisica oficial ni una caja de colision.
- El generador aplica un solo factor uniforme por apariencia y todas sus poses.
  Registra objetivo y factor en el catalogo; conserva TVPVOL01 y RGB originales.
- Rat debe quedar claramente menor que Giant Spider; Ancient Scarab debe
  superar claramente a Scarab. Se auditan las 33 apariencias habilitadas.
- El visor ofrece comparacion simultanea sin normalizar modelos, cuadricula
  de una casilla y dimensiones; el zoom individual se identifica como detalle.
- No cambia autoridad, alcance de ataque, posicion ni colisiones del servidor.

## Monstruos con volumen (TVP 7.72)

- El renderer consume cuatro facings y fases del atlas original sin editarlo.
- Las apariencias 21/56/34/39 tienen modelos anatomicos iniciales,
  colores muestreados del sprite, orientacion N/E/S/W y tres poses 3D.
  Se incorpora la familia de aranas: 30 Spider, 36 Poison Spider,
  38 Giant Spider, 208 The Old Widow y 219 Tarantula, con ocho patas,
  abdomen, cefalotorax y poses segun las fases disponibles en el atlas.
  La paleta original de fase cero se conserva durante la animacion.
  Se incorporan 27 Wolf, 52 Winter Wolf y 3 War Wolf con cuatro patas,
  hocico, orejas y cola; tres poses y RGB originales estables por variante.
  Se incorporan 16 Bear, 42 Polar Bear y 123 Panda: cuerpo robusto,
  cuatro patas, orejas redondas y patrones originales por variante.
  Se incorporan 28 Snake y 81 Cobra con cuerpo ondulante, tres poses y
  capucha volumetrica para Cobra. Snake conserva un perfil bajo sobre suelo.
  Se incorporan 26 Rotworm (seis poses de apertura de boca), 82 Larva,
  83 Scarab y 79 Ancient Scarab (tres poses), con anatomia y RGB originales.
  Treinta y tres apariencias tienen modelo; las otras 111 quedan pendientes.
  Las pruebas de interseccion de siluetas no se habilitan en produccion.
- Recursos derivados y generador viven en `cliente3d/propio/monstruos3d/`.
  No cambian formatos de assets ni red; son recursos del renderer.
- Solo IDs de monstruo (0x40000000..0x7fffffff) usan estas mallas.
  Jugadores, NPCs y apariencias ausentes conservan su representacion actual.
- Posicion, piso, apariencia, seleccion y retirada siguen al servidor.
  La malla no agrega colisiones ni cambia reglas de combate.
- Se comparten mallas por apariencia/fase; la camara no gira el modelo.
- La reconstruccion interpreta siluetas; no recupera anatomia oculta exacta.
- Un visor local permite comparar sprites y volumen sin servidor.
  Las pruebas del componente viven junto al renderer.

## Proposito

Presentar el mundo propio de TVP3D en 3D, enviar intenciones de movimiento y
mostrar unicamente posiciones confirmadas por el servidor. Este carril no
decide caminabilidad, ocupacion, existencia ni resultado de una accion.

## Escena y conexion

- Escena propia: `res://propio/cliente_3d.tscn`.
- Host por defecto: `127.0.0.1`; se puede sustituir con `TVP3D_HOST`.
- Puerto por defecto: `7277`; se puede sustituir con `TVP3D_PUERTO`.
- La conexion usa exclusivamente `protocolo-red` v1 y su `StreamPeerTCP`.
- Al conectar se envia `HELLO` una sola vez por intento, con un nombre entre
  1 y 24 caracteres.
- Al recibir `WELCOME` valido se carga el mapa y se pasa a `EN_MUNDO`.
- Al recibir un `STATE` se reemplaza el conjunto visual completo por las
  entidades confirmadas, sin interpolar la posicion logica ni crear entidades
  locales.

## Estados del cliente

| Estado | Evento | Siguiente |
|---|---|---|
| `DESCONECTADO` | temporizador de reintento | `CONECTANDO` |
| `CONECTANDO` | TCP conectado | `CONECTANDO` + `HELLO` |
| `CONECTANDO` | `WELCOME` valido | `EN_MUNDO` |
| `CONECTANDO` | error TCP/protocolo | `DESCONECTADO` |
| `EN_MUNDO` | `STATE` | `EN_MUNDO` + reemplazo visual |
| `EN_MUNDO` | `ERROR` | `EN_MUNDO` + aviso, sin mutar posicion |
| `EN_MUNDO` | cierre TCP | `DESCONECTADO` |
| cualquier estado | `ESC` | cierre ordenado |

Tras una perdida de conexion, el cliente limpia el estado vivo y reintenta
con una pausa fija. No conserva como confirmado un jugador desconectado ni
reutiliza el buffer de un intento anterior.

## Entrada

- `W`, flecha arriba: `MOVE {dx:0,dy:-1}`.
- `D`, flecha derecha: `MOVE {dx:1,dy:0}`.
- `S`, flecha abajo: `MOVE {dx:0,dy:1}`.
- `A`, flecha izquierda: `MOVE {dx:-1,dy:0}`.
- Se envia como maximo una intencion cada `0.18` segundos.
- El cliente no cambia `_mi_pos` al enviar; solo lo cambia con `STATE` que
  contenga su id.
- Un `ERROR` conserva la posicion y muestra el motivo recibido.

## Representacion

- El mapa del `WELCOME` se valida antes de renderizarlo: version, origen,
  dimensiones, celdas, rangos y tipos deben pertenecer al modelo comun.
- Se representan los siete tipos cerrados del modelo: suelo, pared, agua,
  arbol, roca, decoracion y escalera.
- Las entidades de `STATE` se renderizan desde sus posiciones Tibia y se
  distinguen por id local; el jugador propio no se inventa si no aparece en
  el estado recibido.
- La camara sigue la ultima posicion confirmada del jugador local.

## Errores y limites

| Codigo | Accion del cliente |
|---|---|
| `MAPA_RECIBIDO_INVALIDO` | No renderizar el mapa; mostrar aviso y cerrar el intento |
| `PROTOCOLO_INVALIDO` | Descartar el intento, limpiar buffer y reconectar |
| `ERROR` del servidor | Mostrar `mensaje`; no cambiar estado logico |
| `CONEXION_PERDIDA` | Limpiar entidades y reconectar |
| `PERFIL_INCOMPATIBLE` | Rechazar el `WELCOME` y no reinterpretar sus datos |

El cliente no expone credenciales, tokens, claves ni rutas privadas. El
adaptador `conexion772.gd` del cliente legacy es independiente y no se usa
para la escena propia.

## Muerte y reentrada del cliente TVP 7.72

Esta seccion aplica al cliente jugable de la rama TVP 7.72 (`mundo3d.gd` y
`cliente3d/ui/`), no a la escena propia del perfil JSON. La rama del servidor
no tiene `sendDeath` ni `sendReLoginWindow`: el cliente no espera, no inventa
y no acepta ningun opcode de muerte.

La unica fuente de muerte es la senal `jugador_muerto(posicion)` que emite
`cliente3d/red/estado_mundo.gd` cuando el `0x6C` retira a `mi_id` con las
stats autoritativas mas recientes en vida cero, tal como define
`protocolo-red` 1.1.0. El cliente no vuelve a inferir muerte por su cuenta,
no la deduce de la barra de vida, del corpse ni de un mensaje de texto.

Al recibir la senal, y una sola vez por sesion:

| Paso | Obligacion |
|---|---|
| 1 | Marcar la sesion como muerta y bloquear toda intencion nueva: teclado de movimiento, map-click, ataque, uso, arrastre y chat |
| 2 | Cancelar el uso-con pendiente, el arrastre pendiente y el objetivo visual |
| 3 | Ocultar la interfaz de juego y mostrar la pantalla de reentrada |
| 4 | Enviar logout `0x14` por la misma conexion |
| 5 | Esperar el cierre del socket sin volver solo al formulario de cuenta |
| 6 | Volver al selector de personajes unicamente cuando el jugador lo pide |

El paso 4 usa `enviar_logout()` del adaptador. `ProtocolGame::logout`
(`servidor/src/protocolgame.cpp:303-336`) encuentra al jugador ya removido por
`Game::removeCreature` y llama `disconnect()`; el cliente no debe cerrar el
socket por su cuenta para provocar ese camino ni tratar el cierre como error
de red.

La pantalla de reentrada muestra el texto `You are dead.`, que es el mismo que
el servidor envia por `0xB4` desde
`servidor/data/scripts/creaturescripts/playerdeath.lua:12`, y una accion unica
para volver al selector de personajes. No promete revivir en el templo, no
muestra perdidas ni estadisticas: esas consecuencias son autoridad del
servidor y solo se ven al reingresar.

Al aceptar la reentrada, el cliente limpia el estado vivo de la sesion, cierra
la conexion si el servidor todavia no lo hizo y pide de nuevo la lista de
personajes con las credenciales que ya estaban en memoria. Si no hay
credenciales en memoria vuelve al formulario de cuenta.

Un mensaje del servidor que cancele un logout voluntario no cancela esta
salida: la muerte ya ocurrio en la autoridad y no es reversible desde el
cliente.

## Estado de criatura visible en la UI

Esta seccion aplica al cliente jugable de la rama TVP 7.72. Los tres valores
que `protocolo-red` 1.1.0 conserva —velocidad, calavera y escudo de party— se
muestran, no se calculan. El cliente no deduce una calavera del combate, un
escudo de un mensaje de chat ni una velocidad de la distancia recorrida.

| Dato | Fuente unica | Donde se ve |
|---|---|---|
| Velocidad propia | `EstadoMundo.criaturas[mi_id]["velocidad"]`, puesta por `AddCreature` y por `0x8F` | Fila `Speed` de la ventana Skills |
| Calavera | `EstadoMundo.criaturas[id]["calavera"]`, puesta por `AddCreature` y por `0x90` | Fila del Battle List y panel Target |
| Escudo de party | `EstadoMundo.criaturas[id]["escudo_party"]`, puesta por `AddCreature` y por `0x91` | Fila del Battle List y panel Target |

La velocidad propia no se lee del `0xA0`: ese paquete de 7.72 no la
transporta y usarlo mostraba siempre cero.

Las dos tablas de significado viven en `cliente3d/ui/marca_criatura.gd` como
dato, copiadas de `servidor/src/const.h:179-193`:

| Valor | Calavera | Escudo de party |
|---:|---|---|
| 0 | sin marca | sin marca |
| 1 | `Yellow Skull` | `Party invitation received` |
| 2 | `Green Skull` | `Party invitation sent` |
| 3 | `White Skull` | `Party member` |
| 4 | `Red Skull` | `Party leader` |

El sentido del escudo es el que resuelve `Player::getPartyShield`
(`servidor/src/player.cpp:3742-3767`) desde el jugador que mira; el cliente no
vuelve a decidir quien invito a quien.

Un valor fuera de la tabla se oculta y no se dibuja con un color aproximado.
Un valor ausente vale cero, que tambien es sin marca. Un cambio de calavera o
de escudo no reconstruye la fila del Battle List.

## Menu de criatura y party

El boton derecho sobre una fila del Battle List abre el menu de esa criatura,
como en el cliente clasico. Atacar y seguir siguen estando ahi; lo que se
agrega son las acciones de party.

Que se ofrece sale **solo de los escudos confirmados** por el servidor, porque
esta rama no manda ningun paquete de party (`protocolo-red` 1.4.0). El escudo
propio dice si estamos en una y si somos lider; el del otro dice que relacion
tiene con nosotros:

| Escudo del otro | Escudo propio | Accion ofrecida |
|---:|---|---|
| 0 | sin party, o lider | `Invite to Party` (`0xA3`) |
| 1 | cualquiera | `Join Party` (`0xA4`) |
| 2 | cualquiera | `Revoke Invitation` (`0xA5`) |
| 3 | lider | `Pass Leadership` (`0xA6`) |
| 4 | cualquiera | ninguna sobre el lider |
| — | en una party | `Leave Party` (`0xA7`) |

Solo se ofrece party sobre un jugador: los ids de monstruo y de NPC quedan
fuera (`player.cpp:34`, `monster.cpp:18`, `npc.cpp:16`), y uno no se invita a
si mismo.

Elegir una accion envia su opcode y nada mas. La interfaz **no** se adelanta al
resultado: ningun escudo cambia hasta que el servidor lo confirme por `0x91`.
Si el servidor rechaza la accion, lo dice por `0xB4` como cualquier otra.

La experiencia compartida (`0xA8`) no se ofrece: el cliente 7.72 no tenia ese
boton. El transporte existe si alguna vez se decide agregarla.

### Ofrecer un trade

El menu de un jugador incluye `Trade with <nombre>`. Ofrecer es de dos pasos,
igual que el "use with" de las runas que este cliente ya usa:

1. Se elige a quien. No se manda nada todavia.
2. El clic siguiente sobre un objeto del equipo o de un contenedor manda el
   `0x7D` con ese objeto y ese jugador.

El objeto se direcciona como en cualquier mensaje de objeto: `(0xFFFF, ranura,
0)` para el equipo y `(0xFFFF, 0x40 | contenedor, ranura)` para un contenedor,
con `stackpos` 0.

El boton derecho cancela el trade a medio armar, y despues de cancelar el clic
vuelve a usar el objeto como siempre. Si el otro jugador dejo de estar a la
vista, no se manda nada y se avisa.

El orden es el inverso al del cliente clasico, que empieza por el objeto. Se
eligio asi porque el menu de criatura ya existe y el patron de dos pasos ya
esta en el cliente; es reversible el dia que haya menu de objeto.

### Panel de modos de combate

Boton "Combat" en la barra de Actions abre un panel con tres modos de ataque
(Full Attack / Balanced / Full Defense), Chase Opponent y ataque a jugadores
sin marcar. Manda el `0xA0` exacto con el formato de
`ProtocolGame::parseFightModes` (`servidor/src/protocolgame.cpp:1049-1064`):

| Byte | 1 | 2 | 3 |
|---|---|---|---|
| Fight mode | ofensivo | equilibrado | defensivo |
| Chase (byte 2) | 0 = standing | 1 = chase | - |
| Marcados (byte 3) | 0 = solo marcados | 1 = puede atacar sin marcar | - |

Este servidor **no contesta nada** para `0xA0` -a diferencia de party (`0x91`)
o trade (`0x7E`/`0x7F`)-, asi que el panel no espera ni puede esperar una
confirmacion: refleja unicamente su propio ultimo envio, igual que hace el
cliente clasico con este mismo paquete. El estado inicial (`ofensivo=1`,
`chase=false`, `marcados=false`) copia el default real de `Player` en
`servidor/src/player.h:1065,1071-1072` (`fightMode=FIGHTMODE_ATTACK`,
`chaseMode=false`, `secureMode=false`), no un valor inventado.

Cancelar el objetivo actual (Esc) ya estaba resuelto antes de este contrato:
`enviar_cancelar_accion()` manda `0xBE`
(`Game::playerCancelAttackAndFollow`), que el servidor confirma con el `0xA3`
que el cliente ya escuchaba (`objetivo_cancelado`). No se toco ese camino.

### Interaccion con camas reales (casas)

Esta seccion aplica al cliente jugable de la rama TVP 7.72 (`mundo3d.gd`). Una
cama del catalogo (`items772.json[cid].nombre == "bed"`, cualquiera de sus dos
mitades) tiene `tiene_alto=true`: su modelo 3D sube desde el piso, igual que
el marco vertical de una puerta simple. El clic normal para usar u observar
resuelve la casilla proyectando un rayo contra el plano del piso a la altura
del jugador; contra un objeto con altura ese rayo puede pasar de largo por
encima del respaldo y caer en la casilla siguiente, con cualquier otro objeto
que este ahi. Antes de este contrato eso se traducia en enviar el `spriteId`
de un objeto distinto (por ejemplo un tramo de pared) en una posicion vecina,
y el servidor rechazaba con `You cannot use this object` porque, con razon,
`item->getClientID() != spriteId` en `Game::playerUseItem`.

La correccion reutiliza el mismo mecanismo que ya resuelve puertas simples: un
test de rectangulo en pantalla contra la altura y el ancho reales del sprite
(`_hit_puerta_en_pantalla`), en vez de la interseccion con el plano del piso.
Se aplica con dos reglas fijas:

- La busqueda recorre **exclusivamente** `EstadoMundo.casillas`, la ventana
  viva que ya confirmo el servidor. Nunca el mapa estatico (`_mapa_visible`)
  ni el disco, y nunca una casilla vecina elegida por cercania: la unica
  fuente valida de que mitad de la cama esta en una casilla es el propio
  servidor, tal como pide `protocolo-red`.
- La busqueda queda acotada al piso del jugador y al radio de render
  (`_nivel_visible_para_interaccion`, `RADIO`), igual que las puertas, para no
  repetir el bug ya corregido de resolver la cama homologa de otro
  departamento del mismo edificio (Flat 01 contra Flat 11/21).

Si el rectangulo de ninguna cama viva cubre el clic, la resolucion cae al
camino normal (puerta simple bajo el mouse y, si tampoco hay, la casilla del
rayo contra el piso). No hay busqueda en vecindario ni offset fijo: si el
clic no cae sobre el rectangulo real de una cama, no se envia una cama.

El `use` sobre una cama manda el mismo `0x82` que cualquier objeto, con la
posicion, `spriteId` y `stackpos` que la ventana viva ya confirmo para esa
mitad exacta. La aceptacion, el rechazo y el efecto (dormir, ocupada, sin
permiso de la casa) son autoridad exclusiva del servidor; el cliente no
predice el resultado ni cambia el modelo de la cama hasta que la ventana viva
lo confirme.

### Ventana de texto

El servidor la abre con el `0x96` al usar un cartel, una carta o la etiqueta de
una parcel, y la respuesta vuelve por el `0x89` (`protocolo-red` 1.6.0).

La ventana muestra **solo lo que mando el servidor**: el nombre del item, quien
lo escribio y el texto actual. El maximo de caracteres tambien es suyo: al
escribir se corta ahi y se avisa cuantos quedan.

El paquete **no dice si el item se puede escribir**, asi que el cliente no lo
adivina: deja escribir siempre que el maximo sea mayor que cero y, si no
correspondia, el servidor rechaza el `0x89` con un `0xB4`. `Ok` manda lo
escrito; `Cancel` y `Esc` cierran sin mandar nada.

## Pruebas de cierre

- La escena arranca sin renderer con `--headless` y no produce errores de
  script.
- Con el servidor propio, un usuario recibe `WELCOME`/`STATE`, ve el mapa 3D y
  camina con teclado.
- Un segundo jugador recibido en `STATE` aparece en la escena.
- Un movimiento rechazado por el servidor no cambia la posicion visual.
- Una perdida de conexion limpia el mundo vivo y activa reconexion.
- La senal `jugador_muerto` bloquea intenciones, envia exactamente un `0x14`,
  deja visible la pantalla de reentrada y no vuelve solo al formulario de
  cuenta al cerrarse el socket.
- La reentrada pedida por el jugador limpia la sesion y vuelve al selector de
  personajes.
- Una criatura con calavera o escudo confirmados los muestra en el Battle List
  y en el Target con el nombre exacto de la tabla; una sin ellos no muestra
  marca, y un valor desconocido se oculta.
- `Speed` de la ventana Skills muestra la velocidad confirmada de `mi_id` y la
  cambia al recibir un `0x8F`.
- La ventana de texto muestra el texto y el autor que mando el servidor, corta
  en su maximo, y al aceptar devuelve el id de ventana y el texto tal cual.
- El menu de una criatura ofrece exactamente las acciones de party que
  permiten los escudos confirmados, y ninguna sobre un monstruo, un NPC o uno
  mismo.
- Elegir una accion de party envia su opcode y no cambia ningun escudo.
- Un clic sobre el rectangulo en pantalla de una mitad de cama viva manda el
  `spriteId` y la posicion exactos de esa mitad, aunque el rayo contra el
  piso caería en otra casilla.
- Un clic fuera del rectangulo de cualquier cama viva no envia una cama por
  cercania: cae al camino normal (puerta, luego rayo contra el piso).
- La busqueda de cama nunca usa `_mapa_visible` ni el disco, solo
  `EstadoMundo.casillas`.
- El panel de combate arranca con `ofensivo=1, chase=false, marcados=false`,
  igual que el default de `Player` en el servidor.
- Elegir un modo de ataque manda `[modo, chase actual, marcados actual]` sin
  tocar chase ni marcados; el grupo de botones deja presionado solo el modo
  elegido.
- Alternar chase o marcados manda el byte correspondiente conservando el modo
  de ataque y el otro alternador, y el texto del boton cambia entre sus dos
  caras (Chase Opponent / Stand While Fighting, Attack Unmarked Players /
  Marked Players Only).
