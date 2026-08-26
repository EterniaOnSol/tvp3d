# Estado: cliente

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T05:56:46-06:00
Contrato publicado: SI

## Depende de

- `modelo-comun`: contrato publicado.
- `protocolo-red`: contrato publicado.
- `assets`: contrato publicado.

## Le toca

Construir la experiencia jugable 3D y mostrar solo estado confirmado.

## Hecho

- Andamiaje creado.
- Contrato v1.0.0 publicado para conexion, estados, entrada, reconexion y
  autoridad visual.
- La escena propia usa el protocolo JSON propio y no el adaptador TVP 7.72.
- `WELCOME` valida mapa, posiciones, dimensiones, tipos y duplicados antes de
  renderizar.
- `STATE` reemplaza entidades confirmadas y no hace prediccion local.
- La conexion reintenta tras perdida, limpia buffer/entidades y permite
  configurar host, puerto y nombre por entorno.
- Se representan los siete tipos de tile del modelo, incluidos decoracion y
  escalera.

## Falta

- Integrar la escena propia en el arranque general documentado por
  `integracion`.
- Ejecutar revision visual cruzada y comprobar input de usuario en una ventana
  no headless.

## Bloqueos activos

- Ninguno.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El cliente envia intenciones, no resultados | Mantiene la autoridad del servidor | no |
| La reconexion limpia el estado vivo antes de reintentar | Evita mostrar como confirmado un mundo de una sesion anterior | si |
| La validacion del `WELCOME` vive en el cliente ademas del codec | Impide renderizar datos de mapa incompletos o fuera del modelo | si |

## Notas para quien retome

- El cliente TVP 7.72 existente es referencia y compatibilidad, no dueño del
  cliente propio.
