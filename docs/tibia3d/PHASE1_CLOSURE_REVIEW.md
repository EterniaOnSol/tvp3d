# Architecture V2 — Phase 1 Closure Review

Estado: REVISION DE ORQUESTACION COMPLETADA
Rama revisada: `feature/architecture-v2`
Rol: orquestacion / revision cruzada. Este documento no implementa produccion,
no modifica contratos de carril y no inicia Phase 2.

## 1. Alcance de esta revision

Determinar, con evidencia, si Architecture V2 **Phase 1 — freeze domain
contracts** satisface su gate de roadmap. Esta revision es sobre el
**congelamiento de contratos**, no sobre si las implementaciones de
servidor/cliente/editor/integracion estan completas. Ambas cosas son
conceptos relacionados pero distintos:

| Concepto | Significa |
|---|---|
| `PHASE 1 CERRADA` | los contratos fundacionales requeridos son coherentes y estan publicados |
| `CARRIL HECHO` | la Definicion de Hecho completa de ese carril, incluida implementacion/pruebas donde `CARRILES.md` lo exige, realmente paso |

Ningun carril de implementacion se declara `HECHO` en este documento
solo para poder cerrar Phase 1.

## 2. Matriz exacta de version de contrato (verificada contra archivos)

| Contrato | Version verificada | Esperada | Coincide |
|---|---|---|---|
| `modelo-comun` | `2.1.0` | `2.1.0` | si |
| `protocolo-red` | `2.1.0` | `2.1.0` | si |
| `assets` | `2.0.0` | `2.0.0` | si |
| `servidor` | `2.1.0` | `2.1.0` | si |
| `cliente` | `2.0.0` | `2.0.0` | si |
| `editor` | `2.0.0` | `2.0.0` | si |
| `integracion` | `2.0.1` | `2.0.1` | si |
| `qa` | `2.0.0` | `2.0.0` | si |

Todas las versiones fueron leidas directamente de la linea `Version:` de cada
`worklog/<carril>/CONTRATO.md` en HEAD de esta rama, no asumidas del prompt.

## 3. Grafo de dependencias (reconstruido de los headers de contrato)

```text
modelo-comun (ninguno)
    -> protocolo-red 2.1.0 (obligatorio 2.0.0 + negociable 2.1.0)
    -> servidor 2.1.0
    -> cliente 2.0.0
    -> editor 2.0.0
    -> qa 2.0.0

assets 2.0.0 (ninguno para publicar)
    -> servidor 2.1.0
    -> cliente 2.0.0
    -> editor 2.0.0
    -> qa 2.0.0

protocolo-red 2.1.0
    -> servidor 2.1.0
    -> cliente 2.0.0
    -> qa 2.0.0

servidor 2.1.0, cliente 2.0.0, editor 2.0.0, assets 2.0.0
    -> integracion 2.0.1
    -> qa 2.0.0

todos los contratos publicados
    -> qa 2.0.0
```

Verificaciones puntuales:

- **No hay arista `servidor -> cliente` ni `cliente -> servidor`**: el header
  de `cliente/CONTRATO.md` declara explicitamente "Cliente V2 NO depende de
  `servidor`"; `servidor/CONTRATO.md` no declara dependencia de `cliente`.
- **No hay dependencia oculta cliente->servidor**: analizada explicitamente
  en `cliente/CONTRATO.md` seccion 14 (frontera `COMMAND_REJECTED`); concluye
  sin contradiccion y sin agregar la arista.
- **`editor` no depende de `servidor`/`cliente`/`protocolo-red`**: header
  explicito "Editor V2 NO depende de `servidor`, `cliente` ni
  `protocolo-red`".
- **`integracion` no depende directamente de `modelo-comun`/`protocolo-red`**,
  solo de los cuatro contratos que los consumen (servidor/cliente/editor/
  assets), tal como exige la regla "no agregar dependencia normativa solo
  porque el contrato consumido usa otro contrato internamente".
- **`qa` depende de los siete contratos publicados**, sin depender de ningun
  contrato futuro no publicado (Authentication/Application Session, Map/World
  Rules, etc. estan representados como `BLOCKED`, no como dependencia).
- **El grafo es aciclico**: no existe ningun ciclo de dependencia entre los
  ocho contratos.

Esto coincide con el grafo textual de `CARRILES.md` ("No existe arista
`servidor -> cliente` ni `cliente -> servidor`"), que no fue modificado en
esta revision.

## 4. Checklist del gate de Phase 1 (MASTER_PLAN.md)

| Item requerido | Evidencia | Estado |
|---|---|---|
| Identidad canonica estable + aliases de origen | `modelo-comun` seccion 1-2 (`CanonicalDomainId`, `DomainIdentityV2`, `SourceAliasV2`) | OK |
| Coordenadas Tibia / chunks / pisos | `modelo-comun` seccion 3 (`PosicionTibiaV2`, chunking piso-matematico con coordenadas negativas) | OK |
| Logical footprints | `modelo-comun` seccion 5 (`LogicalFootprintV1`) | OK |
| Entidades | `modelo-comun` seccion 6 (`RuntimeInstanceRefV2`, `EntityDefinitionCoreV2`, `AuthoritativeEntityStateV2`) | OK |
| Comandos | `modelo-comun` seccion 7 (`CommandEnvelopeV2`, `MOVE`) | OK |
| Eventos autoritativos | `modelo-comun` seccion 8 (`AuthoritativeEventEnvelopeV2`) | OK |
| Fronteras de ownership | `modelo-comun` seccion 9 (`OwnershipClassV2`) + tablas de ownership en cada contrato | OK |
| Schemas de replicacion | `modelo-comun` seccion 8A (cuatro payloads neutrales, D-011) | OK |
| Framing/negociacion de protocolo | `protocolo-red` capas 1-3, handshake, seccion 1.3 negociacion exacta | OK |
| Frontera de import/publicacion de Assets | `assets` secciones 1-16 (pipeline, gates `NORMALIZED_DOMAIN`) | OK |
| Frontera de autoridad del servidor | `servidor` secciones 1-15 (lifecycle, `SessionBindingV2`, pipeline) | OK |
| Frontera de replica/presentacion del cliente | `cliente` secciones 2-9 | OK |
| Frontera de autoria del editor | `editor` secciones 1-12 | OK |
| Frontera de configuracion/integracion | `integracion` secciones 1-13 | OK |
| Taxonomia/trazabilidad de QA | `qa` secciones 1-5 | OK, con defecto de conteo (seccion 6 de este documento) |
| Versionado | cada contrato declara SemVer explicito y regla patch/minor/major | OK |
| Errores de validacion | cada contrato define su `*ErrorV2`/tabla de codigos | OK |
| Reglas de migracion | cada contrato V2 tiene seccion de migracion desde su version anterior | OK |
| Limites de persistencia | `servidor` seccion 15, `modelo-comun` seccion 10 | OK |
| Separacion dominio/gameplay vs metadata visual | verificado explicitamente en seccion 7 de este documento (busqueda de campos visuales) | OK |

**Resultado del checklist: todos los items del gate estan satisfechos por
evidencia de contrato.**

## 5. Invariantes cruzados auditados

| # | Invariante | Verificacion | Resultado |
|---|---|---|---|
| 1 | `CanonicalDomainId` != server_id/client_id/looktype/filename/GLB | excluido explicitamente en modelo-comun, assets, servidor, cliente, editor | OK |
| 2 | `RuntimeInstanceRefV2` es identidad runtime scope-local, nunca persistente | modelo-comun seccion 6, servidor seccion 5, cliente seccion 4 | OK |
| 3 | Cadena de scope: servidor activo == `SERVER_WELCOME.runtime_scope_id` == `RuntimeInstanceRefV2.scope_id` replicado == scope aceptado por cliente | servidor seccion 5, protocolo-red handshake, cliente seccion 4 (`XCUT-SCOPE-001` en qa) | OK |
| 4 | `ProtocolConnectionStateV2.READY` != `ServerLifecycleStateV2.READY` != `SessionBindingV2.AUTHORIZED` != `ClientWorldPhaseV2.ACTIVE` | las cuatro maquinas estan definidas por separado, con prosa explicita negando cada implicacion cruzada (D-011, servidor seccion 4/7, cliente seccion 2) | OK |
| 5 | Autoridad: servidor decide, cliente propone, editor autora, integracion ensambla, QA valida | roles declarados explicitamente en cada contrato seccion 0/1 | OK |
| 6 | Ownership de replicacion: modelo-comun forma, servidor produce, protocolo transporta, cliente consume | modelo-comun 8A, servidor secciones 10-11, protocolo-red seccion "Registro neutral", cliente secciones 6-7 | OK |
| 7 | `COMMAND_REJECTED` permanece servidor-owned; cliente no gana dependencia oculta | servidor seccion 10 (`tvp3d.server.command_rejected/2.0.0` sin cambios); cliente seccion 14 analiza la frontera sin importar `servidor` | OK |
| 8 | `CORE_ENTITY_STATE`: forma en modelo-comun, generacion/replication-set en servidor, envelope en protocolo-red, aplicacion atomica en cliente | modelo-comun 8A, servidor seccion 11, protocolo-red "SNAPSHOT", cliente secciones 5-6 | OK |
| 9 | `LogicalFootprint` != dimensiones GLB/AABB/collider/escala visual | ver seccion 7 de este documento (busqueda de campos visuales); ningun payload autoritativo contiene esos campos | OK |
| 10 | Definiciones autoritativas del servidor exigen `NORMALIZED_DOMAIN`/`RESOLVED`; OTBM/OTB/DAT/SPR/`servidor/data/` no son API runtime final | servidor seccion 3 ("Entradas rechazadas"), assets seccion 16 (gates), integracion seccion 9 | OK |
| 11 | Identidad de proyecto de editor != path; target canonico != itemId; guardar != publicacion autoritativa | editor secciones 2, 5, 12 | OK |
| 12 | `NATIVE_V2` es runtime final; `LEGACY_TVP_772` es solo parity/migration; sin fallback nativo->legacy; contenido de clave privada comprometida no es dependencia V2 | integracion secciones 2, 3, 21 | OK |
| 13 | `BLOCKED` != `PASS`; `NOT_RUN` != `PASS`; paridad legacy != certificacion nativa | qa secciones 6, 17, 21 | OK |

**Resultado: los 13 invariantes cruzados se verifican sin contradiccion.**

## 6. Defecto encontrado: conteo de obligaciones QA no reproducible

`qa/CONTRATO.md` seccion 5 afirma **194** obligaciones de fixture
especificadas. Esta revision reprodujo el conteo directamente desde cada
contrato fuente y encontro una discrepancia:

| Contrato | Conteo publicado en `qa` 2.0.0 | Conteo verificado en esta revision | Metodo de verificacion |
|---|---:|---:|---|
| `modelo-comun` | 41 | **42** | ids unicos con forma `` `PREFIJO-TEMA-NNN` `` en la tabla de fixtures |
| `protocolo-red` | 20 | 20 | 10 bullets de prosa (2.0.0) + 10 ids `NEGOTIATE-*` (2.1.0) |
| `assets` | 12 | **13** | bullets de prosa en la seccion 18 |
| `servidor` | 35 | **37** | 23 bullets de la seccion 16 + 14 bullets de "Fixtures agregados en Phase 1D.4" |
| `cliente` | 26 | 26 | ids unicos `CLIENT-*` |
| `editor` | 21 | 21 | ids unicos `EDITOR-*` |
| `integracion` | 39 | 39 | ids unicos `INTEGRATION-*` |
| **Total** | **194** | **198** | suma de la columna verificada |

**Severidad:** BAJA/MEDIA. Es un error aritmetico de conteo dentro de la
propia tabla de cobertura de `qa` 2.0.0 (seccion 5), no una contradiccion de
autoridad, identidad, ownership ni de grafo de dependencias entre contratos.
La metodologia (mapear cada obligacion ya publicada por el contrato fuente a
un `case_id` de QA) es correcta y reproducible, como demuestra esta misma
revision al recalcularla de forma independiente; solo la ejecucion aritmetica
del total en `qa/CONTRATO.md` es incorrecta.

**Por que esto NO bloquea el gate de Phase 1:**

- no crea ni implica una prueba materializada falsa: la cifra correcta
  tambien es "0 materializadas", igual que la publicada;
- no afecta la semantica de ningun otro contrato ni ningun invariante
  cruzado de la seccion 5;
- no viola ninguna regla de autoridad, secretos, versionado ni ownership;
- la pregunta relevante de Phase 1 es si las obligaciones estan
  inventariadas y son trazables, no si la suma esta perfectamente calculada;
  esta revision confirma que SI son trazables (se pudieron recalcular una por
  una desde cada contrato fuente).

**Correccion requerida:** un turno de patch en el carril `qa` (por ejemplo
`qa 2.0.1`) debe corregir la tabla de la seccion 5 a los conteos verificados
de esta tabla (total **198**) antes de que Phase 2 trate esas cifras como
definitivas. Este documento no aplica esa correccion: no se modifica
`worklog/qa/CONTRATO.md` en este turno de orquestacion.

## 7. Busqueda de contradicciones (negativa salvo lo anterior)

Se buscaron activamente, sin encontrarlas:

- un schema con dos dueños simultaneos (los cuatro payloads de replicacion
  fueron migrados explicitamente de `servidor` a `modelo-comun`, con la forma
  `servidor`-owned preservada solo como `HISTORICAL/SUPERSEDED`, nunca
  normativa dos veces);
- identidad autoritativa duplicada;
- versiones de dependencia no coincidentes entre lo declarado y lo publicado
  (verificado en la seccion 2);
- texto normativo v1 por encima de secciones V2 (cada contrato marca su
  material 1.x bajo un heading `HISTORICAL / SUPERSEDED` explicito, despues
  de las secciones normativas V2);
- discrepancia common 2.0 vs 2.1: `servidor.accepted_common_domain_versions`,
  `cliente.common_domain_offer` e `integracion` perfil `NATIVE_V2` coinciden
  exactamente en `["2.1.0"]`;
- version de `IntegrationProfile` desactualizada tras el erratum 2.0.1: `qa`
  depende de `integracion 2.0.1` (no `2.0.0`) en su header;
- puerto/ruta legacy descrito como invariante de arquitectura: `integracion`
  seccion 6 declara explicitamente `127.0.0.1:7277` como default de
  configuracion, no invariante de protocolo;
- campos visuales dentro de un payload autoritativo: busqueda dirigida (ver
  comando abajo) solo encontro menciones de exclusion explicita o contenido
  bajo secciones `HISTORICAL`, nunca dentro de un schema normativo V2;
- servidor consumiendo identidades Assets no resueltas: `servidor` seccion 3
  rechaza explicitamente `UNRESOLVED`/`AMBIGUOUS` como entrada autoritativa;
- cliente aplicando snapshots parciales: `cliente` seccion 6 exige staging
  atomico completo, cero aplicacion parcial;
- editor promoviendo categoria de tile legacy a regla de mundo autoritativa:
  `editor` seccion 4 declara `LEGACY_TILE_CATEGORY_ANNOTATION` como
  editor-owned, nunca exportable como `NORMALIZED_DOMAIN`;
- protocolo otorgando autorizacion via `READY`: negado explicitamente en
  `protocolo-red`, `servidor` y `cliente` por igual;
- alguna afirmacion de que TVP/TFS es runtime final: no encontrada; toda
  mencion es lo opuesto (oracle/parity/migration explicito);
- alguna afirmacion de que un GLB/AABB controla footprint de gameplay: no
  encontrada; `LogicalFootprintV1` se declara independiente en cada contrato
  que lo referencia.

La unica discrepancia real encontrada es la de la seccion 6 (conteo QA).

## 8. Frontera de secretos/seguridad

- Ningun contrato V2 requiere un valor de secreto versionado; todos exigen
  referencia por nombre de variable de entorno.
- `integracion 2.0.1` supera explicitamente la politica 1.x de versionar
  `servidor/key.pem` como secreto de desarrollo aceptable, sin borrar ni
  rotar el archivo (fuera de alcance de un turno contract-only).
- Esta revision **no abrio, imprimio ni inspecciono** el contenido de
  `servidor/key.pem`; solo se evaluo la politica documentada. Su existencia
  fisica es deuda operativa separada, ya registrada como tal.
- No se encontro ningun valor con forma de secreto real en ningun contrato;
  la unica coincidencia de patron fue la descripcion normativa de que forma
  tiene un secreto para poder rechazarlo (`integracion/CONTRATO.md`, politica
  de secretos).

## 9. Ejes de version verificados como no colapsados

| Eje | Valor verificado |
|---|---|
| Version de contrato `protocolo-red` | `2.1.0` |
| Version de frame binario nativo | `protocol_major=2`, `protocol_minor=0` (sin cambio) |
| Common domain negociado por el perfil nativo | `2.1.0` |
| Version de los payloads de replicacion neutrales | `1.0.0` (identidad de schema nueva, independiente del contrato contenedor) |
| Version de publicacion Assets | `2.0.0` |
| Version de proyecto de editor | `tvp3d.editor.project/2.0.0` |
| Version de perfil de integracion | `tvp3d.integration.profile/2.0.1` |
| Version de caso/reporte QA | `tvp3d.qa.case/2.0.0` / `tvp3d.qa.report/2.0.0` |

Confirmado explicitamente: `protocolo-red` contrato `2.1.0` NO implica frame
minor `1`. El frame nativo permanece `major=2, minor=0` en todo momento;
`2.1.0` solo describe la capacidad de negociacion de common domain, un eje de
version totalmente distinto.

## 10. Estado `HISTORICAL / SUPERSEDED` (preservado, no normativo)

Verificado presente y no-normativo en los ocho contratos:

- Protocol 1.x (`protocolo-red`);
- Server 1.1.0 (`servidor`), incluidos los cuatro schemas
  `tvp3d.server.*` de replicacion (ahora bajo su propio heading
  `HISTORICAL / SUPERSEDED: schemas server-owned de replicacion`);
- Client 1.30.0 / TVP 7.72 (`cliente`);
- Editor 1.0.0 (`editor`);
- Integration 1.0.0 (`integracion`), incluida la forma erratica de
  `tvp3d.integration.profile/2.0.0` (documentada en la seccion 27 de
  `integracion/CONTRATO.md` como `SUPERSEDED POR ERRATUM`);
- QA 1.4.0 (`qa`), con cada seccion reclasificada `LEGACY_PARITY` o
  `LEGACY_LIVE_MUTATING`.

Ninguna seccion `HISTORICAL` contiene una palabra normativa (`DEBE`/`NO
DEBE`/`SOLO`) que gobierne el contrato vigente; todas estan explicitamente
marcadas `SUPERSEDED`.

## 11. Dominios especializados faltantes (downstream intencional)

| Dominio | Clasificacion |
|---|---|
| Authentication / Application Session | downstream especializado, bloquea `FULL_NATIVE_PLAYABLE` |
| Map / World Rules | downstream especializado, bloquea `MOVE` autoritativo y `FULL_NATIVE_PLAYABLE` |
| Combat | downstream especializado |
| Items / Inventory | downstream especializado |
| Monster / Spawn Domain | downstream especializado (Phase 5 del roadmap) |
| Quests / Houses | downstream especializado |
| Command Outcome neutral | downstream especializado (mejora UX de rechazo, no bloquea correctitud base) |
| Visual / Monster3D final | downstream especializado (Phase 6 del roadmap) |

**Ninguno de estos es requisito del gate fundacional de Phase 1.**
`MASTER_PLAN.md` los ubica explicitamente en Phase 5 (Monster Domain), Phase
6 (Monster3D) o como contratos de dominio de gameplay posteriores a Phase 3;
Phase 1 solo exige la base comun (identidad, coordenadas, footprint,
entidades, comandos, eventos, ownership, replicacion, framing, boundaries de
assets/servidor/cliente/editor/integracion, taxonomia QA, versionado, errores,
migracion, limites de persistencia y separacion dominio/visual), que esta
satisfecha segun la seccion 4.

## 12. Confirmacion del gate Monster/Cyclops

- Monster Domain: NO publicado (`docs/tibia3d/MONSTER_CONTRACT_PLAN.md`
  sigue en estado "PROPUESTA DE PHASE 0; NO ES UN CONTRATO PUBLICADO").
- Monster3D: NO publicado.
- Cyclops: NO autorizado; toda mencion en los contratos vigentes es
  "sigue/siguen fuera de alcance".
- Los archivos sucios/no versionados relacionados con Cyclops/Monster3D en el
  worktree (`cliente3d/mundo3d.gd`, `cliente3d/propio/monstruos3d/*`,
  `generated/bestiario_referencias/`, `generated/referencias_monstruos/`,
  `herramientas/extraer_referencias_faltantes.py`,
  `worklog/cliente/preview-*.png`) son deuda de worktree de otro turno/agente,
  no autoridad de contrato Architecture V2. Esta revision no los toco ni los
  interpreto como parte del contrato.

## 13. Estado de implementacion vs estado de contrato (no confundir)

| Carril | Estado de contrato | Estado de implementacion (`STATE.md`) |
|---|---|---|
| `modelo-comun` | `PUBLICADO` 2.1.0 | `LISTO_PARA_REVISION` (documental, sin codigo de produccion en este alcance) |
| `protocolo-red` | `PUBLICADO` 2.1.0 | `LISTO_PARA_REVISION` |
| `assets` | `PUBLICADO` 2.0.0 | `LISTO_PARA_REVISION`; manifests/resolver/validators de V2 pendientes de implementar |
| `servidor` | `PUBLICADO` 2.1.0 | `LISTO_PARA_REVISION`; runtime Godot headless V2 no implementado todavia contra este contrato |
| `cliente` | `PUBLICADO` 2.0.0 | `LISTO_PARA_REVISION`; store de replica/fase de mundo nativos no implementados todavia |
| `editor` | `PUBLICADO` 2.0.0 | `LISTO_PARA_REVISION`; formato v2 no implementado en la app Godot todavia |
| `integracion` | `PUBLICADO` 2.0.1 | `LISTO_PARA_REVISION`; perfiles nativos no implementados en `.bat`/scripts todavia |
| `qa` | `PUBLICADO` 2.0.0 | `LISTO_PARA_REVISION`; 198 obligaciones especificadas (corregido, ver seccion 6), 0 materializadas |

**Ningun carril se declara `HECHO` por este cierre.** El cierre de Phase 1
certifica la coherencia del contrato, no la finalizacion de la
implementacion.

## 14. Veredicto

### A. Veredicto de congelamiento de contrato — Phase 1

# **PASS**

El gate fundacional de Phase 1 (`MASTER_PLAN.md`) esta satisfecho: los ocho
contratos estan publicados, sus versiones coinciden con lo verificado en
archivo, el grafo de dependencias es aciclico y respeta las reglas de
`CARRILES.md`, los 13 invariantes cruzados auditados no presentan
contradiccion, ninguna seccion `HISTORICAL` gobierna el contrato vigente,
Monster Domain/Monster3D/Cyclops permanecen sin publicar/autorizar, y no se
requiere ningun valor de secreto versionado. El unico defecto encontrado
(seccion 6, conteo QA) es una correccion aritmetica localizada en un solo
contrato, no una contradiccion fundacional, y no invalida la trazabilidad que
Phase 1 exige.

### B. Estado de preparacion de implementacion

```text
CONTRACT FOUNDATION: FROZEN (Phase 1 gate PASSED)
IMPLEMENTATION STATUS: NOT COMPLETE (todos los carriles en LISTO_PARA_REVISION
                        documental; 0 fixtures QA materializadas)
FULL_NATIVE_PLAYABLE: BLOCKED (Authentication/Application Session,
                        Map/World Rules, y otros dominios pendientes)
LEGACY ORACLE: TVP/TFS permanece parity/migration, no runtime final
```

No se afirma en ningun lugar de este documento que el gameplay nativo este
completo, que un carril de implementacion sea `HECHO`, ni que las 198
obligaciones QA esten materializadas.

## 15. Proxima fase exacta

**Phase 2 — build parity fixtures against TVP.** Objetivo exacto segun
`MASTER_PLAN.md`: convertir el comportamiento legacy observable en fixtures
de oracle reproducibles (clasificacion `LEGACY_PARITY`, schema
`ParityFixtureV2` ya publicado por `qa 2.0.0` seccion 16), con harness de
comparacion deterministico y politica para clasificar diferencias como bug,
deuda o cambio deliberado. Phase 2 NO implementa el servidor Godot nativo
(eso es Phase 3) ni gameplay.

**Primera tarea recomendada de Phase 2 (recomendacion, NO iniciada en este
turno):** que el carril `qa` abra un turno para (a) corregir el conteo de la
seccion 5 de su propio contrato (defecto de la seccion 6 de este documento,
posiblemente `qa 2.0.1`) y (b) materializar el primer lote de fixtures
`ParityFixtureV2` sobre el dominio ya mejor evidenciado en el historial legacy
(muerte/corpse/loot, que ya tiene evidencia viva documentada en
`docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`), como piloto reproducible antes de
escalar al resto del corpus de paridad.

## 16. Deuda de documentacion observada (no corregida en este turno)

`CARRILES.md` lineas 252-261 todavia describe "El siguiente turno
contractual obligatorio es `modelo-comun 2.1.0`" y un "Gate vigente...
solo entonces puede publicarse Client V2" como si fueran obligaciones
futuras. Ambas ya se cumplieron (ver seccion 2 de este documento). El grafo
de dependencias y las reglas de ownership de `CARRILES.md` siguen siendo
correctos y no se modificaron; solo ese parrafo narrativo quedo desactualizado
en el tiempo. No se edito `CARRILES.md` en este turno de orquestacion porque
la gobernanza de este turno restringe esa edicion a una contradiccion real
que exija resolucion inmediata, y el grafo/las reglas tecnicas siguen siendo
correctas; se deja como recomendacion para un turno de mantenimiento de
`orquestacion` explicitamente dedicado a `CARRILES.md`.
