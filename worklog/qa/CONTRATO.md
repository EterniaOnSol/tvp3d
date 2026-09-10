# Contrato: qa

Version: 2.0.0
Estado: PUBLICADO
Propietario: qa
Depende de: modelo-comun 2.1.0, protocolo-red 2.1.0, assets 2.0.0,
servidor 2.1.0, cliente 2.0.0, editor 2.0.0, integracion 2.0.1

QA V2 depende de TODOS los contratos Architecture V2 publicados hasta ahora,
tal como fija `CARRILES.md`. No depende de ningun contrato futuro no
publicado (Authentication/Application Session, Map/World Rules, Combat,
Item/Inventory, Monster/Spawn Domain, Command Outcome neutral, visual/
Monster3D final); su ausencia se representa explicitamente como BLOQUEO
(seccion 12), nunca como dependencia normativa inventada.

Esta es una revision **major** deliberada. QA 1.4.0 trata el servidor TVP
7.72 en vivo como oracle/runtime primario, usa paquetes/ids legacy y pruebas
Docker-orientadas como certificacion central. QA V2 reclasifica todo eso como
`LEGACY / PARITY / HISTORICAL EVIDENCE`, nunca aceptacion del runtime nativo.
Ningun significado de 1.4.0 se reinterpreta en silencio; se preserva integro
bajo `HISTORICAL / SUPERSEDED` mas abajo.

## 0. Proposito y alcance normativo (QA V2)

QA V2 congela como se prueban los contratos Architecture V2 antes de que
Phase 1 se declare cerrada. QA valida semantica ya publicada; NO:

- inventa campos faltantes;
- reinterpreta un payload;
- define caminabilidad, autorizacion, comportamiento de monstruo, estandares
  visuales o defaults de integracion;
- parchea un contrato escribiendo en QA el valor que "deberia" tener.

Si un contrato es contradictorio o ambiguo, QA reporta `QA_CONTRACT_DEFECT`
(seccion 18); no elige que lado tiene razon.

Este turno es contract-only: no se implementan pruebas ejecutables, no se
modifica `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni ningun otro carril, no se
arranca Docker y no se ejecuta ninguna prueba viva mutante. Las palabras
`DEBE`, `NO DEBE`, `PUEDE` y `SOLO` son normativas en las secciones 0-23; el
contenido bajo `HISTORICAL / SUPERSEDED` no es normativo para V2.

## 1. Clasificacion de pruebas (`TestClassV2`)

Enum cerrado, sin una quinta categoria ambigua:

```text
CONTRACT_FIXTURE
NATIVE_INTEGRATION
LEGACY_PARITY
LEGACY_LIVE_MUTATING
```

| Clase | Significado exacto |
|---|---|
| `CONTRACT_FIXTURE` | fixture deterministico contra uno o mas contratos V2 publicados. No requiere servidor legacy en vivo. No requiere credenciales ocultas. Puede ser logica pura de schema/validacion/maquina de estados |
| `NATIVE_INTEGRATION` | valida interaccion entre componentes V2 nativos ya implementados. Requiere que la implementacion relevante exista. Puede lanzar procesos Godot. DEBE usar el perfil `NATIVE_V2` de `integracion` |
| `LEGACY_PARITY` | observacion reproducible del comportamiento TVP/TFS usada como oracle de migracion. NO certifica por si sola la implementacion Architecture V2 |
| `LEGACY_LIVE_MUTATING` | prueba viva que cambia estado de servidor/persistencia/cuenta/mundo legacy. Explicita, aislada, nunca parte de la suite local deterministica por defecto |

Estas categorias NO se mezclan: una prueba declara exactamente una clase.

## 2. Relacion con el roadmap

| Fase | Responsabilidad de QA |
|---|---|
| Phase 1 (este turno) | publicar contrato/taxonomia QA V2 y el inventario de obligaciones de prueba |
| Phase 2 | materializar fixtures `LEGACY_PARITY` reproducibles contra TVP |
| Phase 3+ | cada slice de implementacion nativa debe satisfacer sus casos `CONTRACT_FIXTURE`/`NATIVE_INTEGRATION` relevantes |

Este turno NO materializa el corpus completo de paridad de Phase 2; solo
define su forma/boundary (seccion 16).

## 3. `QACaseV2`

Identificador de schema: `tvp3d.qa.case`, version `2.0.0`.

```json
{
  "schema": "tvp3d.qa.case",
  "version": "2.0.0",
  "case_id": "COMMON-REPL-SPAWN-001",
  "class": "CONTRACT_FIXTURE",
  "title": "ENTITY_SPAWNED neutral payload begins at revision 0",
  "owners": ["qa"],
  "contracts": [
    {"contract": "modelo-comun", "version": "2.1.0"}
  ],
  "requirement_refs": [
    {
      "contract": "modelo-comun",
      "version": "2.1.0",
      "section": "8A",
      "source_fixture_id": "REPL-SPAWN-VALID-001"
    }
  ],
  "preconditions": [],
  "input_fixture": {
    "logical_path": "qa/fixtures/modelo-comun/2.1.0/repl-spawn-valid-001.json"
  },
  "expected": {
    "outcome": "ACCEPT",
    "notes": "state.revision == \"0\"; envelope.subject == state.runtime_id"
  },
  "mutates_external_state": false,
  "requires_network": false,
  "requires_legacy": false,
  "requires_secrets": false,
  "status_policy": {
    "missing_prerequisite_status": "BLOCKED",
    "assertion_mismatch_status": "FAIL"
  }
}
```

| Campo | Regla |
|---|---|
| `case_id` | grammar cerrada (seccion 3.1); estable, nunca aleatorio, nunca reasignado a otro caso |
| `class` | `TestClassV2` (seccion 1) |
| `title` | UTF-8 1..160 bytes |
| `owners` | `1..8` registry_token; por defecto `["qa"]` |
| `contracts` | `1..8` `{contract, version}`; la version DEBE coincidir exactamente con la version del contrato realmente cargado/ejecutado (nunca `"latest"`) |
| `requirement_refs` | `1..16` `{contract, version, section, source_fixture_id}`; `source_fixture_id` es `null` cuando el contrato origen solo publico una obligacion en prosa sin id |
| `preconditions` | `0..16` strings; estado que debe existir antes de ejecutar |
| `input_fixture` | objeto inline o `{logical_path}` a un fixture versionado; QA no inventa un valor de entrada que el contrato origen no publico |
| `expected` | objeto; debe reflejar exactamente el "Resultado obligatorio" del contrato origen, no una reinterpretacion |
| `mutates_external_state` | boolean; `true` SOLO permitido cuando `class=LEGACY_LIVE_MUTATING` |
| `requires_network`, `requires_legacy`, `requires_secrets` | booleans |
| `status_policy` | declara que falta de prerequisito produce `BLOCKED` y que discrepancia de aserciones produce `FAIL` para este caso especifico |

Si `requires_secrets=true`, el caso DEBE declarar
`secret_env_refs: [nombre_de_variable, ...]`; nunca un valor.

### 3.1 Grammar de `case_id`

```text
<PREFIJO>-<TEMA>-<NNN>
```

`PREFIJO` es uno de un registro cerrado que identifica el namespace de QA
(no necesariamente el id que el contrato origen ya publico):

```text
COMMON        (modelo-comun)
PROTOCOL      (protocolo-red)
ASSETS        (assets)
SERVER        (servidor)
CLIENT        (cliente)
EDITOR        (editor)
INTEGRATION   (integracion)
XCUT          (invariante cruzado entre contratos, seccion 11)
NATIVE        (suite NATIVE_SMOKE_V2, seccion 10)
PARITY        (fixture LEGACY_PARITY, seccion 16)
```

`TEMA` es `[A-Z0-9]+(-[A-Z0-9]+)*` y `NNN` es `000..999` con ceros a la
izquierda. NO se usa UUID aleatorio como identidad de caso: `case_id` debe
poder citarse en texto y repetirse igual en cada ejecucion.

Un `case_id` de QA es una identidad DISTINTA del `source_fixture_id` que el
contrato origen ya publico (por ejemplo `REPL-SPAWN-VALID-001` en
modelo-comun); `requirement_refs[].source_fixture_id` es el puente exacto
entre ambos. QA no renombra el fixture del contrato origen; solo indexa su
propia obligacion de materializarlo/ejecutarlo.

### 3.2 Referencia de contrato

```json
{"contract": "modelo-comun", "version": "2.1.0", "section": "8A"}
```

Un resultado de prueba es invalido si la version del contrato que afirma
probar difiere de la version realmente cargada/ejecutada. No existe
dependencia implicita a "la ultima version".

## 4. Trazabilidad de requisitos

Regla obligatoria: toda obligacion de fixture/test normativa publicada por
cada contrato V2 DEBE mapear a al menos un `case_id` de QA antes de poder
considerarse `COVERED`. Un requisito sin `case_id` asociado permanece
`SPECIFIED_NOT_MATERIALIZED` para siempre, nunca `COVERED` por omision.

Estados cerrados de cobertura:

```text
SPECIFIED_NOT_MATERIALIZED
MATERIALIZED
BLOCKED
```

| Estado | Significado |
|---|---|
| `SPECIFIED_NOT_MATERIALIZED` | el contrato origen publico la obligacion; QA aun no le asigno `case_id` ejecutable con fixture real |
| `MATERIALIZED` | existe un `QACaseV2` real cuyos `input_fixture`/`expected`/`contracts` coinciden exactamente con la version del contrato vigente, y fue ejecutado con resultado `PASS` o `FAIL` registrado en un `QAReportV2` |
| `BLOCKED` | no puede materializarse todavia porque depende de una implementacion o contrato ausente (seccion 12) |

Una prueba legacy parecida NO promueve automaticamente un requisito a
`MATERIALIZED` (seccion 4.1).

### 4.1 No se reclaman pruebas materializadas por parecido

Si una prueba legacy existente se parece a un fixture V2:

- NO se marca automaticamente `MATERIALIZED`;
- solo cuenta si sus entradas, salidas y afirmaciones de version de contrato
  coinciden realmente con el contrato V2 nuevo;
- el exito historico es evidencia, nunca certificacion V2 automatica.

## 5. Matriz de cobertura por contrato

Inventario de obligaciones publicadas, reconstruido leyendo cada contrato
vigente en este turno. Ningun numero de esta tabla fue inventado: son las
obligaciones de fixture ya publicadas por cada contrato.

| Contrato | Version | Obligaciones publicadas | Namespace QA | Estado actual |
|---|---|---:|---|---|
| `modelo-comun` | `2.1.0` | 41 (ids `ID-*`, `ALIAS-*`, `POSITION-*`, `CHUNK-*`, `DIRECTION-*`, `FOOTPRINT-*`, `RUNTIME-ID-*`, `COMMAND-*`, `EVENT-*`, `OWNERSHIP-*`, `VERSION-*`, `REPL-*`) | `COMMON-*` | `SPECIFIED_NOT_MATERIALIZED` |
| `protocolo-red` | `2.1.0` | 20 (10 obligaciones en prosa de framing/handshake/sync 2.0.0 + 10 ids `NEGOTIATE-*` de negociacion 2.1.0) | `PROTOCOL-*` | `SPECIFIED_NOT_MATERIALIZED` |
| `assets` | `2.0.0` | 12 (obligaciones en prosa, seccion 18) | `ASSETS-*` | `SPECIFIED_NOT_MATERIALIZED` |
| `servidor` | `2.1.0` | 35 (21 obligaciones en prosa base + 14 agregadas en la alineacion 2.1.0, seccion 16) | `SERVER-*` | `SPECIFIED_NOT_MATERIALIZED` |
| `cliente` | `2.0.0` | 26 (ids `CLIENT-*`, seccion 22) | `CLIENT-*` | `SPECIFIED_NOT_MATERIALIZED` |
| `editor` | `2.0.0` | 21 (ids `EDITOR-*`, seccion 21) | `EDITOR-*` | `SPECIFIED_NOT_MATERIALIZED` |
| `integracion` | `2.0.1` | 39 (ids `INTEGRATION-*`, seccion 23, incluida la subseccion del erratum) | `INTEGRATION-*` | `SPECIFIED_NOT_MATERIALIZED` |

**Total de obligaciones especificadas: 194. Total materializadas en este
turno: 0.** Este contrato inventaria y clasifica; no ejecuta. Las
obligaciones en prosa (assets, servidor, protocolo-red 2.0.0 base) requieren
que QA les asigne `case_id` propio (prefijo `ASSETS-`/`SERVER-`/`PROTOCOL-`)
antes de poder materializarse, porque el contrato origen no las enumero con
un id individual.

## 6. Estado de resultado (`QAResultStatusV2`)

Enum cerrado:

```text
PASS
FAIL
BLOCKED
NOT_RUN
```

| Estado | Significado exacto |
|---|---|
| `PASS` | el caso se ejecuto contra las versiones declaradas y todas las aserciones normativas pasaron |
| `FAIL` | el caso se ejecuto y al menos una asercion normativa fallo |
| `BLOCKED` | el caso no pudo ejecutarse validamente porque un prerequisito explicito esta ausente/no disponible |
| `NOT_RUN` | el caso no fue solicitado/ejecutado |

`BLOCKED != PASS`. `NOT_RUN != PASS`. Un reporte NUNCA cuenta `BLOCKED` o
`NOT_RUN` como verde.

## 7. `QAReportV2`

Identificador de schema: `tvp3d.qa.report`, version `2.0.0`.

```json
{
  "schema": "tvp3d.qa.report",
  "version": "2.0.0",
  "suite_id": "CONTRACT_V2",
  "profile": "NATIVE_V2",
  "contract_versions": [
    {"contract": "modelo-comun", "version": "2.1.0"},
    {"contract": "protocolo-red", "version": "2.1.0"},
    {"contract": "assets", "version": "2.0.0"},
    {"contract": "servidor", "version": "2.1.0"},
    {"contract": "cliente", "version": "2.0.0"},
    {"contract": "editor", "version": "2.0.0"},
    {"contract": "integracion", "version": "2.0.1"}
  ],
  "cases": [
    {
      "case_id": "COMMON-REPL-SPAWN-001",
      "status": "NOT_RUN",
      "assertions_total": 0,
      "assertions_passed": 0,
      "error_code": null,
      "evidence": [],
      "blockers": ["case not yet materialized"]
    }
  ],
  "summary": {
    "total": 1,
    "pass": 0,
    "fail": 0,
    "blocked": 0,
    "not_run": 1
  }
}
```

| Campo | Regla |
|---|---|
| `suite_id` | `SuiteProfileV2` (seccion 10) |
| `profile` | `NATIVE_V2` o `LEGACY_TVP_772` segun `integracion` 2.0.1, o `null` si no aplica |
| `contract_versions` | lista exacta de versiones realmente cargadas |
| `cases[].status` | `QAResultStatusV2` |
| `cases[].error_code` | `null` o codigo exacto (owner original si viene de otro contrato, seccion 18) |
| `cases[].evidence` | referencias logicas (`logical_path`, `content_id`), nunca rutas absolutas |
| `cases[].blockers` | `0..N` strings; obligatorio no vacio si `status=BLOCKED` |
| `summary` | conteos consistentes con `cases[]`; `pass+fail+blocked+not_run == total` |

El reporte NUNCA contiene contrasenas, tokens, material de clave privada ni
secretos de cuenta. No requiere username de maquina ni paths absolutos
locales.

## 8. Evidencia deterministica vs metadata de runtime

Superficie de comparacion deterministica permitida:

versiones de schema, `case_id`, hashes, paths relativos/logicos, valores
esperados/observados normalizados, estado de resultado.

Prohibido en la superficie deterministica:

hostname de maquina, username, PID, timestamp de reloj de pared, ids
aleatorios.

Si una ejecucion en vivo necesita timestamps/duraciones para depuracion,
esos campos se clasifican como diagnostico de runtime NO canonico, fuera de
la superficie de comparacion deterministica de `QAReportV2`.

## 9. Codigos de salida de la suite

```text
0   todos los casos REQUIRED seleccionados PASS
1   uno o mas casos REQUIRED seleccionados FAIL
2   ningun FAIL, pero uno o mas casos REQUIRED seleccionados BLOCKED
3   el harness/reporte/configuracion de QA en si mismo es invalido
```

Un caso `REQUIRED` en `NOT_RUN` impide el codigo `0` cuando formaba parte de
la suite requerida seleccionada. Ningun runner puede devolver `0` solo
porque las pruebas que fallarian fueron omitidas.

## 10. Perfiles de suite (`SuiteProfileV2`)

Enum cerrado:

```text
CONTRACT_V2
NATIVE_SMOKE_V2
PARITY_TVP_772
LEGACY_LIVE_MANUAL
```

| Perfil | Contenido |
|---|---|
| `CONTRACT_V2` | solo fixtures de contrato/schema (`CONTRACT_FIXTURE`) |
| `NATIVE_SMOKE_V2` | verificaciones de proceso/protocolo/baseline del perfil `NATIVE_V2` de `integracion` 2.0.1 (`NATIVE_INTEGRATION`) |
| `PARITY_TVP_772` | fixtures reproducibles de oracle de Phase 2 (`LEGACY_PARITY`) |
| `LEGACY_LIVE_MANUAL` | certificaciones legacy mutantes/manuales (`LEGACY_LIVE_MUTATING`) |

`LEGACY_LIVE_MANUAL` NUNCA forma parte de la suite local/CI por defecto de
`CONTRACT_V2` ni `NATIVE_SMOKE_V2`.

## 11. Invariantes cruzados entre contratos

Casos con `case_id` estable, cada uno cruza mas de un contrato:

| `case_id` | Invariante |
|---|---|
| `XCUT-SCOPE-001` | `RuntimeInstanceRefV2.scope_id` (modelo-comun) == `SERVER_WELCOME.runtime_scope_id` (protocolo-red) == scope activo del servidor (servidor) == scope del replica store aceptado (cliente) |
| `XCUT-READY-AUTH-001` | Protocol `READY` != `SessionBindingV2 AUTHORIZED` (servidor) != `ClientWorldPhaseV2 ACTIVE` (cliente); los tres son conceptos distintos que nunca se implican entre si |
| `XCUT-FOOTPRINT-VISUAL-001` | `LogicalFootprintV1` (modelo-comun/servidor) != visual bounds/GLB/collider (no existe tal campo en ningun payload autoritativo) |
| `XCUT-CANONICAL-LEGACY-001` | `CanonicalDomainId` != client id/server id/looktype/filename legacy, en modelo-comun, assets, servidor, cliente y editor por igual |
| `XCUT-REPLICATION-CHAIN-001` | el servidor produce el payload neutral de replicacion (servidor), el cliente consume exactamente el mismo schema de modelo-comun (cliente), y protocolo-red solo lo transporta sin redefinirlo |
| `XCUT-COMMONVERSION-001` | `integracion` `NATIVE_V2.server.accepted_common_domain_versions` == perfil de aplicacion nativo de `servidor` (`["2.1.0"]`) == `client.common_domain_offer` de `integracion` == oferta nativa de `cliente` (`["2.1.0"]`) |
| `XCUT-EDITOR-SOURCE-001` | `SourceBindingV2` del editor referencia una publicacion de Assets V2 sin mutar la fuente; el `import_run_id` referenciado debe existir en la publicacion real |
| `XCUT-NOSECRET-001` | ningun perfil V2 (`integracion`) depende del contenido de una clave privada versionada (`servidor/key.pem`); ninguna configuracion V2 de ningun contrato incluye un valor secreto literal |
| `XCUT-LEGACY-ORACLE-001` | TVP/TFS permanece oracle/paridad (assets, servidor, protocolo-red, cliente, integracion); ningun contrato V2 lo declara autoridad de runtime nativo |

## 12. Dominios especializados bloqueados

QA representa explicitamente los contratos que todavia faltan, sin
inventarles pruebas:

| Dominio faltante | Estado | Razon | Bloquea |
|---|---|---|---|
| `AUTHENTICATION_APPLICATION_SESSION` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | actor controlado autorizado (cliente 2.0.0 seccion 12); cualquier `CommandEnvelopeV2` de gameplay legitimo |
| `MAP_WORLD_RULES` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | caminabilidad/ocupacion/pathfinding autoritativos; `MOVE` habilitado en produccion (servidor 2.1.0 seccion 14) |
| `COMBAT` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | dano, condiciones, efectos de combate |
| `ITEM_INVENTORY` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | items dinamicos, contenedores, drops |
| `MONSTER_SPAWN_DOMAIN` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | especies, IA, spawns, loot |
| `COMMAND_OUTCOME_NEUTRAL` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | UX de rechazo enriquecida sin adaptador `servidor` (cliente 2.0.0 seccion 14) |
| `FINAL_VISUAL_MONSTER3D` | `BLOCKED` | `CONTRACT_NOT_PUBLISHED` | mapping final looktype/canonical_id -> asset visual de produccion (editor 2.0.0 seccion 23) |

La ausencia de estos contratos NO invalida los contratos base ya publicados.
SI bloquea `FULL_NATIVE_PLAYABLE` (seccion 13) y cualquier suite que
pretenda certificar esos comportamientos.

## 13. `FULL_NATIVE_PLAYABLE`

Declaracion explicita: **`FULL_NATIVE_PLAYABLE` NO es una suite que pase
hoy.** Permanece `BLOQUEADO` hasta que existan los contratos especializados
requeridos (minimo: `AUTHENTICATION_APPLICATION_SESSION` y
`MAP_WORLD_RULES`, seccion 12) y su implementacion.

QA V2 NO certifica hoy como aceptacion nativa V2:

- exito de movimiento por teclado;
- exito de login;
- exito de combate;
- gameplay de monstruos.

Las pruebas historicas de prototipo (`HISTORICAL / SUPERSEDED` mas abajo) NO
eliminan estos bloqueos; son evidencia de paridad, no certificacion V2.

## 14. Secretos en QA

Fixtures y reportes de QA NO PUEDEN contener literalmente contrasenas,
tokens, claves privadas, credenciales de DB ni credenciales de cuenta. Si un
caso legacy requiere una credencial, DEBE referenciar una variable de
entorno/proveedor de secretos por NOMBRE unicamente (`secret_env_refs`,
seccion 3). Un secreto requerido y ausente para una prueba viva
explicitamente solicitada produce `BLOCKED`, no `FAIL`, salvo que el
contrato de esa suite declare ese secreto como prerequisito obligatorio del
entorno de prueba. Nunca se imprime un valor secreto en salida de fallo.

## 15. Pruebas mutantes (`LEGACY_LIVE_MUTATING`)

Todo caso `LEGACY_LIVE_MUTATING` DEBE declarar `mutates_external_state=true`
y documentar:

- aislamiento requerido (cuenta/personaje/servidor dedicado a pruebas);
- obligaciones de limpieza (que se restaura y cuando);
- que estado persistente puede cambiar;
- que ocurre si la limpieza no puede completarse (queda como bloqueo
  documentado, nunca como aprobacion parcial).

NUNCA forman parte de la suite deterministica por defecto
(`CONTRACT_V2`/`NATIVE_SMOKE_V2`). Este turno NO ejecuta ninguna.

## 16. `ParityFixtureV2` (boundary para Phase 2)

Identificador de schema: `tvp3d.qa.parity_fixture`, version `2.0.0`. Este
turno publica solo la forma; Phase 2 materializa el corpus.

```json
{
  "schema": "tvp3d.qa.parity_fixture",
  "version": "2.0.0",
  "fixture_id": "PARITY-DEATH-001",
  "oracle": "TVP_772",
  "oracle_version": "7.72",
  "source_evidence": {"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"},
  "preconditions": ["personaje fuera de zona de proteccion"],
  "input_action": "un demon invocado ataca hasta HP 0",
  "observed_authoritative_result": "0x6C de mi_id con HP 0 emite muerte; corpse dead human",
  "normalization_rules": ["excluir loot aleatorio del corpse"],
  "determinism_notes": "requiere precondicion de campo reproducible",
  "excluded_nondeterministic_fields": ["loot_contents"],
  "classification": "MATCH_EXPECTED"
}
```

| Campo | Regla |
|---|---|
| `oracle` | `TVP_772` u otro identificador de fuente TFS/TVP segun corresponda |
| `classification` | enum cerrado: `MATCH_EXPECTED\|KNOWN_LEGACY_BUG\|DELIBERATE_V2_DIFFERENCE\|UNRESOLVED` |
| `excluded_nondeterministic_fields` | campos observados que varian entre corridas (por ejemplo loot aleatorio) y quedan fuera de la comparacion |

## 17. La paridad no dicta V2 ciegamente

Un comportamiento de TVP observado en Phase 2 es EVIDENCIA. No es
automaticamente la especificacion V2. Una diferencia se clasifica como:

```text
BUG
DEBT
DELIBERATE_CHANGE
```

segun el roadmap/contrato de dominio propietario decida. QA no puede cambiar
el comportamiento V2 solo para igualar un bug accidental legacy.

## 18. `QAErrorV2`

```json
{
  "schema": "tvp3d.qa.error",
  "version": "2.0.0",
  "code": "QA_CONTRACT_DEFECT",
  "path": null,
  "message": "modelo-comun 2.1.0 section 8A conflicts with servidor 2.1.0 section 10",
  "context": {}
}
```

| Codigo | Significado |
|---|---|
| `QA_CASE_SCHEMA_INVALID` | un `QACaseV2` no valida contra su propio schema |
| `QA_CONTRACT_VERSION_MISMATCH` | la version declarada por el caso difiere de la version realmente cargada |
| `QA_FIXTURE_MISSING` | el `input_fixture` referenciado no existe/no resuelve |
| `QA_EXPECTATION_INVALID` | `expected` no corresponde al "Resultado obligatorio" real del contrato origen |
| `QA_REPORT_INVALID` | un `QAReportV2` no valida contra su propio schema |
| `QA_PREREQUISITE_MISSING` | falta un prerequisito declarado en `preconditions`; produce `BLOCKED` en el caso |
| `QA_SECRET_EXPOSURE` | un valor con forma de secreto aparecio en un fixture/reporte versionado |
| `QA_UNDECLARED_MUTATION` | un caso mutó estado externo sin declarar `mutates_external_state=true` |
| `QA_NONDETERMINISTIC_OUTPUT` | una comparacion deterministica produjo resultados distintos para la misma entrada declarada |
| `QA_CONTRACT_DEFECT` | dos contratos dependientes se contradicen; QA reporta, no arbitra |
| `QA_HARNESS_FAILURE` | el propio harness/runner de QA fallo antes de poder evaluar el caso |

No se duplican codigos de dominio/protocolo/servidor/cliente. Cuando el
sistema bajo prueba emite un error propio de su contrato (por ejemplo
`COMMON_DOMAIN_VERSION_UNSUPPORTED` de protocolo-red), QA afirma exactamente
ese `owner`/`code`; no lo envuelve como `QAError` salvo que el harness en si
mismo haya fallado.

## 19. Veredicto de revision de carril vs reporte QA

Alineado con `.claude/skills/revisar-carril/SKILL.md`: un veredicto `HECHO`
de revision cruzada de un carril exige que su Definicion de Hecho y la
evidencia requerida realmente pasen; no se aprueba porque exista un commit.

`QAReportV2.status=PASS` en los casos materializados y un veredicto `HECHO`
de revision de carril son conceptos RELACIONADOS pero NO IDENTICOS:

- un reporte QA puede tener `PASS` en todos los casos ya materializados y
  aun asi el carril no ser `HECHO`, si quedan obligaciones
  `SPECIFIED_NOT_MATERIALIZED` relevantes, `STATE.md` incompleto, o rutas
  fuera de propiedad tocadas;
- un veredicto `HECHO` de revision de carril requiere ademas revisar
  propiedad de rutas, contrato-antes-que-codigo, autoridad del servidor,
  ausencia de secretos e historia append-only, no solo el resultado de
  ejecucion de casos.

## 20. Sin reclamos de ejecucion

Este turno publica el contrato/taxonomia QA V2 unicamente. No reporta "todas
las fixtures V2 pasaron" porque ninguna fue materializada/ejecutada. El
cierre de este turno reporta: obligaciones inventariadas, casos
especificados (schema/boundary), cobertura mapeada, estado de
materializacion (`SPECIFIED_NOT_MATERIALIZED` para las 194 obligaciones).

## 21. Migracion desde QA 1.4.0

| Seccion 1.4.0 | Reclasificacion V2 |
|---|---|
| Paridad IR vs estado vivo | `LEGACY_PARITY`: observacion reproducible, no certifica V2 nativo |
| Certificacion viva de casas y camas | `LEGACY_LIVE_MUTATING`: bloqueada, evidencia preservada |
| Certificacion viva de muerte y corpse | `LEGACY_LIVE_MUTATING` |
| Certificacion viva de VIP y trade | `LEGACY_LIVE_MUTATING` |
| Certificacion viva de mail y parcels | `LEGACY_LIVE_MUTATING` |
| Certificacion viva de reacquisicion de monstruos | `LEGACY_LIVE_MUTATING` |

Ninguna de estas certifica Architecture V2 nativo por si sola; quedan como
`LEGACY / PARITY / HISTORICAL EVIDENCE` (`HISTORICAL / SUPERSEDED` mas
abajo), utiles para Phase 2 y como referencia de comportamiento legacy.

## 22. Consumidores y exclusiones

Consumidores: todos los carriles como sujetos de prueba; `orquestacion` para
revision de cierre de Phase 1.

QA V2 no expone secretos, no certifica `FULL_NATIVE_PLAYABLE`, no define
semantica de dominio ajena, no publica Monster Domain/Monster3D/Cyclops, y no
autoriza modificar `cliente3d/pruebas/`, `qa/`, `docs/qa/` ni codigo de
produccion de ningun otro carril en este turno.

## Historial de contrato de qa

| Version | Publicacion |
|---|---|
| `1.0.0`..`1.4.0` | TVP 7.72 en vivo como oracle/runtime primario, paquetes/ids legacy, pruebas Docker-orientadas (ver HISTORICAL) |
| `2.0.0` | taxonomia `TestClassV2`, `QACaseV2`/`QAReportV2`, matriz de cobertura de 194 obligaciones sobre los 7 contratos V2, invariantes cruzados, dominios bloqueados explicitos, `FULL_NATIVE_PLAYABLE` declarado bloqueado, boundary de `ParityFixtureV2` para Phase 2 |

## HISTORICAL / SUPERSEDED — QA 1.4.0 y anteriores

Estado: `SUPERSEDED` por QA V2 2.0.0 (secciones 0-22 arriba). Preservado
integro como evidencia; ninguna palabra `DEBE`/`NO DEBE`/`SOLO` en las
secciones siguientes gobierna el contrato vigente. Reclasificacion exacta
por seccion (ver tambien seccion 21):

- "Paridad IR vs estado vivo" -> `LEGACY_PARITY`.
- "Certificacion viva de casas y camas" -> `LEGACY_LIVE_MUTATING` (bloqueada).
- "Certificacion viva de muerte y corpse" -> `LEGACY_LIVE_MUTATING`.
- "Certificacion viva de VIP y trade" -> `LEGACY_LIVE_MUTATING`.
- "Certificacion viva de mail y parcels" -> `LEGACY_LIVE_MUTATING`.
- "Certificacion viva de reacquisicion de monstruos" -> `LEGACY_LIVE_MUTATING`.

Ninguna de estas certifica Architecture V2 nativo. TVP 7.72 en vivo como
oracle/runtime primario de pruebas queda superado: QA V2 usa TVP solo como
`LEGACY_PARITY` (Phase 2), nunca como aceptacion del runtime nativo.

## Proposito

Verificar recorridos completos y comparar una muestra del estado vivo de TVP
7.72 contra los datos estaticos importados al IR, sin convertir criaturas ni
otros datos dinamicos en parte del mapa fuente.

## Paridad IR vs estado vivo

La prueba ejecutable es:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_paridad_ventana.tscn
```

Reglas:

- Hace login contra el servidor TVP de prueba y espera el mapa inicial `0x64`.
- Compara una ventana de radio 4, es decir, 9x9 tiles en el piso actual.
- Compara cada item como `(client_id, cantidad)` en el orden recibido.
- Las criaturas se cuentan en el reporte, pero se excluyen de la comparacion
  porque son estado vivo y no pertenecen al IR estatico.
- Codigo de salida `0` exige cero diferencias; cualquier diferencia, timeout o
  desconexion produce codigo distinto de cero.

El reporte se escribe en
`cliente3d/generated/reports/live_parity_window.json` y conserva centro,
radio, fuente, conteos y diferencias.

## Resultado de referencia

La muestra ejecutada contra TVP produjo 81/81 tiles coincidentes, 0
diferencias y 1 criatura ignorada.

## No expone

- Credenciales ni secretos de despliegue.
- Autoridad de movimiento en el cliente.
- Cambios en `servidor/data/`; el servidor TVP sigue siendo la fuente viva.

## Compatibilidad

El reporte es adicional y no altera `EstadoMundo`, el IR ni el protocolo.

## Certificacion viva de casas y camas

La prueba `pruebas/prueba_casa_cama_vivo.tscn` debe cubrir una casa reproducible
del mapa real y conservar la autoridad del servidor en cada paso:

- El personaje god asigna temporalmente la casa 6 a `Valentino` y luego limpia
  el propietario al terminar.
- `Valentino` entra por la salida de la casa, usa una cama real y debe ser
  expulsado por el servidor al quedar dormido.
- Al reconectar, el servidor debe despertar al personaje, limpiar el sleeper y
  devolverlo a la entrada de la casa; la posicion persistida no puede depender
  de una prediccion del cliente.
- Un personaje no propietario debe recibir rechazo al usar la misma cama.

La prueba no modifica `servidor/data`; solo usa talkactions de god y paquetes
de uso de item contra el servidor de prueba. Si el mapa no contiene la cama o
la autoridad no expone alguno de estos pasos, el resultado es bloqueo
documentado y no una aprobacion parcial.

## Certificacion viva de muerte y corpse

La prueba `pruebas/prueba_muerte_loot_vivo.tscn` solo puede afirmar que falta
un corpse en una casilla si `EstadoMundo.mapa_alineado` sigue verdadero. Si el
jugador no aparece en su propia casilla despues del `0x64`, la pila local no es
evidencia del contenido que mando el servidor: la prueba debe fallar como mapa
desalineado y conservar `items_sin_catalogo`, `cids_sin_catalogo` y el primer
item imposible, sin atribuir el fallo al nombre o a `Creature::dropCorpse`.

La matriz local ejecuta tambien los self-tests de estado de criatura y mapa
7.72. Estos prueban paquetes sinteticos; una corrida viva sigue siendo
obligatoria para certificar que los saltos del servidor real terminan en la
misma casilla y consumen exactamente el `0x64`.

## Certificacion viva de VIP y trade

La prueba explicita es:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_trade_vip_vivo.tscn
```

Reglas:

- Abre `GOD VALENTINO` y `Valentino` en dos sesiones simultaneas y mantiene
  ambos sockets con el ping real del servidor.
- Fuerza remove/add de VIP y exige la secuencia offline, online al entrar y
  offline al salir, conservando el GUID que devuelve TVP.
- Reune a los personajes por autoridad del servidor, prepara dos fluid
  containers reales, envia oferta y contraoferta, acepta desde ambas sesiones
  y exige las actualizaciones de inventario de la transferencia, no solo el
  cierre `0x7F`.
- Es una prueba viva mutante: mueve objetos y actualiza la lista VIP de los
  personajes de prueba. No pertenece a la matriz local sin servidor.
- El objetivo acepta `--personaje=<nombre>` y `--guid=<numero>`. Otra cuenta
  puede darse con `--cuenta=<numero> --clave-env=<variable>`; la clave se lee
  del entorno y no se escribe en argumentos, reportes ni logs.
- La prueba usa el iniciador `0x7D` publicado por `protocolo-red` 1.5.0. Esto
  certifica servidor, parser y transferencia; el camino que empieza en el menu
  de criatura sigue requiriendo su propia prueba viva de interfaz.

## Certificacion viva de mail y parcels

La entrega se prueba contra el servidor reconstruido con
`pruebas/prueba_parcel_vivo.tscn`. Debe escribir y releer la etiqueta, meterla
en la parcel, comprobar que el mailbox la retira de la casilla y encontrarla
en el depot 1 del destinatario. Es una prueba mutante: crea parcels y cambia
los archivos persistidos de los personajes, por lo que no pertenece a la
matriz local ni se repite cuando el usuario ya confirmo el recorrido vivo.

## Certificacion viva de reacquisicion de monstruos

La prueba explicita es:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_reacquisicion_monstruo.tscn
```

Reglas:

- El servidor reune al god y al personaje fuera de PZ e invoca un monstruo
  nuevo, identificado por su id de criatura.
- Un primer golpe solo cuenta si el texto autoritativo nombra al monstruo
  invocado; una criatura silvestre cercana no sirve como evidencia.
- El servidor mueve al jugador 39 SQM fuera de la ventana visible, en el mismo
  piso y fuera de PZ, y lo devuelve inmediatamente.
- El cierre exige otro golpe nombrado despues del regreso y que el mismo id de
  criatura siga presente. Luego limpia el monstruo y devuelve al personaje a
  su templo.
