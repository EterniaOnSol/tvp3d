# Estado: integracion

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T07:26:36-06:00
Contrato publicado: SI

## Depende de

- `servidor`: contrato publicado.
- `cliente`: contrato publicado.
- `editor`: contrato publicado.
- `assets`: contrato publicado.

## Le toca

Ensamblar configuracion, escenas, comandos de arranque y empaquetado.

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
