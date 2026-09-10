# Contrato: integracion

Version: 2.0.0
Estado: PUBLICADO
Propietario: integracion
Depende de: servidor 2.1.0, cliente 2.0.0, editor 2.0.0, assets 2.0.0

Integracion V2 ensambla consumidores ya publicados; no agrega dependencia
normativa sobre `modelo-comun` o `protocolo-red` solo porque esos contratos
los usan internamente. Historial: Integration 1.0.0 dependia de `servidor`,
`cliente`, `editor` y `assets` sin fijar version por numero (ver `HISTORICAL
/ SUPERSEDED` mas abajo).

Esta es una revision **major** deliberada. Integration 1.x trata TVP/Docker/
MariaDB como runtime primario y el perfil Godot "PROPIO" como secundario/
experimental; versiona `servidor/key.pem` como clave de desarrollo aceptable;
y fija `127.0.0.1:7277` como si fuera invariante de arquitectura. Architecture
V2 invierte esa relacion y supera esas tres politicas explicitamente (ver
seccion 3 y seccion 24). Ninguno de esos significados de 1.0.0 se reinterpreta
en silencio.

## 0. Proposito y alcance normativo (Integration V2)

Runtime final de Architecture V2:

```text
Godot 4.7 headless authoritative server
            |
       Protocol V2
            |
     Godot 4.7 3D client

  + Assets V2 datos normalizados
  + Editor V2 proyectos de autoria
```

TVP/TFS + Docker + MariaDB permanecen como perfil `LEGACY / PARITY /
MIGRATION`, NO el runtime nativo final. Este turno es contract-only: no se
modifican `.bat`, `project.godot`, archivos Docker, escenas de produccion,
codigo de servidor/cliente/editor, ni `servidor/key.pem`. Las palabras
`DEBE`, `NO DEBE`, `PUEDE` y `SOLO` son normativas en las secciones 0-26; el
contenido bajo `HISTORICAL / SUPERSEDED` no es normativo para V2.

## 1. `IntegrationProfileV2`

```json
{
  "schema": "tvp3d.integration.profile",
  "version": "2.0.0",
  "profile_id": "NATIVE_V2_DEV",
  "profile_kind": "NATIVE_V2",
  "godot": {
    "resolution_order": ["CONFIG_REFERENCE", "REPO_LOCAL_TOOL", "PATH"],
    "config_reference_env": "TVP3D_GODOT",
    "repo_local_path": "herramientas/godot/"
  },
  "server": {
    "headless_required": true,
    "bind_host": "127.0.0.1",
    "port": 7277,
    "accepted_common_domain_versions": ["2.1.0"],
    "dataset_binding": {
      "schema": "tvp3d.integration.dataset_binding",
      "version": "2.0.0",
      "logical_manifest_path": "assets/importados/v2/world.dataset-manifest.json",
      "expected_publication_class": "NORMALIZED_DOMAIN",
      "expected_assets_contract_version": "2.0.0",
      "expected_import_run_id": null
    },
    "log_destination_env": "TVP3D_SERVER_LOG_DIR"
  },
  "client": {
    "server_endpoint": {"host": "127.0.0.1", "port": 7277},
    "common_domain_offer": ["2.1.0"],
    "presentation_dataset_reference": "assets/importados/v2/world.dataset-manifest.json"
  },
  "editor": {
    "default_project_path_hint": "assets/proyectos/rookgaard_norte.json"
  },
  "environment_overrides": [
    {"env_var": "TVP3D_HOST", "applies_to": "server.bind_host"},
    {"env_var": "TVP3D_PUERTO", "applies_to": "server.port"},
    {"env_var": "TVP3D_GODOT", "applies_to": "godot.config_reference_env"}
  ]
}
```

Todos los campos de nivel raiz son obligatorios; `client` y `editor` pueden
ser objetos vacios `{}` si ese perfil no lanza esos roles.
`environment_overrides` puede ser `[]`.

| Campo | Regla |
|---|---|
| `profile_id` | `registry_token`-like, `^[A-Z][A-Z0-9_]{0,63}$`; identidad logica del perfil, no un path |
| `profile_kind` | enum cerrado (seccion 2) |
| `godot.resolution_order` | permutacion de `CONFIG_REFERENCE\|REPO_LOCAL_TOOL\|PATH`, 1..3 valores unicos |
| `godot.config_reference_env` | nombre de variable de entorno (string), nunca la ruta resuelta en si |
| `godot.repo_local_path` | path relativo al repositorio, nunca absoluto |
| `server.headless_required` | `true` para `NATIVE_V2` |
| `server.bind_host` | string validado (IP o hostname); es configuracion, no invariante (seccion 6) |
| `server.port` | entero `1..65535`; es configuracion, no invariante (seccion 6) |
| `server.accepted_common_domain_versions` | lista no vacia de SemVer; debe coincidir con el perfil de aplicacion nativo de `servidor` (`["2.1.0"]` para `servidor 2.1.0`) |
| `server.dataset_binding` | `DatasetBindingV2` exacto (seccion 10) |
| `server.log_destination_env` | nombre de variable de entorno o `null`; nunca un valor secreto |
| `client.server_endpoint` | `{host, port}` del mismo tipo que `server.bind_host`/`server.port` |
| `client.common_domain_offer` | debe coincidir con el perfil nativo de `cliente` (`["2.1.0"]` para `cliente 2.0.0`) |
| `editor.default_project_path_hint` | path relativo bajo `assets/proyectos/`; es una sugerencia de apertura, NUNCA identidad del proyecto (seccion 8) |
| `environment_overrides[].env_var` | nombre de variable de entorno |
| `environment_overrides[].applies_to` | path de puntos hacia un campo de este mismo objeto |

Un campo desconocido, un tipo incorrecto o un valor fuera de rango produce
`INTEGRATION_CONFIG_INVALID` (seccion 22); no hay defaults silenciosos.

## 2. `profile_kind` (registro cerrado)

```text
NATIVE_V2
LEGACY_TVP_772
```

| `profile_kind` | Clasificacion | Significado |
|---|---|---|
| `NATIVE_V2` | runtime final de Architecture V2 | Godot headless autoritativo + Godot 3D client + Protocol V2 + Assets V2 + Editor V2; NO requiere Docker, MariaDB ni `servidor/key.pem` |
| `LEGACY_TVP_772` | `LEGACY / PARITY / MIGRATION`, explicito | TVP/TFS + Docker + MariaDB; oracle y puente de migracion, nunca runtime final |

`NATIVE_V2` NO se documenta como experimental. `LEGACY_TVP_772` NO se
documenta como runtime primario. Un perfil declara exactamente un
`profile_kind`; no existe un tercer valor mixto en `2.0.0`.

Ejemplo minimo `LEGACY_TVP_772` (sin secretos, solo referencias):

```json
{
  "schema": "tvp3d.integration.profile",
  "version": "2.0.0",
  "profile_id": "LEGACY_TVP_772_DEV",
  "profile_kind": "LEGACY_TVP_772",
  "godot": {
    "resolution_order": ["CONFIG_REFERENCE", "REPO_LOCAL_TOOL", "PATH"],
    "config_reference_env": "TVP3D_GODOT",
    "repo_local_path": "herramientas/godot/"
  },
  "legacy": {
    "requires_docker": true,
    "requires_mariadb": true,
    "login_port": 7171,
    "game_port": 7172,
    "mariadb_windows_port": 3371,
    "phpmyadmin_port": 8071,
    "rsa_private_key_ref_env": "TVP3D_LEGACY_RSA_KEY_PATH"
  },
  "environment_overrides": []
}
```

`legacy.rsa_private_key_ref_env` es el nombre de una variable de entorno que
apuntaria a la clave; el valor de la clave JAMAS aparece en un
`IntegrationProfileV2` versionado (seccion 3).

## 3. Politica de secretos (no negociable en V2)

La configuracion de integracion versionada NO PUEDE contener:

contrasenas, claves privadas, credenciales de cuenta, tokens de acceso,
secretos OAuth, contrasenas de base de datos, API keys, material RSA
privado.

La configuracion versionada PUEDE contener solo:

- nombres de variables de entorno;
- referencias logicas a un secreto (por ejemplo, un nombre de secreto en un
  gestor externo, si se define en un contrato futuro de integracion
  operativa);
- configuracion publica no secreta.

Nunca el valor del secreto en si. Un valor que coincide con la forma de un
secreto conocido (por ejemplo, un bloque `BEGIN RSA PRIVATE KEY`, una
contrasena literal o un token) en un `IntegrationProfileV2` versionado
produce `INTEGRATION_SECRET_IN_VERSIONED_CONFIG` (seccion 22) y bloquea la
carga del perfil.

### Politica superada: `servidor/key.pem` versionado

Integration 1.0.0 declaraba `servidor/key.pem` como clave RSA de desarrollo
versionada "compatible" para el perfil legacy. Esa afirmacion se preserva
**solo** en `HISTORICAL / SUPERSEDED` mas abajo. Para Architecture V2, esa
politica queda explicitamente superada:

- una clave privada es un secreto sin importar si el repositorio es privado;
- Native V2 NO REQUIERE una clave privada versionada; `NATIVE_V2` no tiene
  ningun campo de clave privada en su schema (seccion 1);
- este turno contract-only NO borra ni rota el archivo existente
  `servidor/key.pem`; no se inspecciona ni se imprime su contenido;
- queda como nota de remediacion/deuda explicita: el archivo permanece fuera
  del alcance de este turno, pertenece solo a la historia de
  migracion/paridad legacy, y una limpieza operativa/de seguridad futura debe
  decidir su remocion o rotacion;
- ninguna configuracion `2.0.0` puede copiar o depender de ese material
  privado; `legacy.rsa_private_key_ref_env` (seccion 2) es una referencia por
  nombre, nunca el contenido.

## 4. Resolucion de Godot

Orden conceptual, sin fijar un ejecutable especifico de maquina:

1. `CONFIG_REFERENCE`: variable de entorno o campo de configuracion explicito
   (`godot.config_reference_env`);
2. `REPO_LOCAL_TOOL`: ubicacion local del repositorio si esta oficialmente
   provista (`godot.repo_local_path`, por ejemplo `herramientas/godot/`);
3. `PATH`: resolucion estandar del sistema.

`godot.resolution_order` declara el orden exacto que un perfil usa; el orden
por defecto sugerido es el de arriba. Ningun perfil versionado incluye una
ruta absoluta de maquina (`C:\Users\...`) como valor fijo (seccion 12); una
ruta absoluta solo puede llegar como override de entorno/CLI en tiempo de
ejecucion local, nunca serializada.

## 5. Contrato de arranque del servidor nativo

Server V2 DEBE ejecutarse como Godot 4.7 con `--headless`. La configuracion
de integracion identifica, sin redefinir el contrato `servidor`:

- perfil/aplicacion de servidor (`profile_id`, `profile_kind=NATIVE_V2`);
- publicacion del dataset normalizado (`server.dataset_binding`, seccion 10);
- host/interfaz de bind (`server.bind_host`);
- puerto (`server.port`);
- destino de log/reporte si aplica (`server.log_destination_env`);
- fuente de configuracion no secreta.

Estos son datos de configuracion de integracion, no constantes de
arquitectura. `servidor 2.1.0` no fija host/puerto en su propio contrato;
tampoco lo hace este.

## 6. Host / puerto

Integration 1.x fijaba `127.0.0.1:7277` como si fuera invariante del perfil
propio. Eso queda superado: host y puerto son **configuracion de
integracion**, nunca invariante de Protocol V2 ni de `servidor`.

- `port`: entero `1..65535`;
- `bind_host`/`connect host`: string validado como IP o hostname segun el
  schema de este contrato (no se redefine aqui una gramatica DNS completa).

Un perfil de desarrollo PUEDE usar por defecto loopback (`127.0.0.1`) y un
puerto convencional (por ejemplo `7277`), pero el contrato distingue
explicitamente:

- **configuracion por defecto** (lo que un perfil de ejemplo declara);
- **invariante de protocolo/dominio** (algo que Protocol V2 exigiria siempre).

Protocol V2 no tiene puerto sagrado.

## 7. Contrato de arranque del cliente nativo

La configuracion de integracion para el cliente identifica:

- endpoint del servidor (`client.server_endpoint`);
- seleccion de perfil nativo;
- referencias de publicacion de dataset/presentacion, si se requieren;
- opciones de runtime no secretas.

NO se incluyen credenciales de autenticacion en este perfil. `cliente 2.0.0`
exige hoy un `RuntimeInstanceRefV2` de actor controlado suministrado por un
contrato FUTURO de sesion-de-aplicacion/autenticacion que todavia no existe
(cliente 2.0.0, seccion 12). Por lo tanto, Integration V2 NO PUEDE afirmar
que "el login/gameplay nativo completo esta terminado". Este contrato solo
puede definir expectativas de arranque y de smoke de
conexion/baseline (seccion 15), nunca un criterio de aceptacion de gameplay
completo.

## 8. Contrato de arranque del editor

La identidad de un proyecto Editor V2 es `project_id` (UUID), no su
filename/path (editor 2.0.0, seccion 2). Integration PUEDE configurar un
path relativo al repositorio para abrir un proyecto
(`editor.default_project_path_hint`), pero mover/renombrar ese archivo NO
altera su `project_id`. Integration NO INFIERE identidad de proyecto desde el
path. Las rutas bajo `assets/proyectos/` son referencias de almacenamiento de
integracion/editor, no identidad de dominio.

## 9. Vinculacion de assets/datos

El servidor/cliente/editor nativos NO DESCUBREN archivos legacy arbitrarios
escaneando rutas de maquina. El perfil de integracion referencia datos
publicados de Assets V2 mediante configuracion logica explicita
(`server.dataset_binding`, `client.presentation_dataset_reference`). Para el
servidor nativo, el dataset autoritativo debe satisfacer el gate
`NORMALIZED_DOMAIN` de Server V2.

El perfil nativo `NATIVE_V2` NO PUEDE apuntar directamente a `OTBM`, `OTB`,
`DAT`, `SPR` ni `servidor/data/` como autoridad runtime. Esos pertenecen a
los flujos de import/paridad de Assets V2, no a la configuracion de
integracion nativa.

## 10. `DatasetBindingV2`

```json
{
  "schema": "tvp3d.integration.dataset_binding",
  "version": "2.0.0",
  "logical_manifest_path": "assets/importados/v2/world.dataset-manifest.json",
  "expected_publication_class": "NORMALIZED_DOMAIN",
  "expected_assets_contract_version": "2.0.0",
  "expected_import_run_id": null
}
```

| Campo | Regla |
|---|---|
| `logical_manifest_path` | path relativo al repositorio; referencia de localizacion, NO identidad ni validacion de contenido |
| `expected_publication_class` | debe ser `NORMALIZED_DOMAIN` para uso autoritativo nativo |
| `expected_assets_contract_version` | SemVer; debe coincidir con `assets` publicado (`2.0.0`) |
| `expected_import_run_id` | `content_id` (`sha256:...`) opcional o `null`; si esta presente, es un `import_run_id` esperado segun lo expone `servidor`/`assets` |

Integration SOLO localiza/selecciona el dataset publicado; NO redefine ni
copia los schemas `AuthoritativeDatasetManifestV2` (servidor),
`ImportRunManifestV2` o `NormalizedRecordV2` (assets). La validacion
semantica real del dataset es autoridad de `assets`/`servidor`.

## 11. Capas de configuracion

Precedencia determinista, de menor a mayor:

1. defaults del contrato (los valores de ejemplo de este documento);
2. configuracion de perfil versionada no secreta (`IntegrationProfileV2`);
3. overrides de entorno (`environment_overrides`, por nombre de variable);
4. overrides explicitos de linea de comandos.

Una capa de mayor precedencia sobreescribe una de menor precedencia campo por
campo. Reglas adicionales:

- un secreto NUNCA entra en la configuracion versionada (seccion 3), sin
  importar la capa;
- una clave de configuracion desconocida en cualquier capa falla
  (`INTEGRATION_CONFIG_INVALID`);
- un valor invalido falla, sin normalizarlo silenciosamente;
- el NOMBRE de una variable de entorno es dato de contrato/configuracion
  (puede versionarse); el VALOR de esa variable es estado de runtime, nunca
  un artefacto versionado;
- un override explicito invalido falla sin caer de vuelta a un valor
  anterior o a otro perfil (seccion 21).

## 12. Reglas de path

Los paths versionados DEBEN ser relativos al repositorio o paths logicos de
recurso. NUNCA:

```text
C:\Users\...
/home/alguien/...
otra ruta absoluta de maquina
```

Un path absoluto de ejecutable suministrado en tiempo de ejecucion mediante
un override explicito de entorno/configuracion local PUEDE permitirse para
descubrimiento de herramientas (por ejemplo, `TVP3D_GODOT` apuntando a un
binario local), pero ese valor NUNCA se serializa dentro de un artefacto de
proyecto/perfil versionado y determinista. La distincion es explicita:
override de entorno local (permitido, no versionado) vs. campo de perfil
versionado (rechazado si es absoluto:
`INTEGRATION_ABSOLUTE_PATH_REJECTED`).

## 13. Orden de arranque nativo

Secuencia conceptual:

1. cargar `IntegrationProfileV2`;
2. validar perfil/schema;
3. resolver Godot (seccion 4);
4. resolver la publicacion de Assets referenciada (`DatasetBindingV2`);
5. validar prerequisitos del servidor nativo (`NORMALIZED_DOMAIN`,
   `accepted_common_domain_versions`);
6. lanzar Godot server `--headless`;
7. esperar la superficie de disponibilidad/liveness definida por integracion
   (seccion 14);
8. lanzar el cliente si se solicito;
9. el cliente negocia Protocol V2/common `2.1.0` (cliente 2.0.0, seccion 1);
10. el cliente recibe el baseline autoritativo (`CORE_ENTITY_STATE`, cliente
    2.0.0, secciones 5-6);
11. el editor, si se abre, lo hace de forma independiente contra su propio
    `project_id`/`SourceBindingV2` (editor 2.0.0).

Esta secuencia NO inventa autorizacion de gameplay: el paso 10 llega a
`ACTIVE` (fase de mundo del cliente), no a un actor controlado autorizado
(cliente 2.0.0, seccion 12, sigue sin resolverse).

## 14. Observaciones de disponibilidad (readiness)

Integration distingue explicitamente, sin redefinir ninguna maquina de
estados de dominio/protocolo/cliente:

```text
PROCESS_STARTED
TRANSPORT_REACHABLE
PROTOCOL_NEGOTIATED
AUTHORITATIVE_BASELINE_ACCEPTED
```

| Observacion | Significa | NO implica |
|---|---|---|
| `PROCESS_STARTED` | el proceso Godot arranco sin salir inmediatamente | puerto abierto, `ServerLifecycleStateV2 READY` |
| `TRANSPORT_REACHABLE` | el puerto TCP acepta conexiones | `ServerLifecycleStateV2 READY`, `ProtocolConnectionStateV2 READY` |
| `PROTOCOL_NEGOTIATED` | `SERVER_WELCOME` fue aceptado con `common_domain_version=2.1.0` | `ClientWorldPhaseV2 ACTIVE`, autorizacion de aplicacion |
| `AUTHORITATIVE_BASELINE_ACCEPTED` | el cliente acepto un `CORE_ENTITY_STATE` valido y esta `ACTIVE` | actor controlado autorizado, gameplay habilitado |

Estas son observaciones de integracion para smoke/diagnostico, no un nuevo
`ProtocolConnectionStateV2`, `ServerLifecycleStateV2` ni
`ClientWorldPhaseV2`. `TCP abierto` no se confunde con `servidor gameplay
READY`, y `Protocol READY` no se confunde con `Client ACTIVE` (mismas reglas
que `protocolo-red`/`servidor`/`cliente` ya fijan).

## 15. Frontera de certificacion del smoke nativo

Lo que Integration V2 PUEDE certificar hoy contra los contratos publicados:

- el proceso servidor es lanzable en `--headless`;
- el proceso cliente es lanzable;
- la negociacion Protocol `2.1.0`/common `2.1.0` es posible
  (`PROTOCOL_NEGOTIATED`);
- un baseline autoritativo `CORE_ENTITY_STATE` puede aceptarse en principio
  (`AUTHORITATIVE_BASELINE_ACCEPTED`);
- ningun secreto se imprime durante el smoke;
- un apagado limpio es posible (seccion 16).

Porque `Authentication/Application Session` y `Map/World Rules` siguen sin
publicarse, Integration V2 declara explicitamente:

**`FULL_NATIVE_PLAYABLE` esta BLOQUEADO / AUN NO DEFINIDO.**

Caminar con teclado o cualquier prueba de gameplay del prototipo historico
sigue siendo evidencia `HISTORICAL`, NUNCA un gate de aceptacion V2 valido
hasta que esos contratos existan.

## 16. Apagado (shutdown)

Como minimo:

- se solicita cierre/`GOODBYE` al cliente donde aplique (protocolo-red);
- el servidor entra en su via de parada ordenada donde el contrato
  `servidor` la soporte (`DRAINING -> STOPPED`);
- los procesos hijos quedan contabilizados (ninguno queda huerfano sin
  reportarse);
- integracion NO borra datasets ni proyectos por defecto;
- ninguna "limpieza" puede destruir artefactos fuente (assets, proyectos,
  `servidor/data/`);
- una salida distinta de cero se reporta si un proceso requerido no puede
  detenerse dentro de la politica de timeout operativo, que este turno NO
  fija en segundos exactos (queda para un contrato operativo futuro).

## 17. Logging

Los logs de integracion NUNCA imprimen contrasenas, tokens, claves privadas,
valores de credenciales ni valores secretos de entorno. PUEDEN contener
`profile_id`, versiones de schema, codigos de salida de proceso, endpoints no
secretos, paths logicos y hashes/content ids donde sea seguro. La redaccion
ocurre antes de persistir cualquier diagnostico.

## 18. Perfil legacy `LEGACY_TVP_772`

Preserva el conocimiento util de integracion TVP 7.72: Docker, MariaDB,
puertos `7171`/`7172`, requisitos RSA legacy, phpMyAdmin y los flujos `.bat`
existentes (ver `HISTORICAL / SUPERSEDED`). Toda esa superficie queda
clasificada explicitamente `LEGACY / PARITY / MIGRATION`, no arquitectura de
runtime final. No se borra evidencia historica ni comandos exitosos. El
arranque de `NATIVE_V2` NO REQUIERE este perfil.

## 19. Docker

`NATIVE_V2` NO PUEDE requerir Docker. Docker sigue siendo legitimo para
`LEGACY_TVP_772`, herramientas de desarrollo, o infraestructura opcional
futura si se contrata por separado. La autoridad final de Server V2 debe
poder correr como Godot headless sin TVP/TFS/MariaDB legacy.

## 20. Modelo de comando/entrypoint

Este turno NO modifica ningun `.bat`. Se definen roles logicos, separados de
cualquier nombre de archivo:

```text
PREPARE_NATIVE
START_NATIVE_SERVER
START_NATIVE_CLIENT
OPEN_EDITOR
SMOKE_NATIVE
STOP_NATIVE
```

y sus equivalentes legacy conceptuales (`PREPARE_LEGACY`, `START_LEGACY`,
`PLAY_LEGACY`, `SMOKE_LEGACY`, `STOP_LEGACY`).

Mapeo historico/actual informativo (no normativo, no se toca este turno):

| Rol logico | `.bat` actual (evidencia) |
|---|---|
| `PREPARE_NATIVE` | `PREPARAR TVP3D PROPIO.bat` |
| `START_NATIVE_SERVER` | `ARRANCAR SERVIDOR PROPIO.bat` |
| `START_NATIVE_CLIENT` | `JUGAR PROPIO.bat` |
| `SMOKE_NATIVE` | `PROBAR SERVIDOR PROPIO.bat` |
| `OPEN_EDITOR` | `ABRIR MAP EDITOR.bat` |
| `PREPARE_LEGACY` | `PREPARAR TVP3D.bat` |
| `START_LEGACY` | `ARRANCAR SERVIDOR.bat` |
| `PLAY_LEGACY` | `JUGAR.bat` |
| `SMOKE_LEGACY` | `PROBAR CONEXION.bat` |
| `STOP_LEGACY` | `PARAR SERVIDOR.bat` |

Una implementacion futura puede exponer estos roles via `.bat`, shell,
PowerShell u otro lanzador, preservando el rol semantico. El nombre de
archivo NUNCA es el contrato.

## 21. Fail fast / sin fallback implicito a legacy

Critico: si `NATIVE_V2` no puede arrancar, **FALLA `NATIVE_V2`**. Integration
V2 NO PUEDE:

- iniciar TVP automaticamente;
- cambiar al protocolo 7.72;
- cargar un mapa demo antiguo en silencio;
- elegir otro dataset legacy;
- usar la clave RSA versionada del perfil legacy;
- seleccionar otro puerto sin reportarlo.

Cambiar de perfil exige una eleccion explicita de usuario/configuracion, NO
un fallback automatico.

## 22. `IntegrationErrorV2`

```json
{
  "schema": "tvp3d.integration.error",
  "version": "2.0.0",
  "code": "INTEGRATION_SECRET_IN_VERSIONED_CONFIG",
  "path": "$.legacy.rsa_private_key",
  "message": "versioned profile fields may only reference environment variable names, never secret values",
  "context": {}
}
```

`code` es `registry_token`; `path` es `null` o JSONPath ASCII 1..256 bytes;
`message` es UTF-8 0..256 bytes sin secretos ni paths absolutos; `context` es
`{}` en `2.0.0`. Un error de un contrato dependiente conserva su
`owner`/`code` original.

| Codigo | Abortar | Limpieza | Accion sobre proceso hijo | Fallback a legacy |
|---|---|---|---|---|
| `INTEGRATION_PROFILE_UNSUPPORTED` | si | nada que limpiar (nada arranco) | ninguno | NO |
| `INTEGRATION_CONFIG_INVALID` | si | nada que limpiar | ninguno | NO |
| `INTEGRATION_SECRET_IN_VERSIONED_CONFIG` | si, antes de cargar el perfil | nada que limpiar | ninguno | NO |
| `INTEGRATION_ABSOLUTE_PATH_REJECTED` | si, para ese campo | nada que limpiar | ninguno | NO |
| `INTEGRATION_GODOT_NOT_FOUND` | si | nada que limpiar | ninguno | NO |
| `INTEGRATION_DATASET_NOT_FOUND` | si | nada que limpiar | ninguno | NO |
| `INTEGRATION_DATASET_PROFILE_INVALID` | si | nada que limpiar | ninguno | NO |
| `INTEGRATION_SERVER_START_FAILED` | si | terminar el proceso servidor si llego a lanzarse | detener | NO |
| `INTEGRATION_SERVER_NOT_READY` | si (timeout de espera) | detener el proceso servidor | detener | NO |
| `INTEGRATION_CLIENT_START_FAILED` | si | el servidor puede seguir vivo segun configuracion | detener cliente | NO |
| `INTEGRATION_PROTOCOL_NEGOTIATION_FAILED` | si | cerrar la conexion del cliente | cerrar sesion | NO |
| `INTEGRATION_BASELINE_FAILED` | si | cerrar sesion/cliente | cerrar sesion | NO |
| `INTEGRATION_EDITOR_PROJECT_INVALID` | solo para la apertura del editor | ninguna sobre servidor/cliente | ninguno | NO |
| `INTEGRATION_SHUTDOWN_FAILED` | reporta salida distinta de cero | mejor esfuerzo de terminar hijos restantes | forzar terminacion si procede | NO (no hay a que volver) |

`NATIVE_V2` NUNCA cae de vuelta a `LEGACY_TVP_772` en ningun codigo de esta
tabla.

## 23. Fixtures contractuales (especificacion, sin produccion)

| Fixture | Caso minimo | Resultado obligatorio |
|---|---|---|
| `INTEGRATION-NATIVE-MIN-001` | perfil `NATIVE_V2` minimo valido | acepta |
| `INTEGRATION-LEGACY-MIN-001` | perfil `LEGACY_TVP_772` minimo valido | acepta |
| `INTEGRATION-NODOCKER-001` | perfil `NATIVE_V2` sin campo Docker | no requiere Docker |
| `INTEGRATION-NOMARIADB-001` | perfil `NATIVE_V2` sin campo MariaDB | no requiere MariaDB |
| `INTEGRATION-NOKEYPEM-001` | perfil `NATIVE_V2` sin referencia a `servidor/key.pem` | no requiere el archivo |
| `INTEGRATION-SECRET-001` | valor con forma de secreto en config versionada | `INTEGRATION_SECRET_IN_VERSIONED_CONFIG` |
| `INTEGRATION-ENVREF-001` | referencia por nombre de variable de entorno | aceptado |
| `INTEGRATION-PATH-REL-001` | path relativo al repositorio | aceptado |
| `INTEGRATION-PATH-ABS-001` | path absoluto de maquina en perfil versionado | `INTEGRATION_ABSOLUTE_PATH_REJECTED` |
| `INTEGRATION-PORT-VALID-001` | puerto `1..65535` | aceptado |
| `INTEGRATION-PORT-INVALID-001` | puerto `0` o `> 65535` | `INTEGRATION_CONFIG_INVALID` |
| `INTEGRATION-CLI-OVERRIDE-001` | override explicito de CLI valido | precedencia maxima aplicada |
| `INTEGRATION-CLI-OVERRIDE-INVALID-001` | override explicito de CLI invalido | falla sin fallback a un valor anterior |
| `INTEGRATION-HEADLESS-001` | arranque de Server V2 | exige `--headless` |
| `INTEGRATION-DATASET-NORMALIZED-001` | `dataset_binding` apunta a publicacion `NORMALIZED_DOMAIN` | aceptado |
| `INTEGRATION-DATASET-RAW-001` | `dataset_binding` apunta a `servidor/data/`/OTBM crudo | rechazado como dataset autoritativo nativo |
| `INTEGRATION-CLIENT-OFFER-001` | perfil de cliente | `common_domain_offer=["2.1.0"]` |
| `INTEGRATION-READY-DIFF-001` | proceso arrancado sin negociacion | `PROCESS_STARTED` sin `PROTOCOL_NEGOTIATED` |
| `INTEGRATION-READY-DIFF-002` | negociacion sin baseline aceptado | `PROTOCOL_NEGOTIATED` sin `AUTHORITATIVE_BASELINE_ACCEPTED` |
| `INTEGRATION-SMOKE-NOACTOR-001` | smoke de baseline sin actor controlado | puede pasar `AUTHORITATIVE_BASELINE_ACCEPTED` sin autorizacion de gameplay |
| `INTEGRATION-FULLPLAYABLE-BLOCKED-001` | intento de certificar `FULL_NATIVE_PLAYABLE` | reportado bloqueado pendiente de Authentication/Application Session y Map/World Rules |
| `INTEGRATION-EDITOR-PATHMOVE-001` | mover/renombrar el archivo de un proyecto editor | `project_id` no cambia |
| `INTEGRATION-NOFALLBACK-001` | fallo de arranque `NATIVE_V2` | `LEGACY_TVP_772` nunca arranca automaticamente |
| `INTEGRATION-LOGREDACT-001` | logs generados durante un smoke | cero valores secretos presentes |
| `INTEGRATION-SHUTDOWN-PRESERVE-001` | apagado tras un smoke | datasets/proyectos/artefactos fuente quedan intactos |

Especificaciones de contrato; ningun test ni produccion se implementa en
este turno.

## 24. Migracion desde Integration 1.0.0

| v1 | Regla de migracion a V2 |
|---|---|
| `127.0.0.1:7277` fijo para el perfil propio | pasa a `server.bind_host`/`server.port` de configuracion; solo un default de un perfil `NATIVE_V2` de ejemplo, nunca invariante de protocolo/arquitectura |
| `servidor/key.pem` versionado "compatible con desarrollo privado" | politica superada (seccion 3); ningun campo `2.0.0` porta material privado; el archivo existente queda como deuda de remediacion fuera de este turno |
| Perfil `PROPIO` calificado "experimental"/"ruta separada" | reclasificado `profile_kind=NATIVE_V2`, el runtime final de Architecture V2 |
| TVP/Docker/MariaDB como recorrido principal (`ARRANCAR SERVIDOR.bat` primero en la lista) | reclasificado `profile_kind=LEGACY_TVP_772`, explicito `LEGACY/PARITY/MIGRATION`; `NATIVE_V2` no lo requiere |
| Los `.bat` documentados como si fueran el contrato mismo | se documentan roles logicos (seccion 20) separados del nombre de archivo; los `.bat` existentes quedan como evidencia historica, sin tocarse este turno |
| "El cliente llega a la pantalla de juego con la cuenta de desarrollo" como criterio de aceptacion | eso validaba el perfil legacy con su propia autenticacion TVP; `NATIVE_V2` no puede certificar login/gameplay completo hasta el contrato futuro de Authentication/Application Session (seccion 15) |

Ningun criterio de aceptacion legacy se descarta; queda preservado como
evidencia historica de paridad.

## 25. Consumidores y exclusiones

Consumidores: `qa`, desarrolladores que preparan una maquina limpia,
`servidor`/`cliente`/`editor` como procesos lanzados.

Integration V2 no expone secretos, no redefine autoridad de `servidor`, no
redefine estados de `protocolo-red`/`cliente`, no certifica
`FULL_NATIVE_PLAYABLE`, y no publica Map/World Rules, Authentication/
Application Session, Monster Domain ni Monster3D. No autoriza modificar
`.bat`, `project.godot`, Docker, escenas de produccion ni `servidor/key.pem`.

## 26. Dependencias downstream y reporte a QA

`FULL_NATIVE_PLAYABLE` esta bloqueado explicitamente por, como minimo:

| Falta | Bloquea |
|---|---|
| Authentication / Application Session | actor controlado autorizado (cliente 2.0.0 seccion 12); sin esto ningun `CommandEnvelopeV2` de gameplay es legitimo |
| Map / World Rules Domain | caminabilidad/ocupacion/pathfinding autoritativos; sin esto `MOVE` sigue sin habilitarse en produccion (servidor 2.1.0 seccion 14) |
| Posibles dominios adicionales (Combat, Item/Inventory, Monster/Spawn) | jugabilidad completa mas alla del smoke de baseline |

QA V2 debe materializar, como minimo, las fixtures de la seccion 23: perfiles
minimos validos, ausencia de Docker/MariaDB/`key.pem` en `NATIVE_V2`, rechazo
de secretos/paths absolutos, puertos validos/invalidos, precedencia de
overrides, distincion `PROCESS_STARTED`/`PROTOCOL_NEGOTIATED`/
`AUTHORITATIVE_BASELINE_ACCEPTED`, bloqueo explicito de
`FULL_NATIVE_PLAYABLE`, ausencia de fallback automatico a legacy, y
preservacion de datasets/proyectos/fuentes tras apagado.

## Historial de contrato de integracion

| Version | Publicacion |
|---|---|
| `1.0.0` | TVP/Docker/MariaDB como runtime primario, perfil propio experimental en `127.0.0.1:7277`, `servidor/key.pem` versionado (ver HISTORICAL) |
| `2.0.0` | `IntegrationProfileV2` con `profile_kind` cerrado (`NATIVE_V2` final, `LEGACY_TVP_772` explicito), politica de secretos no negociable, host/puerto como configuracion, `DatasetBindingV2`, capas de configuracion deterministas, sin fallback implicito a legacy, `FULL_NATIVE_PLAYABLE` declarado bloqueado |

## HISTORICAL / SUPERSEDED — Integration 1.0.0

Estado: `SUPERSEDED` por Integration V2 2.0.0 (secciones 0-26 arriba).
Preservado integro como evidencia; ninguna palabra `DEBE`/`NO DEBE`/`SOLO` en
las secciones siguientes gobierna el contrato vigente.

Quedan explicitamente superados por V2:

- TVP/Docker/MariaDB como runtime final primario (ahora `LEGACY_TVP_772`
  explicito, seccion 2/18);
- el perfil `PROPIO` calificado como experimental (ahora `NATIVE_V2`, el
  runtime final, seccion 2);
- `127.0.0.1:7277` como invariante de arquitectura del perfil nativo (ahora
  configuracion, seccion 6);
- versionar una clave RSA privada como politica de secretos aceptable para
  V2 (seccion 3).

No se borra ningun comando, ruta ni evidencia de smoke exitoso historico.

## Proposito

Permitir que una maquina limpia clone TVP3D, prepare sus herramientas y
arranque tanto el perfil legacy TVP 7.72 como el perfil propio Godot usando
rutas relativas al repositorio.

## Requisitos de maquina

- Windows 10/11.
- Docker Desktop iniciado y con Docker Compose disponible.
- Godot 4.7.x. Puede estar en `herramientas/godot/`, en el PATH como `godot`,
  o indicarse con la variable `TVP3D_GODOT`.
- El repositorio privado clonado con todos sus archivos versionados.

## Archivos de desarrollo versionados

- `servidor/config.lua` contiene la configuracion local Docker de TVP3D.
- `servidor/key.pem` contiene la clave RSA de desarrollo compatible con
  `cliente3d/red/rsa.gd`.
- `servidor/gamedata/` y `.godot/` siguen siendo estado local generado y no se
  versionan.

## Comandos publicos

| Comando | Resultado |
|---|---|
| `PREPARAR TVP3D.bat` | Verifica Docker, Godot, config y RSA |
| `ARRANCAR SERVIDOR.bat` | Compila y arranca TVP y MariaDB en Docker |
| `JUGAR.bat` | Abre el cliente TVP3D conectado a localhost |
| `ABRIR MAP EDITOR.bat` | Abre el editor 3D del mapa |
| `PROBAR CONEXION.bat` | Ejecuta la prueba de login y movimiento |
| `PARAR SERVIDOR.bat` | Detiene los contenedores sin borrar la base |
| `PREPARAR TVP3D PROPIO.bat` | Verifica Godot y las escenas del perfil propio |
| `ARRANCAR SERVIDOR PROPIO.bat` | Arranca el servidor Godot headless en `7277` |
| `JUGAR PROPIO.bat` | Abre el cliente propio 3D en `7277` |
| `PROBAR SERVIDOR PROPIO.bat` | Comprueba dos clientes, estado compartido y ocupacion |

Todos los comandos se resuelven desde `%~dp0`; no dependen de
`C:\Users\dell\...` ni de un directorio de trabajo externo.

## Perfil de red

- Login: `7171`.
- Juego: `7172`.
- MariaDB desde Windows: `3371`.
- phpMyAdmin: `8071`.
- Dentro de Docker, el servidor usa `mariadb:3306`.
- Perfil propio: TCP `127.0.0.1:7277`, sin Docker ni MariaDB.

## Criterio de aceptacion

Una maquina con Docker Desktop y Godot instalados puede ejecutar `PREPARAR
TVP3D.bat`, luego `ARRANCAR SERVIDOR.bat` y `JUGAR.bat`; el cliente llega a la
pantalla de juego con la cuenta de desarrollo y el mapa completo. Sin Docker,
el perfil propio debe pasar `PREPARAR TVP3D PROPIO.bat`, luego
`ARRANCAR SERVIDOR PROPIO.bat` y `JUGAR PROPIO.bat`; el recorrido de dos
clientes se valida con `PROBAR SERVIDOR PROPIO.bat`. Los modelos 3D de
criaturas se pueden agregar bajo `cliente3d/assets/` y conectarse al
identificador/nombre conservado por el renderer de cubos.

## Errores

- Si falta Docker, Godot, `servidor/config.lua` o `servidor/key.pem`, el
  preparador termina con codigo distinto de cero y explica el archivo faltante.
- Si Docker no esta iniciado, el preparador lo reporta sin imprimir
  credenciales.
