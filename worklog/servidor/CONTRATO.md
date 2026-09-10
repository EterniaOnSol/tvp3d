# Contrato: servidor

Version: 2.1.0
Estado: PUBLICADO
Propietario: servidor
Depende de: modelo-comun 2.1.0, protocolo-red 2.1.0, assets 2.0.0
(historial: Server V2 2.0.0 dependia de modelo-comun 2.0.0 y
protocolo-red 2.0.0; ver seccion 18 para el analisis de compatibilidad)

## Proposito y alcance normativo

Authoritative Server V2 es el runtime final de TVP3D: Godot 4.7 ejecutado
con `--headless`. Mantiene el estado de juego, valida toda intencion cliente
y es el unico emisor de hechos y snapshots autoritativos. TVP/TFS permanece
como oracle, referencia y puente de migracion; nunca opera como segunda
autoridad.

Este contrato congela el boundary generico capaz de alojar dominios futuros.
No implementa backend, autenticacion, combate, monstruos, mapa, items,
inventario, quests, houses ni spawns. Las palabras `DEBE`, `NO DEBE`,
`SOLO` y `RECHAZA` son normativas.

## 1. Autoridad exclusiva

El servidor es el unico owner de:

- existencia de entidades runtime y asignacion de RuntimeInstanceRefV2;
- posicion, direccion, ocupacion logica y revisiones;
- validacion/aplicacion de movimiento y reglas de dominio;
- decisiones de persistencia;
- aceptacion o rechazo de comandos;
- eventos, snapshots y replication sets autoritativos.

El cliente propone CommandEnvelopeV2. Ni una prediccion acertada ni una
presentacion plausible confirma estado. Mallas, GLB, colliders de
presentacion, animaciones, Blender, rigs, materiales, LOD y escala visual no
entran en ninguna decision o schema servidor.

## 2. Tipos comunes consumidos

Server V2 consume sin redefinir de modelo-comun 2.0.0:

- CanonicalDomainId y DomainIdentityV2;
- RuntimeInstanceRefV2;
- EntityDefinitionCoreV2;
- AuthoritativeEntityStateV2;
- PosicionTibiaV2 y DirectionV2;
- LogicalFootprintV1;
- CommandEnvelopeV2;
- AuthoritativeEventEnvelopeV2.

Sus formas, rangos, orden, nulabilidad, versionado y errores siguen siendo los
del contrato comun. El servidor no acepta una segunda forma de id, posicion,
direccion, footprint, comando, evento o estado. Ninguno de estos ocho tipos
cambio en 2.1.0.

Desde 2.1.0, Server V2 tambien consume sin redefinir de modelo-comun 2.1.0
(seccion 8A de ese contrato) los cuatro payloads neutrales de replicacion y
sus tres event types compartidos: `tvp3d.replication.entity_spawned/1.0.0`,
`tvp3d.replication.entity_core_state_changed/1.0.0`,
`tvp3d.replication.entity_despawned/1.0.0` y
`tvp3d.replication.core_entity_state/1.0.0`. El servidor sigue siendo su
unico productor autoritativo; modelo-comun sigue siendo el unico dueno de su
forma y semantica. Para estos cuatro payloads, esta seccion y las secciones
10-11 reemplazan la normativa que el servidor publicaba en 2.0.0; esa forma
2.0.0 queda preservada solo como HISTORICAL/SUPERSEDED (ver mas abajo).

Protocol V2 2.1.0 transporta esos envelopes y controla framing, handshake,
negociacion exacta de `common_domain_version` y secuencias. Assets V2 2.0.0
publica datos importados/normalizados. El servidor no reimplementa ninguno de
los tres contratos.

### Perfil de common domain nativo (protocolo-red 2.1.0)

Protocol V2 2.1.0 exige que cada perfil de aplicacion declare
`accepted_common_domain_versions`. El perfil nativo Architecture V2 de este
servidor declara exactamente:

```json
{
  "schema": "tvp3d.server.common_domain_profile",
  "version": "2.1.0",
  "accepted_common_domain_versions": ["2.1.0"]
}
```

Motivo: los cuatro eventos/snapshot core autoritativos de este servidor
dependen de los registros introducidos en modelo-comun 2.1.0
(`ENTITY_SPAWNED`, `ENTITY_CORE_STATE_CHANGED`, `ENTITY_DESPAWNED`,
`CORE_ENTITY_STATE`). El servidor NO DEBE anunciar `2.0.0` en este conjunto
solo porque el transporte sepa negociarlo: capacidad de transporte no es
compatibilidad de aplicacion.

Consecuencias exactas, aplicando el algoritmo de seleccion de
protocolo-red 2.1.0:

- si el cliente ofrece unicamente `["2.0.0"]`, la interseccion con
  `accepted_common_domain_versions=["2.1.0"]` es vacia: Protocol V2 responde
  `COMMON_DOMAIN_VERSION_UNSUPPORTED` y cierra; esta sesion NUNCA llega a
  READY ni a gameplay;
- si el cliente ofrece `["2.1.0"]` o `["2.0.0","2.1.0"]`, Protocol V2
  selecciona `2.1.0` y `SERVER_WELCOME.common_domain_version` es
  exactamente `"2.1.0"`;
- Protocol `READY` en esta seleccion sigue sin implicar autorizacion de
  aplicacion; `SessionBindingV2` sigue siendo obligatorio antes de mutar
  gameplay (seccion 7).

Este perfil es una decision de la aplicacion Server V2 nativa, no una
capacidad nueva de protocolo-red: protocolo-red 2.1.0 ya sabia negociar
`2.0.0` y `2.1.0` antes de este turno; lo que este contrato fija es que el
perfil nativo solo acepta `2.1.0`.

## 3. Boundary de datos publicados

El runtime normal no lee OTBM, OTB, XML, DAT, SPR ni `servidor/data/`. Solo
consume NormalizedRecordV2 de Assets 2.0.0 cuya salida correspondiente figure
como `NORMALIZED_DOMAIN` en un ImportRunManifestV2 exitoso.

### AuthoritativeDatasetManifestV2

El deployment selecciona explicitamente un manifest servidor:

```json
{
  "schema": "tvp3d.server.dataset_manifest",
  "version": "2.0.0",
  "dataset_id": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "assets_contract_version": "2.0.0",
  "import_run_manifest": {
    "logical_path": "assets/importados/v2/world.import-run.json",
    "sha256": "2222222222222222222222222222222222222222222222222222222222222222",
    "import_run_id": "sha256:3333333333333333333333333333333333333333333333333333333333333333"
  },
  "records": [{
    "logical_path": "assets/importados/v2/core/player-definition.json",
    "sha256": "4444444444444444444444444444444444444444444444444444444444444444",
    "record_id": "sha256:5555555555555555555555555555555555555555555555555555555555555555",
    "document_schema": "tvp3d.assets.normalized_record",
    "document_version": "2.0.0",
    "record_type": "ENTITY_DEFINITION",
    "payload_schema": "tvp3d.entity_definition",
    "payload_version": "2.0.0",
    "publication_class": "NORMALIZED_DOMAIN"
  }]
}
```

Todos los campos son obligatorios. `dataset_id` es content_id de la
serializacion del objeto sin ese campo, usando exactamente TVP3D Canonical
JSON Assets V2. `assets_contract_version` es el literal `2.0.0`.
logical_path cumple las reglas de path relativo de Assets V2; los hashes son
sha256 minusculos y los ids usan content_id.

`records` contiene `1..1000000` referencias unicas, ordenadas por
`payload_schema, payload_version, record_type, record_id`.
`publication_class` debe ser el literal `NORMALIZED_DOMAIN`. Cada referencia
debe coincidir por path, hash, document_schema, document_version y
publication_class con un output del ImportRunManifestV2 referenciado, cuyo
`result` debe ser `SUCCESS`. document_schema/version deben ser
`tvp3d.assets.normalized_record/2.0.0`. El archivo debe parsear exactamente
como NormalizedRecordV2; record_id, record_type, payload_schema y
payload_version deben coincidir con la referencia.

dataset manifest, import-run manifest y records se verifican completamente
antes de construir estado vivo. Un hash, path, id, schema o version distinto
no admite fallback.

### SupportedPayloadRegistrationV2

El servidor registra pares que sabe validar sin definir aqui sus payloads:

```json
{
  "schema": "tvp3d.server.payload_registration",
  "version": "2.0.0",
  "payload_schema": "tvp3d.entity_definition",
  "payload_version": "2.0.0",
  "record_type": "ENTITY_DEFINITION",
  "owner_contract": "modelo-comun",
  "owner_contract_version": "2.0.0",
  "required_for_ready": true
}
```

Todos los campos son obligatorios. Las versiones son SemVer y record_type es
registry_token. payload_schema conserva la forma exacta de Assets V2,
`^[a-z][a-z0-9_.]{0,127}$`; owner_contract usa
`^[a-z][a-z0-9_.-]{0,127}$` para permitir nombres como `modelo-comun`. La
clave unica del registro es
`(payload_schema, payload_version, record_type)`.

`required_for_ready=true` exige presencia y validacion por el contrato owner
antes de READY. Un par no registrado o una version desconocida falla el
startup. Agregar soporte exige publicar el contrato owner y una nueva
configuracion/version compatible del registro; nunca se trata el objeto como
diccionario opaco.

El contrato servidor no publica campos finales de mapa o items. Hasta que sus
owners publiquen esos schemas, no pueden registrarse como entrada
autoritativa.

### Entradas rechazadas

No pueden alimentar autoridad:

- IdentityResolutionV2 `UNRESOLVED` o `AMBIGUOUS`;
- `AUDIT_IR`, `CLIENT_DIAGNOSTIC` o caches sin gate adecuado;
- `items772.json` u otro lookup por client id como registry canonico;
- server id, client id, looktype, nombre XML o filename usados como
  CanonicalDomainId;
- payload_schema/version no registrado;
- manifest, hash, path o NormalizedRecordV2 mal formado;
- raw legacy files o `servidor/data/` como API runtime.

Un dato invalido no se reemplaza por mapa demo, definicion inventada ni valor
por defecto.

## 4. Maquina de startup y vida del proceso

`ServerLifecycleStateV2` es cerrado:

```text
BOOTING
LOADING_DATA
VALIDATING_DATA
READY
DRAINING
STOPPED
FAILED
```

| Estado | Trabajo permitido | Transiciones validas |
|---|---|---|
| `BOOTING` | validar configuracion no secreta | `LOADING_DATA` o `FAILED` |
| `LOADING_DATA` | leer manifest/records a staging | `VALIDATING_DATA` o `FAILED` |
| `VALIDATING_DATA` | hashes, gates, schemas, ids, referencias | `READY` o `FAILED` |
| `READY` | aceptar sesiones y comandos autorizados | `DRAINING` o `FAILED` |
| `DRAINING` | dejar de aceptar comandos, cerrar sesiones, hooks de cierre | `STOPPED` o `FAILED` |
| `STOPPED` | ninguno; terminal limpio | ninguno |
| `FAILED` | diagnostico/cierre seguro; terminal fallido | ninguno |

No hay salto entre estados. El mundo authoritative se publica atomicamente al
entrar en READY; staging incompleto nunca es visible. Antes de READY y desde
DRAINING ningun comando de gameplay muta estado.

Schema requerido ausente/desconocido, identidad requerida no resuelta,
definicion referenciada inexistente o input normalizado invalido lleva a
FAILED antes de abrir gameplay. Un fallo runtime no se recupera cargando demo.

Los perfiles `PRODUCTION` y `DEVELOPMENT_DEMO` son selecciones explicitas de
integracion. Un demo usa su propio dataset manifest valido y marcado por
configuracion; no es fallback de PRODUCTION. Este contrato no fija host,
puerto, `127.0.0.1`, `7277` ni `user://mapa_tvp3d.json`.

## 5. Runtime scope y asignacion de instancias

Tras validar el dataset y justo antes de READY, el servidor crea un
`runtime_scope_id` uuid_v4 nuevo. Es inmutable durante ese epoch.

Reglas:

- todo restart autoritativo crea un scope nuevo, aunque recargue el mismo
  estado persistente;
- SERVER_WELCOME.runtime_scope_id coincide exactamente con el scope activo;
- una sesion y todos sus RuntimeInstanceRefV2 pertenecen a ese scope;
- instance_id es positive_uint64_string, se asigna de forma monotona y nunca
  se reutiliza dentro del scope;
- el par retirado nunca vuelve a asignarse; overflow no hace wrap y lleva a
  DRAINING/FAILED segun cierre seguro;
- una ref de un scope anterior es stale y no identifica una entidad actual;
- runtime scope/ref son transitorios: nunca CanonicalDomainId ni identidad
  persistente.

El allocator conserva el high-water mark del epoch aun tras despawn. No se
deduce instance_id de legacy ids, posiciones, indices, session_id o hashes de
assets.

## 6. Definiciones e instancias

### DefinitionRegistry

La clave exacta es:

```text
(CanonicalDomainId, definition_version)
    -> EntityDefinitionCoreV2 + estado especializado validado
```

La identidad y version deben provenir de NormalizedRecordV2 resuelto,
NORMALIZED_DOMAIN y un payload pair registrado. Dos definiciones con la misma
clave son error aunque sus bytes coincidan. Aliases solo consultan un mapping
publicado y resuelto; nunca son keys directas de autoridad.

Para `tvp3d.entity_definition/2.0.0`, payload.identity debe coincidir byte a
byte con NormalizedRecordV2.identity, y payload.definition_version es la
version de la key. Una diferencia falla validacion; el servidor no elige una
de las dos identidades.

### RuntimeEntityStore

La clave exacta es:

```text
RuntimeInstanceRefV2
    -> AuthoritativeEntityStateV2 + estado especializado servidor
```

Una instancia solo nace si su `definition.canonical_id + definition_version`
existe. Su logical footprint efectivo se lee de esa version exacta. Un cambio
de asset visual no cambia definition, footprint, revision ni estado. Una
definicion desconocida no puede hacer spawn.

El estado especializado requiere contrato owner; no se admite un diccionario
libre. Este registry/store generico no agrega campos de monster, combate,
inventario o visuales.

## 7. SessionBindingV2

Protocol `READY` significa negociacion de transporte, no autenticacion ni
control de actor. El servidor mantiene una asociacion interna exacta:

```json
{
  "schema": "tvp3d.server.session_binding",
  "version": "2.0.0",
  "protocol_session_id": "9b7d8c4e-8e64-4f3b-a9e6-5efc17a8b2d1",
  "runtime_scope_id": "550e8400-e29b-41d4-a716-446655440000",
  "authorization_state": "AUTHORIZED",
  "actor": {
    "scope_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "42"
  }
}
```

Todos los campos son obligatorios. ids de sesion/scope son uuid_v4.
`authorization_state` es `UNBOUND`, `AUTHORIZED` o `REVOKED`.

| Estado | actor | Puede mutar gameplay |
|---|---|---|
| `UNBOUND` | null | no |
| `AUTHORIZED` | RuntimeInstanceRefV2 existente, mismo scope | solo ese actor y tras validar comando |
| `REVOKED` | la ultima ref autorizada, solo para auditoria transitoria | no |

La transicion cerrada es `UNBOUND -> AUTHORIZED -> REVOKED`. Cerrar el
protocol session elimina el binding. En 2.0.0 una sesion revocada no se
reautoriza; crea otra sesion. Solo servidor crea/cambia bindings.

El mecanismo que prueba identidad y autoriza `UNBOUND -> AUTHORIZED`
pertenece a un contrato futuro. Aqui no hay usernames, passwords, tokens,
OAuth, providers ni credential storage.

Invariantes:

- ningun COMMAND de gameplay se aplica sin binding AUTHORIZED;
- CommandEnvelopeV2.actor debe coincidir byte a byte con binding.actor;
- conocer o adivinar una RuntimeInstanceRefV2 no concede control;
- una conexion protocol READY sin binding no muta gameplay;
- rechazar autorizacion normal usa COMMAND_REJECTED, no ProtocolErrorV2.

## 8. Registro y pipeline de comandos

Cada handler habilitado posee un registro:

```json
{
  "schema": "tvp3d.server.command_registration",
  "version": "2.0.0",
  "type": "MOVE",
  "payload_owner_contract": "modelo-comun",
  "payload_owner_version": "2.0.0",
  "payload_type": "MOVE",
  "mutates_state": true
}
```

`type` y `payload_type` son registry_token; owner cumple la forma de
owner_contract y su version es SemVer. La clave `type` es unica. Registrar un
token no define sus reglas: el contrato owner debe publicar el payload y el
handler debe fijar exactamente esa version.

Por cada CommandEnvelopeV2, el orden obligatorio es:

1. Protocol V2 ya valido frame, rol y forma del envelope.
2. Verificar ServerLifecycleStateV2 `READY` y que la sesion no este syncing.
3. Verificar actor.scope_id y runtime_scope_id activos.
4. Resolver SessionBindingV2 y exigir AUTHORIZED + actor exacto.
5. Rechazar command_id ya visto en esa protocol session; registrar el nuevo
   id antes de evaluar reglas.
6. Verificar command type y payload contract registrados.
7. Validar el payload exacto con su contrato owner.
8. Evaluar precondiciones autoritativas.
9. Evaluar reglas/ocupacion/permisos del dominio owner.
10. Preparar en una transaccion todas las mutaciones, revisions resultantes y
    persistencia que el owner marque REQUIRED_FOR_COMMIT.
11. Ejecutar esos hooks y hacer commit atomico de estado + revisions, o
    rechazar todo con cero mutacion.
12. Emitir eventos autoritativos resultantes en orden determinista.
13. Ejecutar hooks AFTER_COMMIT_OBSERVATION si el owner los publica; son
    auditoria/replica y no pueden cambiar el resultado ya confirmado.

Los dos modos de hook son tokens cerrados de semantica, no backends:
`REQUIRED_FOR_COMMIT` participa en la atomicidad; `AFTER_COMMIT_OBSERVATION`
no puede decidir gameplay ni solicitar rollback. Un contrato especializado
debe elegir uno antes de persistir.

Un rechazo descarta staging de gameplay y hooks. No existe mutacion parcial.
Emite como maximo el COMMAND_REJECTED contratado: eso avanza la sequence del
stream de entrega, pero no cambia world state, entity revision ni
persistencia. Una prediccion cliente no se incorpora salvo que este pipeline
acepte y emita el resultado.

`command_id` se deduplica durante toda la protocol session. Repetirlo se
rechaza conforme `COMMAND_ID_DUPLICATE` de modelo-comun; no reaplica ni
devuelve el resultado anterior. Reconexion crea otra session pero no convierte
un comando viejo en idempotente.

## 9. Rechazos de comando y ServerErrorV2

Un rechazo de aplicacion es un hecho servidor, no ProtocolErrorV2. El objeto
exacto que normaliza el diagnostico es:

```json
{
  "schema": "tvp3d.server.error",
  "version": "2.0.0",
  "owner": {
    "contract": "servidor",
    "version": "2.0.0"
  },
  "code": "APPLICATION_SESSION_REQUIRED",
  "path": null,
  "message": "an authorized application session is required",
  "retryable": true,
  "mutation_occurred": false,
  "context": {}
}
```

Todos los campos son obligatorios. owner.contract cumple
`^[a-z][a-z0-9_.-]{0,127}$` y owner.version es SemVer; code es
registry_token. `path` es null o JSONPath ASCII de 1..256 bytes; message es
UTF-8 de 0..256 bytes, seguro para cliente y sin secretos. `context` debe ser
`{}` en 2.0.0. Un COMMAND_REJECTED exige `mutation_occurred=false`.

owner permite transportar un error de modelo-comun o de un contrato
especializado sin apropiarse de su codigo. Server V2 no incluye
ProtocolErrorV2 ni AssetImportErrorV2 dentro de ServerErrorV2.
ServerErrorV2 tampoco es DomainErrorV2: cuando falla un validador comun,
conserva su code/path/message y declara owner `modelo-comun/2.0.0` dentro
del wrapper de rechazo servidor; no cambia la tabla ni la forma comun.

Codigos propios de servidor 2.0.0:

| Codigo | Superficie | Retryable | Accion |
|---|---|---:|---|
| `SERVER_NOT_READY` | command fuera de READY | si | rechazar sin cola ni mutacion |
| `APPLICATION_SESSION_REQUIRED` | binding UNBOUND/ausente | si | rechazar; esperar autorizacion externa |
| `ACTOR_NOT_AUTHORIZED` | binding REVOKED o actor distinto | no | rechazar; no revelar otro estado |
| `ACTOR_SCOPE_MISMATCH` | binding/ref interno fuera del scope activo | no | rechazar y cerrar binding inconsistente |
| `COMMAND_PRECONDITION_FAILED` | precondicion autoritativa falsa | si | rechazar sin mutacion |
| `INSTANCE_UNKNOWN` | runtime ref valida pero inexistente/retirada | no | rechazar y solicitar baseline si aplica |
| `SYNC_IN_PROGRESS` | session sin baseline o recuperando | si | rechazar sin encolar |
| `DATASET_MANIFEST_INVALID` | manifest servidor mal formado | no | startup -> FAILED |
| `DATASET_HASH_MISMATCH` | hash/id/path no coincide | no | startup -> FAILED |
| `DATASET_PUBLICATION_CLASS_REJECTED` | output no NORMALIZED_DOMAIN | no | startup -> FAILED |
| `DATASET_SCHEMA_UNSUPPORTED` | payload pair no registrado | no | startup -> FAILED |
| `DATASET_IDENTITY_UNRESOLVED` | id requerido null/unresolved/ambiguous | no | startup -> FAILED |
| `DEFINITION_REGISTRY_CONFLICT` | clave de definition repetida | no | startup -> FAILED |
| `REPLICATION_SET_INVALID` | snapshot contiene ref/scope/orden invalido | si | no publicar snapshot |
| `REVISION_EXHAUSTED` | uint64 no puede incrementar | no | no wrap; DRAINING/FAILED |

Server V2 consume sin renombrar estos errores comunes cuando corresponden:
`COMMAND_ID_DUPLICATE`, `COMMAND_TYPE_UNKNOWN`,
`COMMAND_PAYLOAD_INVALID`, `COMMAND_ACTOR_MISMATCH`,
`DEFINITION_UNKNOWN`, errores de RuntimeInstanceRefV2, posicion, direccion,
footprint y revision. Su owner es `modelo-comun 2.0.0`.

En wire, un actor.scope_id que contradice SERVER_WELCOME ya es
`SESSION_SCOPE_MISMATCH` de Protocol V2 y no alcanza el pipeline servidor.
`ACTOR_SCOPE_MISMATCH` es defensa de la capa application para un binding o
llamada interna inconsistente; no redefine framing.

### COMMAND_REJECTED

El payload exacto es:

```json
{
  "schema": "tvp3d.server.command_rejected",
  "version": "2.0.0",
  "error": {
    "schema": "tvp3d.server.error",
    "version": "2.0.0",
    "owner": {"contract": "servidor", "version": "2.0.0"},
    "code": "COMMAND_PRECONDITION_FAILED",
    "path": null,
    "message": "authoritative precondition failed",
    "retryable": true,
    "mutation_occurred": false,
    "context": {}
  }
}
```

Viaja dentro de AuthoritativeEventEnvelopeV2 con
`type=COMMAND_REJECTED`. `causation_command_id` es el command_id rechazado.
`subject` es el actor solo si su ref es valida, pertenece al scope y es
conocida; de otro modo null. `subject_revision` siempre es null porque el
rechazo no muta al subject.

Un frame corrupto, rol ilegal, handshake faltante o schema de protocolo
invalido usa ProtocolErrorV2 y nunca COMMAND_REJECTED.

## 10. Registro minimo de eventos core

Server V2 2.1.0 sigue registrando exactamente:

```text
ENTITY_SPAWNED
ENTITY_CORE_STATE_CHANGED
ENTITY_DESPAWNED
COMMAND_REJECTED
```

Todos viajan en AuthoritativeEventEnvelopeV2. No son opcodes de transporte.
Desde 2.1.0 el servidor deja de redefinir la forma completa de los primeros
tres: son payloads neutrales de modelo-comun 2.1.0, referenciados aqui sin
copiarlos. `COMMAND_REJECTED` sigue siendo integramente servidor-owned.

| type | payload schema (owner) | subject | subject_revision | causation |
|---|---|---|---|---|
| `ENTITY_SPAWNED` | `tvp3d.replication.entity_spawned/1.0.0` (modelo-comun) | runtime id creado | `"0"` | command id o null |
| `ENTITY_CORE_STATE_CHANGED` | `tvp3d.replication.entity_core_state_changed/1.0.0` (modelo-comun) | runtime id mutado | revision resultante | command id o null |
| `ENTITY_DESPAWNED` | `tvp3d.replication.entity_despawned/1.0.0` (modelo-comun) | runtime id retirado | revision terminal | command id o null |
| `COMMAND_REJECTED` | `tvp3d.server.command_rejected/2.0.0` (servidor) | actor valido/conocido o null | null | command id obligatorio |

El servidor solo puede producir `ENTITY_SPAWNED`, `ENTITY_CORE_STATE_CHANGED`
y `ENTITY_DESPAWNED` dentro de una protocol session cuyo
`SERVER_WELCOME.common_domain_version` sea exactamente `2.1.0` (perfil nativo
de la seccion 2). Este perfil nunca deja que una sesion negociada en `2.0.0`
llegue a READY, asi que no existe una ruta nativa para que ese caso ocurra en
produccion; si ocurriera por un adapter transicional explicito, corresponde a
`COMMON_DOMAIN_REGISTRY_MISMATCH` de protocolo-red, no a un error de dominio
servidor.

### ENTITY_SPAWNED

`payload` es exactamente `tvp3d.replication.entity_spawned/1.0.0` de
modelo-comun 2.1.0: `{schema, version, state}`, con `state` igual a
`AuthoritativeEntityStateV2`. El servidor no repite esa forma aqui;
`worklog/modelo-comun/CONTRATO.md` seccion 8A define el objeto exacto y sus
invariantes (revision inicial `"0"`, `envelope.subject == state.runtime_id`,
`envelope.subject_revision == state.revision`). Regla propia del servidor:
solo emite este evento cuando una transaccion del pipeline (seccion 8) crea
una instancia runtime nueva con definicion resuelta; el payload no decide
quien puede spawnear, eso es politica de dominio/servidor.

### ENTITY_CORE_STATE_CHANGED

`payload` es exactamente `tvp3d.replication.entity_core_state_changed/1.0.0`
de modelo-comun 2.1.0: estado core resultante completo, nunca un patch
ambiguo (ver seccion 8A de modelo-comun para la prohibicion explicita de
forma patch). Regla propia del servidor: cada transaccion atomica que cambia
posicion y/o direccion de una instancia incrementa su revision exactamente
una vez y emite exactamente un evento con ese estado resultante, aunque
cambien varios campos core en la misma transaccion.

### ENTITY_DESPAWNED

`payload` es exactamente `tvp3d.replication.entity_despawned/1.0.0` de
modelo-comun 2.1.0: `{schema, version, reason}`, con `reason` unicamente
`REMOVED` en esta version del payload neutral. Regla propia del servidor:
incrementa una vez la revision terminal, la emite como `subject_revision` y
retira la instancia atomicamente; la ref queda retirada para siempre. Salir
de un replication set sin destruir la instancia no se reinterpreta como
despawn; una politica futura debe contratar ese evento.

### Semantica de revisions y multiples sujetos

- un evento que incluye state usa la revision resultante exacta;
- COMMAND_REJECTED nunca incrementa revision;
- un comando que cambia varios sujetos emite un evento por sujeto en el orden
  numerico de instance_id, salvo que el contrato owner publique otro orden;
- stream sequence ordena entrega a una sesion, no mutaciones globales;
- eventos especializados futuros pueden agregarse por sus contratos sin
  cambiar Protocol V2.

No se registran eventos de monster, combate, items, loot, spawn de especie,
animacion ni assets.

## 11. Snapshot core y replication set

Protocol SNAPSHOT transporta, para este perfil nativo, exactamente:

```text
payload_type    = CORE_ENTITY_STATE
payload_version = 1.0.0
payload schema  = tvp3d.replication.core_entity_state/1.0.0 (modelo-comun)
```

El servidor deja de redefinir aqui la forma completa de ese payload;
`worklog/modelo-comun/CONTRATO.md` seccion 8A define el objeto exacto
(`schema`, `version`, `runtime_scope_id`, `entities[]`) y sus invariantes:
`0..1000000` `AuthoritativeEntityStateV2` exactos, sin `runtime_id`
duplicados, todos dentro de `runtime_scope_id`, ordenados por valor numerico
ascendente de `instance_id`, cada `definition` resoluble por el consumidor.

Lo que sigue siendo autoridad exclusiva del servidor, y que modelo-comun no
decide:

- el instante/boundary de generacion del snapshot;
- que entidades pertenecen al replication set de esa protocol session;
- cuando capturar un snapshot nuevo (INITIAL, gap, conflict, stale revision);
- que cada `definition` referenciada exista en `DefinitionRegistry` antes de
  incluirla.

El payload representa el replication set autoritativo completo de esa
protocol session en el boundary capturado; no necesariamente todas las
entidades del mundo. Visibilidad, regiones de interes y streaming espacial
requieren contrato futuro; el cliente no agrega ni omite miembros por
iniciativa propia.

Un snapshot solo se transporta dentro de una protocol session cuyo
`common_domain_version` negociado sea `2.1.0` (seccion 2); este perfil nunca
deja llegar a READY una sesion negociada en `2.0.0`, asi que no existe una
ruta nativa de produccion para transportar
`tvp3d.server.core_entity_state/2.0.0` bajo 2.1.0 (forma preservada solo como
HISTORICAL/SUPERSEDED, ver mas abajo).

No contiene aliases legacy, client id, looktype, sprite, GLB, material, rig,
clip, animacion, collider, visual bounds o transform 3D.

## 12. Event stream, world state y sync

Conceptos distintos:

| Concepto | Scope | Significado |
|---|---|---|
| protocol stream_id/sequence | una entrega a una session | orden de eventos transportados |
| AuthoritativeEntityStateV2.revision | una runtime instance | orden de mutaciones de esa entidad |
| simulation/game tick | loop servidor | reloj interno no definido aqui |
| persistent revision | record persistente especializado | concurrencia/persistencia futura |

Ninguno se copia o deriva automaticamente de otro. Dos sesiones pueden tener
stream ids/sequences diferentes para representar el mismo world state.

Ante INITIAL, gap, duplicate conflict o stale subject revision:

1. la session entra en `SYNCING`/sin baseline;
2. no se aceptan, encolan ni aplican gameplay COMMAND;
3. el servidor captura el replication set desde un unico boundary
   autoritativo, fuera de una transaccion parcialmente aplicada;
4. valida el snapshot neutral `tvp3d.replication.core_entity_state/1.0.0`
   completo (seccion 11);
5. crea un stream_id nuevo y envia Protocol SNAPSHOT con `last_sequence="0"`;
6. ese snapshot reemplaza atomicamente el payload_type y fija baseline; el
   siguiente evento de ese stream usa sequence `"1"`.

Server V2 2.1.0 no exige replay de eventos. Enviar un COMMAND durante
Protocol SYNCING es una violacion de estado protocol; si una llamada interna
alcanza el application pipeline, recibe `SYNC_IN_PROGRESS` sin mutacion ni
cola. PING/PONG y GOODBYE conservan su semantica de protocolo.

## 13. Footprint logico y ocupacion

Para cada entidad:

```text
effective occupied cells =
  AuthoritativeEntityStateV2.position
  + LogicalFootprintV1
```

Se usa exactamente la formula, anchor, offsets, orden y overflow de
modelo-comun 2.0.0. La position es el anchor autoritativo y todas las celdas
conservan su z.

Ocupar una celda no implica por si mismo bloquear toda otra entidad. Las
reglas de coexistencia, terrain, pathfinding y permisos pertenecen al
contrato especializado del mundo. Cuando una regla especializada consulta
ocupacion, usa estas celdas logicas; nunca AABB, mesh bounds, collider,
escala, vertices o dimensiones GLB.

## 14. MOVE comun

`MOVE` conserva unicamente la semantica comun 2.0.0:

1. validar `abs(dx)+abs(dy)==1`;
2. mapear `(0,-1)=NORTH`, `(1,0)=EAST`, `(0,1)=SOUTH`,
   `(-1,0)=WEST`;
3. calcular el anchor propuesto `(x+dx,y+dy,z)` sin overflow y en el mismo
   piso;
4. calcular todas las celdas LogicalFootprintV1 propuestas;
5. preguntar al contrato owner de world/map/occupancy si el movimiento esta
   permitido;
6. si acepta, actualizar posicion + direccion atomicamente, incrementar una
   vez revision y emitir ENTITY_CORE_STATE_CHANGED;
7. si rechaza, conservar posicion, direccion, ocupacion y revision.

`walkable_historical`, `queryadd_walkable`, `blocking` importado o una
colision visual nunca constituyen por si solos la respuesta. Hasta publicar
el contrato de Map/World Rules, MOVE puede validarse como envelope pero no
habilitarse como handler de produccion V2.

## 15. Boundary de persistencia

El servidor decide si y cuando persiste estado segun el contrato owner. Este
turno no elige SQL, SQLite, MariaDB, filesystem ni otro backend, ni define
transacciones fisicas.

Nunca son identidad persistente:

- RuntimeInstanceRefV2, scope_id o instance_id;
- event_id, stream_id o sequence;
- protocol session_id o command_id;
- legacy server/client id o looktype;
- filename GLB o cualquier referencia visual.

Un record persistente usa la identidad estable publicada por su dominio. Si
un personaje requiere identidad persistente distinta de su type/definition,
el contrato de Persistent Character Identity debe publicarla; no se promueve
una ref runtime. Los hooks ocurren dentro o despues del commit segun el owner,
pero un fallo nunca permite confirmar al cliente una mutacion parcial.

No se exponen credenciales ni configuracion de storage.

## 16. Fixtures contractuales requeridos

La implementacion futura debe cubrir, como minimo:

- startup rechaza payload schema/version no registrado;
- startup rechaza identidad requerida unresolved/ambiguous;
- AUDIT_IR y CLIENT_DIAGNOSTIC rechazados como input autoritativo;
- legacy client id/looktype rechazados como CanonicalDomainId;
- hash/manifest mal formado falla startup sin demo;
- restart autoritativo crea runtime_scope_id distinto;
- un par runtime retirado nunca se reutiliza;
- spawn con definition desconocida falla;
- command antes de READY causa cero mutacion;
- protocol READY sin application binding no permite gameplay;
- actor no ligado y actor de otra session son rechazados;
- cliente no puede mutar otro actor;
- rechazo deja byte-equivalentes world state, revisions y persistencia, y
  emite exactamente un COMMAND_REJECTED si la session tiene stream activo;
- mutacion exitosa incrementa revision exactamente una vez;
- ENTITY_CORE_STATE_CHANGED lleva la revision resultante;
- command_id repetido produce COMMAND_ID_DUPLICATE y no reaplica;
- snapshot ordena numericamente instance_id y usa el mismo runtime scope;
- gap produce sync + snapshot con stream nuevo/baseline cero;
- session syncing no muta, encola ni reaplica comandos;
- footprint 1x1 produce una celda;
- footprint multi-SQM usa anchor/offsets comunes;
- cambiar dimensiones visuales deja ocupacion byte-equivalente;
- estado/mensaje Server 1.x no valida como schema Server V2.

### Fixtures agregados en Phase 1D.4 (alineacion 2.1.0)

- el perfil nativo declara `accepted_common_domain_versions=["2.1.0"]`;
- un cliente que solo ofrece `["2.0.0"]` nunca alcanza una sesion de
  gameplay: Protocol V2 responde `COMMON_DOMAIN_VERSION_UNSUPPORTED` antes de
  READY;
- un cliente que ofrece `2.1.0` hace que Protocol V2 seleccione `2.1.0` y
  `SERVER_WELCOME.common_domain_version` sea exactamente `"2.1.0"`;
- Protocol `READY` con `SessionBindingV2.authorization_state=UNBOUND` produce
  cero mutacion de gameplay ante cualquier COMMAND;
- `ENTITY_SPAWNED` emitido en produccion usa el payload neutral
  `tvp3d.replication.entity_spawned/1.0.0`, no `tvp3d.server.*`;
- `ENTITY_CORE_STATE_CHANGED` emitido en produccion usa el payload neutral
  `tvp3d.replication.entity_core_state_changed/1.0.0`;
- `ENTITY_DESPAWNED` emitido en produccion usa el payload neutral
  `tvp3d.replication.entity_despawned/1.0.0`;
- el identificador superseded `tvp3d.server.entity_spawned/2.0.0` es
  rechazado como forma normativa en una sesion nativa negociada en `2.1.0`;
- `COMMAND_REJECTED` sigue usando exactamente `tvp3d.server.command_rejected/2.0.0`,
  sin migrar al registro neutral;
- el snapshot SNAPSHOT usa `payload_type=CORE_ENTITY_STATE`,
  `payload_version=1.0.0` y el schema neutral `tvp3d.replication.core_entity_state/1.0.0`;
- el payload del snapshot no cambia de forma aunque el servidor elija un
  replication set distinto entre dos capturas;
- un comando rechazado sigue produciendo cero mutacion de gameplay,
  exactamente como en 2.0.0;
- un comando aceptado sigue incrementando la revision de la entidad
  exactamente una vez, exactamente como en 2.0.0;
- ningun payload autoritativo (evento, snapshot, error) admite un campo
  visual (GLB, sprite, mesh, material, rig, skeleton, clip, animacion, LOD,
  AABB, escala visual, Blender, image-to-3D).

Son especificaciones, no tests ni implementacion de produccion.

## 17. Downstream y contratos especializados faltantes

Migraciones contractuales posteriores:

- `cliente`: consumir los cuatro eventos core y CORE_ENTITY_STATE, mantener
  prediction como presentacion y exigir binding/baseline antes de input;
- `editor`: producir referencias a CanonicalDomainId/version y nunca marcar
  audit/unresolved como dataset servidor;
- `qa`: materializar fixtures de lifecycle, dataset, binding, atomicidad,
  revision, snapshot, sync y footprint contra Server V2;
- `integracion`: publicar launch profiles/config externos para Godot
  `--headless`, seleccionar dataset manifest y separar production/demo sin
  hardcodear host, puerto, paths o secretos.

Antes de implementar las capacidades correspondientes faltan contratos
especializados:

| Capacidad | Contrato requerido |
|---|---|
| terrain, mapa, pathfinding y ocupacion | Map / World Rules Domain |
| items, containers, inventory y drops | Item / Inventory Domain |
| login application, personaje persistente y binding | Authentication / Persistent Character Identity |
| damage, attacks, conditions y effects logicos | Combat Domain |
| especies, AI, spawns y loot de creatures | Monster Domain + Spawn Domain |
| quests, storages, houses, beds y permisos | Quest / House Domain |

No se publican aqui. Especialmente Monster Domain, Monster3D y Cyclops siguen
fuera de alcance.

### Gate Client V2 (Phase 1D.4)

Con `servidor 2.1.0` publicado sobre `modelo-comun 2.1.0` y
`protocolo-red 2.1.0`, el siguiente carril contractual puede ser `cliente`.
Su contrato debe depender de:

```text
modelo-comun 2.1.0
protocolo-red 2.1.0
assets 2.0.0
```

NO de `servidor`. El cliente consume `AuthoritativeEventEnvelopeV2` +
`ENTITY_SPAWNED`/`ENTITY_CORE_STATE_CHANGED`/`ENTITY_DESPAWNED` neutrales y
Protocol SNAPSHOT + `CORE_ENTITY_STATE`/1.0.0 directamente desde
modelo-comun y protocolo-red; no importa ni depende del contrato `servidor`
para interpretar esos payloads. El cliente si debe conocer, fuera de
schema, que un servidor con este perfil nativo exige
`common_domain_version=2.1.0` para llegar a gameplay, y que
`SessionBindingV2 AUTHORIZED` sigue siendo una precondicion de aplicacion
que el cliente no controla ni puede simular.

Contract-only: este turno no modifica `cliente`, `mundo3d.gd` ni implementa
gameplay.

## 18. Compatibilidad y migracion

Server 2.0.0 es un cambio major frente a Server 1.x. Server 1.x usa ids
uint32 de sesion, HELLO/STATE/ERROR, mapa v1 y protocolo propio 1.x; ningun
objeto se reinterpreta como V2. Un endpoint/fixture 1.x requiere adapter
explicito.

### Analisis SemVer explicito: 2.0.0 -> 2.1.0

Server 2.1.0 es una extension minor compatible de 2.0.0, no una
reinterpretacion:

| Superficie | Cambio en 2.1.0 | Compatible |
|---|---|---|
| Autoridad exclusiva (seccion 1) | ninguno | si |
| Ocho tipos comunes core consumidos (seccion 2) | ninguno | si |
| `AuthoritativeDatasetManifestV2`, registro de payloads, entradas rechazadas | ninguno | si |
| `ServerLifecycleStateV2` y maquina de startup | ninguno | si |
| Runtime scope / asignacion de instancias | ninguno | si |
| `DefinitionRegistry` / `RuntimeEntityStore` | ninguno | si |
| `SessionBindingV2`, sus tres estados y transiciones | ninguno | si |
| Pipeline de comandos (13 pasos, seccion 8) | ninguno | si |
| `ServerErrorV2`, codigos propios, `COMMAND_REJECTED` | ninguno | si |
| `tvp3d.server.entity_spawned/2.0.0`, `tvp3d.server.entity_core_state_changed/2.0.0`, `tvp3d.server.entity_despawned/2.0.0`, `tvp3d.server.core_entity_state/2.0.0` | dejan de ser la forma normativa; se sustituyen por una migracion explicita hacia `tvp3d.replication.*/1.0.0` de modelo-comun, con campos equivalentes segun la normalizacion ya declarada por modelo-comun 2.1.0, no una reinterpretacion silenciosa | si, es una migracion declarada con tabla e HISTORICAL/SUPERSEDED (ver mas abajo) |
| `accepted_common_domain_versions` del perfil nativo | pasa a declararse explicitamente como `["2.1.0"]` | si, es politica de aplicacion nueva, no un campo de un schema 2.0.0 existente |
| Footprint, MOVE comun, boundary de persistencia, boundary de assets | ninguno | si |

Ningun schema, rango, regla de autoridad o estado obligatorio de Server 2.0.0
cambio de significado; los cuatro identificadores de payload de replicacion
se reemplazan por una migracion declarada, con sus campos preservados segun
la normalizacion de modelo-comun 2.1.0 (solo `schema`/`version` raiz
cambian). Por eso 2.1.0 es la version correcta; no se requiere 3.0.0.

### Migracion de los cuatro identificadores server-owned (D-011)

| Identificador Server 2.0.0 (superseded) | Identificador neutral 2.1.0 (normativo) |
|---|---|
| `tvp3d.server.entity_spawned/2.0.0` | `tvp3d.replication.entity_spawned/1.0.0` |
| `tvp3d.server.entity_core_state_changed/2.0.0` | `tvp3d.replication.entity_core_state_changed/1.0.0` |
| `tvp3d.server.entity_despawned/2.0.0` | `tvp3d.replication.entity_despawned/1.0.0` |
| `tvp3d.server.core_entity_state/2.0.0` | `tvp3d.replication.core_entity_state/1.0.0` |

La migracion cambia solo los campos raiz `schema` y `version`; todo otro
campo, tipo, rango, nulabilidad, orden e invariante permanece igual, segun la
normalizacion que modelo-comun 2.1.0 ya declaro. El perfil nativo de este
servidor (`accepted_common_domain_versions=["2.1.0"]`) NO DEBE aceptar los
cuatro identificadores `tvp3d.server.*` como formas validas de esos tres
eventos o del snapshot en produccion: quedan como HISTORICAL/SUPERSEDED (ver
mas abajo) y cualquier adapter transicional que los traduzca debe ser
explicito, nunca un alias implicito silencioso.

TVP/TFS y protocolo 7.72 quedan operativos como oracle/migration bridge hasta
Phase 10. Paridad se captura como fixture con procedencia; nunca se invoca al
legacy para decidir una transaccion V2 en vivo.

Un patch no cambia schema ni autoridad. Una minor puede agregar un codigo,
registro o capacidad opcional solo con negociacion/rechazo seguro, o
sustituir un identificador de schema propio por una migracion explicita hacia
un contrato owner neutral sin cambiar campos ni semantica. Cambiar estado
obligatorio, autoridad, lifecycle, ids, atomicidad o forma/semantica de un
schema que siga siendo servidor-owned requiere major nuevo.

## 19. Consumidores y exclusiones

Consumidores: servidor Godot headless futuro, cliente, integracion, QA,
editor y contratos de dominio especializados.

Server V2 no expone secretos, credenciales, proveedores, storage backend,
host/puerto final, filesystem privado, payloads no publicados, datos de
monster/combat/item/quest, ni informacion visual. No autoriza modificar
codigo, mapa, red, runtime legacy, `mundo3d.gd`, Monster Domain o Monster3D.

## HISTORICAL / SUPERSEDED: schemas server-owned de replicacion (Server 2.0.0)

Estado: `SUPERSEDED` por las secciones 10 y 11 de este contrato desde 2.1.0.

Server V2 2.0.0, publicado antes de D-011, definia normativamente estos
cuatro payloads completos. Se preservan aqui unicamente como evidencia
historica y como base de la tabla de migracion de la seccion 18; ya NO son la
forma normativa de `ENTITY_SPAWNED`, `ENTITY_CORE_STATE_CHANGED`,
`ENTITY_DESPAWNED` ni del snapshot `CORE_ENTITY_STATE` bajo el perfil nativo
2.1.0, y el perfil nativo no los acepta como entrada.

### `tvp3d.server.entity_spawned/2.0.0` (superseded)

```json
{
  "schema": "tvp3d.server.entity_spawned",
  "version": "2.0.0",
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

### `tvp3d.server.entity_core_state_changed/2.0.0` (superseded)

```json
{
  "schema": "tvp3d.server.entity_core_state_changed",
  "version": "2.0.0",
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
    "position": {"x": 32098, "y": 32219, "z": 7},
    "direction": "EAST",
    "revision": "1"
  }
}
```

### `tvp3d.server.entity_despawned/2.0.0` (superseded)

```json
{
  "schema": "tvp3d.server.entity_despawned",
  "version": "2.0.0",
  "reason": "REMOVED"
}
```

### `tvp3d.server.core_entity_state/2.0.0` (superseded)

```json
{
  "schema": "tvp3d.server.core_entity_state",
  "version": "2.0.0",
  "runtime_scope_id": "550e8400-e29b-41d4-a716-446655440000",
  "entities": [{
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
  }]
}
```

Estos cuatro objetos son equivalentes campo a campo a sus sucesores
neutrales, excepto por los campos raiz `schema`/`version`, segun la
normalizacion que modelo-comun 2.1.0 ya declaro. No desaparecen del
historial Git ni de este documento: dejan de ser la forma que el perfil
nativo 2.1.0 produce o acepta como entrada valida.

## HISTORICAL / PARITY EVIDENCE: Server 1.1.0

Estado: `SUPERSEDED` por Authoritative Server V2 2.0.0.

Dependencias originales: modelo-comun 1.0.0, protocolo-red 1.0.0,
assets 1.3.0. Los hosts, puertos, rutas, mensajes y reglas siguientes solo
describen el prototipo/legacy y sus fixtures; no configuran Server V2.

Evidencia legacy preservada:

| Evidencia | Clasificacion V2 |
|---|---|
| movimiento TVP/prototipo, ocupacion y STATE ordenado | fixture de paridad para Map / World Rules |
| ids/jugador/posicion/direccion de sesion | input de migracion; requiere tipos comunes V2 |
| items readable/writeable y guarda `canReadText` | fixture futuro Item / Quest Domain |
| House::addTile, beds, `item->getBed()`, sleep/wake | fixture futuro Quest / House Domain |
| Edron Demon scroll room, AID 3121 y storage 10000 | fixture futuro Monster/Spawn/Quest; no primitive core |
| skull/party/player state del runtime TVP | oracle para dominios posteriores |

Los eventos historicos conservan evidencia de que:

- registrar House::addTile activa flags/pertenencia de casas en TVP;
- la guarda de use item debio permitir `canReadText` para cartas/labels y
  `getBed()` para alcanzar BedItem::canUse;
- dormir y retirar al jugador fueron observados; wake/persistencia quedaron
  parcialmente pendientes;
- esos resultados prueban el legacy, no implementan semantica nativa V2.

### Sala del pergamino de Demon

- La sala de Edron usa la posicion Tibia [33063,31623,15] como spawn
  inicial determinista: monstername=Demon, amount=1, radius=0.
- El item con AID 3121 es el unico disparador de la emboscada. Al retirarlo,
  si GlobalStorageKeys.edronDemonScroll != 1, crea exactamente cuatro
  Demons en [33060,31623,15], [33066,31623,15], [33066,31627,15] y
  [33060,31627,15], y luego fija la storage a 1.
- Retirar el pergamino otra vez es idempotente: no crea duplicados ni mueve
  el Demon inicial. La autoridad permanece en el servidor y el cliente solo
  representa el STATE recibido.
- El cambio de radio no altera otros spawns de Demon ni el comportamiento de
  la emboscada; se limita a esta entrada exacta del mapa.

### Proposito historico

Ejecutar el mundo propio de TVP3D como una autoridad headless. El servidor
recibe intenciones, valida cada transicion contra su mapa y ocupacion actuales
y solo entonces emite el estado confirmado por `STATE`.

### Perfil de ejecucion historico

- Proceso: Godot 4 en modo `--headless`.
- Host local de desarrollo: `127.0.0.1`.
- Puerto del perfil propio: `7277`.
- Mapa: `user://mapa_tvp3d.json`, version `1` del modelo comun.
- Si el archivo no existe, el perfil de demo inicia con el mapa determinista
  integrado y lo anuncia en el log; un mapa existente pero invalido hace que
  el proceso termine con error y no se sustituye silenciosamente.
- El estado de jugadores es de sesion y vive en memoria durante este perfil;
  no se persisten credenciales, tokens ni sesiones desconectadas.

### Estados de conexion historicos

| Estado | Entrada valida | Salida |
|---|---|---|
| `CONECTADO` | `HELLO` valido | `EN_MUNDO` |
| `CONECTADO` | `MOVE`, `PING` o `GOODBYE` | `CONECTADO` + `ERROR`, o desconexion |
| `EN_MUNDO` | `MOVE` validado | `EN_MUNDO` + `STATE` |
| `EN_MUNDO` | `MOVE` rechazado | `EN_MUNDO` + `ERROR`, sin mutar estado |
| `EN_MUNDO` | `PING` | `EN_MUNDO` + `PONG` |
| cualquier estado | `GOODBYE` o cierre TCP | desconectado |

El servidor acepta del cliente solamente `HELLO`, `MOVE`, `PING` y `GOODBYE`.
`WELCOME`, `STATE`, `ERROR` y `PONG` son mensajes de salida; recibirlos como
entrada es un error de direccion y no cambia el mundo.

### Estado autoritativo historico

Cada jugador listo conserva:

```json
{
  "id": "uint32>0",
  "nombre": "string[1..24]",
  "pos": "PosicionTibia",
  "direccion": "norte|este|sur|oeste"
}
```

Los ids son unicos durante la ejecucion. Cada nuevo jugador recibe una casilla
caminable libre; el servidor nunca confirma dos jugadores sobre la misma
casilla. Al entrar o salir un jugador, todos los jugadores listos reciben el
`STATE` completo y ordenado por id.

### Resolucion historica de `MOVE`

1. El mensaje debe pertenecer al estado `EN_MUNDO` y cumplir el contrato de
   `protocolo-red`.
2. Se registra la intencion `SOLICITADA`.
3. Se calcula la posicion vecina y se vuelve a comprobar que el tile sea
   `SUELO` o `ESCALERA`, tenga el mismo `z` y este dentro del mapa.
4. Se comprueba que ningun otro jugador listo ocupe la posicion destino.
5. Si ambas comprobaciones pasan, la transicion es `VALIDADA`, `APLICADA` y
   `EMITIDA`; se actualizan posicion y direccion y se difunde `STATE`.
6. Si falla una comprobacion, la transicion es `RECHAZADA` y `EMITIDA` como
   `ERROR`; la posicion, ocupacion y mapa quedan sin cambios.

Errores de rechazo de movimiento:

| Codigo | Motivo |
|---|---|
| `IDENTIFICACION_REQUERIDA` | Aun no se recibio `HELLO` valido |
| `MOVIMIENTO_BLOQUEADO` | El destino no es caminable o esta fuera del mapa |
| `MOVIMIENTO_OCUPADO` | Otro jugador listo ocupa el destino |
| `MOVIMIENTO_NO_CARDINAL` | El payload no representa un paso cardinal |
| `OPCODE_NO_PERMITIDO` | El cliente envio un opcode de salida |
| `HELLO_DUPLICADO` | Se intento cambiar la identidad de una sesion lista |

Los textos enviados en `ERROR.mensaje` son breves y quedan limitados por el
maximo de 160 caracteres del protocolo.

### Arranque y fallos historicos

- Un fallo al abrir o validar un mapa existente impide arrancar el listener.
- Un fallo al enlazar el puerto termina con codigo de salida distinto de cero.
- Un paquete invalido del protocolo se informa, se cierra esa conexion y no se
  reinterpretan sus bytes restantes.
- La desconexion de un cliente elimina su entidad y difunde el nuevo `STATE`.
- El servidor no expone rutas privadas, secretos ni datos de autenticacion.

### Pruebas de cierre historicas

- Arranque reproducible con `--headless`.
- Dos clientes reciben el mismo `STATE` con las mismas entidades.
- Un segundo cliente no puede ocupar la casilla del primero.
- Un movimiento hacia un tile bloqueado no muta estado y produce `ERROR`.
- `HELLO`, `WELCOME`, `STATE`, `MOVE`, `ERROR`, `PING`, `PONG` y `GOODBYE`
  usan exclusivamente el framing de `protocolo-red` propio.

### No expone el perfil historico

- No implementa el framing ni los opcodes TVP 7.72.
- No permite al cliente escribir mapa, posiciones o persistencia.
- No convierte tiles desconocidos en suelo.
