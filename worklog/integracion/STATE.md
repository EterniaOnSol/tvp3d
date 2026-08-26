# Estado: integracion

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T02:05:00-06:00
Contrato publicado: SI

## Depende de

- `servidor`: falta contrato.
- `cliente`: falta contrato.
- `editor`: falta contrato.
- `assets`: falta contrato.

## Le toca

Ensamblar configuracion, escenas, comandos de arranque y empaquetado.

## Hecho

- Andamiaje creado.

## Falta

- Contrato de ejecucion portable publicado.
- Resolver comun de Godot agregado y usado por los comandos Windows.
- Configuracion Docker y RSA de desarrollo versionadas.
- `test_controles.tscn` y `test_formas_render.tscn` pasan con 0 fallas.
- `docker compose config --quiet` valida la configuracion.

## Bloqueos activos

- Ejecutar el servidor real en una maquina con Docker Desktop iniciado.
- Validar el primer arranque desde un clon limpio.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Puertos y rutas viven en configuracion del perfil | Evita duplicarlos en scripts | si |
| La configuracion y RSA se versionan para el perfil privado de desarrollo | El usuario confirmo que el repositorio privado no contiene secretos operativos | si |

## Notas para quien retome

- El perfil integrado usa TVP/C++ en Docker con puertos 7171/7172.
- El perfil `PROPIO` sigue siendo una ruta experimental separada y usa el
  resolver comun de Godot.
- La prueba runtime del servidor queda pendiente porque Docker Desktop no
  estaba iniciado en este entorno.
