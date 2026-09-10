# Estado: integracion

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-09-10T01:05:00-06:00
Contrato publicado: SI (`CONTRATO.md` v2.0.1)

## Turno cerrado: Phase 1G.1 — Integration Profile Schema Erratum

- Erratum de patch `2.0.0 -> 2.0.1`. Sin cambios de arquitectura: politica de
  secretos, `DatasetBindingV2`, precedencia de configuracion, orden de
  arranque, observaciones de disponibilidad, frontera de smoke,
  `IntegrationErrorV2` y politica sin-fallback quedan identicos.
- Corregida la contradiccion interna de `2.0.0`: el texto exigia "todos los
  campos de nivel raiz obligatorios" y rechazo de campos desconocidos, pero
  el propio ejemplo normativo `LEGACY_TVP_772` omitia `server`/`client`/
  `editor` e introducia `legacy`, un campo fuera de la tabla generica de
  campos raiz. Bajo esa regla literal, el propio ejemplo `LEGACY_TVP_772` de
  2.0.0 no validaba contra su propio contrato.
- `IntegrationProfileV2` republicado como **union discriminada exacta** por
  `profile_kind` (seccion 1): raiz comun (`schema`, `version`, `profile_id`,
  `profile_kind`, `godot`, `environment_overrides`, identica en ambas
  variantes) + dos raices de variante mutuamente excluyentes:
  - `NATIVE_V2` (1.1): `server` obligatorio; `client`/`editor` obligatorios
    como objetos pero pueden ser `{}`; `legacy` prohibido incluso vacio.
  - `LEGACY_TVP_772` (1.2): `legacy` obligatorio (forma cerrada
    `LegacyProfileV2`: `requires_docker`, `requires_mariadb`, `login_port`,
    `game_port`, `mariadb_windows_port`, `phpmyadmin_port`,
    `rsa_private_key_ref_env`); `server`/`client`/`editor` prohibidos
    incluso vacios.
- Publicado el algoritmo de discriminador exacto (seccion 1.3, 7 pasos):
  `profile_kind` selecciona la variante; nunca se infiere de la presencia de
  campos; un campo de la otra variante o un campo desconocido siempre
  produce `INTEGRATION_CONFIG_INVALID`.
- `tvp3d.integration.profile` avanza `2.0.0 -> 2.0.1` porque su regla de
  validacion de raiz cambio de forma observable; `2.0.0` queda
  `SUPERSEDED POR ERRATUM` para ese schema especifico (seccion 27).
  `tvp3d.integration.dataset_binding/2.0.0` y `tvp3d.integration.error/2.0.0`
  NO cambiaron de version porque su forma no tenia ninguna ambiguedad.
- Agregadas 14 fixtures especificas del erratum (seccion 23, subseccion
  dedicada) cubriendo ambas variantes minimas, `client={}`/`editor={}`,
  rechazo cruzado de campos de la otra variante, variante requerida ausente,
  `profile_kind` desconocido, campo de raiz desconocido, no-inferencia del
  discriminador, ausencia de secretos y `DatasetBindingV2` sin cambios.
- No se modifico codigo de produccion, `.bat`, Docker, `project.godot`,
  config ni `servidor/key.pem`; el archivo de clave no fue leido ni impreso.

## Verificacion de cierre Phase 1G.1

- Ambos ejemplos normativos (`NATIVE_V2` y `LEGACY_TVP_772`) validan contra
  su propia variante declarada en el contrato corregido.
- Ninguna variante acepta campos que pertenecen solo a la otra.
- No existe un tercer perfil mixto.
- `NATIVE_V2` sigue siendo el runtime final; `LEGACY_TVP_772` sigue siendo
  `LEGACY/PARITY/MIGRATION` explicito, ninguno reclasificado.
- Politica de secretos sin cambios; `DatasetBindingV2` sin cambios de forma.
- 4 bloques JSON del contrato parsean.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo contrato/estado de `integracion` y el diario append-only forman parte
  del cierre; los cambios sucios ajenos detectados al inicio quedan
  intactos.

## Turno cerrado: Phase 1G — Native Integration V2

- Publicado Integration V2 `2.0.0` (major) sobre `servidor 2.1.0`,
  `cliente 2.0.0`, `editor 2.0.0` y `assets 2.0.0`. Sin dependencia normativa
  agregada sobre `modelo-comun`/`protocolo-red`.
- `IntegrationProfileV2` con `profile_kind` cerrado: `NATIVE_V2` (runtime
  final Architecture V2, NO experimental) y `LEGACY_TVP_772` (explicito
  `LEGACY/PARITY/MIGRATION`, NO runtime primario). Se invierte la relacion
  de 1.0.0.
- Politica de secretos no negociable: ningun perfil versionado puede
  contener contrasenas/claves/tokens; solo nombres de variables de entorno o
  referencias logicas. `INTEGRATION_SECRET_IN_VERSIONED_CONFIG` rechaza
  cualquier valor con forma de secreto.
- Politica superada explicitamente: versionar `servidor/key.pem` como clave
  privada de desarrollo aceptable. El archivo NO se toco, borro ni inspecciono
  este turno; queda como nota de remediacion/deuda para una limpieza
  operativa/de seguridad futura. Ningun campo `2.0.0` porta material privado.
- `127.0.0.1:7277` deja de ser invariante de arquitectura: host/puerto son
  `server.bind_host`/`server.port` de configuracion (`1..65535`), con un
  perfil de ejemplo que puede usarlos como default.
- Publicado `DatasetBindingV2` (localizacion logica de la publicacion Assets
  V2 sin redefinir sus schemas) y prohibicion explicita de apuntar el
  perfil nativo a OTBM/OTB/DAT/SPR/`servidor/data/` como autoridad runtime.
- Publicadas capas de configuracion deterministas (defaults -> perfil
  versionado -> entorno -> CLI explicito), reglas de paths (solo
  relativos/logicos en artefactos versionados) y orden de arranque nativo de
  11 pasos sin inventar autorizacion de gameplay.
- Publicadas observaciones de disponibilidad de integracion
  (`PROCESS_STARTED`/`TRANSPORT_REACHABLE`/`PROTOCOL_NEGOTIATED`/
  `AUTHORITATIVE_BASELINE_ACCEPTED`) sin redefinir las maquinas de estado de
  `protocolo-red`/`servidor`/`cliente`.
- Declarado explicitamente: `FULL_NATIVE_PLAYABLE` esta BLOQUEADO/AUN NO
  DEFINIDO, pendiente de Authentication/Application Session y Map/World
  Rules. El smoke nativo (arranque headless, negociacion 2.1.0, baseline
  aceptado, apagado limpio, cero secretos) SI puede certificarse hoy.
  Movimiento/gameplay del prototipo historico sigue siendo evidencia
  `HISTORICAL`, nunca gate de aceptacion V2.
- Fijado sin fallback implicito: si `NATIVE_V2` falla, falla; nunca arranca
  `LEGACY_TVP_772` automaticamente, nunca reusa la clave RSA legacy, nunca
  elige otro dataset/puerto sin reportarlo.
- Roles logicos de entrypoint (`PREPARE_NATIVE`, `START_NATIVE_SERVER`,
  `START_NATIVE_CLIENT`, `OPEN_EDITOR`, `SMOKE_NATIVE`, `STOP_NATIVE` y sus
  equivalentes legacy) documentados separados de los nombres `.bat`
  existentes, que no se modificaron.
- Integration 1.0.0 preservado integro bajo
  `HISTORICAL / SUPERSEDED — Integration 1.0.0`.
- No se modificaron `.bat`, `project.godot`, config, Docker, escenas de
  produccion, codigo de servidor/cliente/editor ni `servidor/key.pem`.

## Dependencias downstream reportadas (Phase 1G)

- **QA V2** debe materializar las fixtures de la seccion 23 del contrato:
  perfiles minimos, ausencia de Docker/MariaDB/`key.pem` en `NATIVE_V2`,
  rechazo de secretos/paths absolutos, puertos validos/invalidos,
  precedencia de overrides, distincion de las cuatro observaciones de
  disponibilidad, bloqueo de `FULL_NATIVE_PLAYABLE`, ausencia de fallback
  automatico y preservacion de datasets/proyectos/fuentes tras apagado.
- **Authentication / Application Session** (futuro) debe publicarse antes de
  que cualquier smoke nativo pueda certificar gameplay autorizado.
- **Map / World Rules Domain** (futuro) debe publicarse antes de que `MOVE`
  o cualquier regla de mundo sea autoritativa en el smoke nativo.
- Remediacion de seguridad pendiente (fuera de este carril): decidir
  remocion/rotacion de `servidor/key.pem` versionado.

## Decisiones Phase 1G

| Decision | Motivo | Reversible |
|---|---|---|
| `NATIVE_V2` y `LEGACY_TVP_772` como unico registro cerrado de `profile_kind`, sin tercer valor mixto | Evita perfiles ambiguos que mezclen runtime final con oracle legacy | si, un minor futuro podria agregar otro valor explicito |
| Politica de secretos rechaza cualquier valor con forma de secreto, no solo nombres de campo conocidos | Un campo inocuo podria terminar cargando una clave real; la deteccion por forma es mas robusta que por nombre | no |
| `servidor/key.pem` no se toca este turno, solo se documenta como deuda | El turno es contract-only; borrar/rotar una clave es una accion operativa fuera de alcance y potencialmente destructiva | no aplica (decision de alcance) |
| `FULL_NATIVE_PLAYABLE` declarado bloqueado explicitamente | Sin Authentication/Application Session y Map/World Rules, certificar jugabilidad completa seria una afirmacion falsa | no, hasta que esos contratos existan |
| Roles logicos de entrypoint separados de nombres `.bat` | Permite documentar el contrato sin tocar los scripts existentes este turno | si |

## Verificacion de cierre Phase 1G

- 4 bloques JSON del contrato parsean.
- Los eventos agregados son lineas JSON validas y solo se anexaron al final.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo contrato/estado de `integracion` y el diario append-only forman parte
  del cierre; los cambios sucios ajenos detectados al inicio quedan
  intactos.
- No se modificaron `.bat`, `project.godot`, Docker, escenas, codigo de
  servidor/cliente/editor ni `servidor/key.pem`; el archivo de clave no fue
  leido ni impreso.
- Ningun ejemplo normativo contiene un valor de credencial/clave real.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Depende de

- `servidor` 2.1.0: contrato publicado.
- `cliente` 2.0.0: contrato publicado.
- `editor` 2.0.0: contrato publicado.
- `assets` 2.0.0: contrato publicado.

## Le toca

Ensamblar configuracion, roles de entrypoint y smoke nativo sobre los
contratos V2 publicados, manteniendo `LEGACY_TVP_772` como perfil explicito
no primario, hasta que Authentication/Application Session y Map/World Rules
permitan certificar `FULL_NATIVE_PLAYABLE`.

## Hecho

- Andamiaje creado.
- Flujo propio documentado: preparar, arrancar, jugar y probar dos clientes.
- `PREPARAR TVP3D PROPIO.bat` valida Godot y las escenas sin exigir Docker.
- `PROBAR SERVIDOR PROPIO.bat` ejecuta el recorrido real de dos clientes con
  el servidor Godot headless.
- El editor versionado ya esta publicado y `ABRIR MAP EDITOR.bat` conserva una
  ruta relativa al repositorio.
- `PREPARAR TVP3D.bat` y `ARRANCAR SERVIDOR.bat` pasaron con Docker Desktop
  activo; Compose construyo la imagen y dejo MariaDB saludable.
- `PROBAR CONEXION.bat` completo login, entrada al mundo y cuatro movimientos:
  11 mensajes recibidos.

## Falta

- Repetir el primer arranque legacy desde un clon limpio cuando se haga la
  prueba de entrega.
- Mantener la revision cruzada de los perfiles legacy y propio.

## Bloqueos activos

- Ninguno para la integracion validada en este entorno.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Puertos y rutas viven en configuracion del perfil | Evita duplicarlos en scripts | si |
| La configuracion y RSA se versionan para el perfil privado de desarrollo | El usuario confirmo que el repositorio privado no contiene secretos operativos | si |

## Notas para quien retome

- El perfil integrado usa TVP/C++ en Docker con puertos 7171/7172.
- El perfil `PROPIO` sigue siendo una ruta experimental separada y usa el
  resolver comun de Godot.
- `PREPARAR TVP3D PROPIO.bat` paso; con el servidor iniciado, `PROBAR SERVIDOR
  PROPIO.bat` paso con dos clientes y rechazo de ocupacion.
- `PREPARAR TVP3D.bat` paso Godot, config y RSA, pero reporto Docker Desktop no
  iniciado en la primera comprobacion; tras iniciar Docker Desktop, el
  preflight paso, Compose arranco y la prueba legacy completo correctamente.
- Compose se detuvo limpiamente despues de la validacion; los puertos 7171,
  7172, 3371 y 8071 quedaron libres y los volumenes no se eliminaron.
