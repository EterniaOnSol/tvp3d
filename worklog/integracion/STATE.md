# Estado: integracion

Estado: NO_INICIADO
Ultimo agente: ninguno
Ultima actualizacion: 2026-08-25T08:00:00-06:00
Contrato publicado: NO

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

- Publicar contrato de ejecucion.
- Probar arranque reproducible.

## Bloqueos activos

- Dependencias sin contrato.
- No hay remoto Git confirmado para push.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Puertos y rutas viven en configuracion del perfil | Evita duplicarlos en scripts | si |

## Notas para quien retome

- Los comandos existentes pueden ser compatibilidad TVP o juego propio; no
  mezclar sus puertos ni sus protocolos.
