# Estado: editor

Estado: NO_INICIADO
Ultimo agente: ninguno
Ultima actualizacion: 2026-08-25T08:00:00-06:00
Contrato publicado: NO

## Depende de

- `modelo-comun`: falta contrato.
- `assets`: falta contrato.

## Le toca

Editar tiles y perfiles 3D, y guardar proyectos reproducibles.

## Hecho

- Andamiaje creado.

## Falta

- Publicar contrato de proyecto.
- Implementar edicion, undo/redo, guardado y exportacion.

## Bloqueos activos

- Dependencias sin contrato.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El editor exporta un formato propio versionado | Separa autoria de los datos originales | si |

## Notas para quien retome

- Un sprite plano no se convierte automaticamente en malla correcta; el
  perfil 3D debe conservar el id y declarar su geometria/material.
