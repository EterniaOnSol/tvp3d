# Estado: integracion

Estado: EN_CURSO
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T06:23:39-06:00
Contrato publicado: SI

## Depende de

- `servidor`: contrato publicado.
- `cliente`: contrato publicado.
- `editor`: falta contrato.
- `assets`: contrato publicado.

## Le toca

Ensamblar configuracion, escenas, comandos de arranque y empaquetado.

## Hecho

- Andamiaje creado.
- Flujo propio documentado: preparar, arrancar, jugar y probar dos clientes.
- `PREPARAR TVP3D PROPIO.bat` valida Godot y las escenas sin exigir Docker.
- `PROBAR SERVIDOR PROPIO.bat` ejecuta el recorrido real de dos clientes con
  el servidor Godot headless.

## Falta

- Integrar el contrato y escena del editor para cerrar el flujo completo.
- Validar el primer arranque legacy desde un clon limpio con Docker Desktop.
- Mantener la revision cruzada de los perfiles legacy y propio.

## Bloqueos activos

- `EDITOR_SIN_CONTRATO`: la integracion completa aun depende del carril editor.
- `DOCKER_DESKTOP_NO_INICIADO_EN_ENTORNO`: el perfil legacy no puede validar
  runtime Docker en esta maquina.

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
