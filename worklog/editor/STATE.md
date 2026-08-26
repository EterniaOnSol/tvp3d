# Estado: editor

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T06:31:00-06:00
Contrato publicado: SI (`CONTRATO.md` v1.0.0)

## Depende de

- `modelo-comun`: publicado.
- `assets`: publicado.

## Le toca

Mantener el formato de autoria y la edicion reproducible de tiles y perfiles
3D, sin modificar las fuentes importadas.

## Hecho

- Contrato `tvp3d.project.v1` publicado.
- Modelo `ProyectoTVP3D` con fuente, overrides, perfiles y validacion estricta.
- Undo/redo acotado a 64 estados.
- Guardado y exportacion JSON deterministas en `assets/proyectos/`.
- Botones Nuevo, Abrir, Guardar, Deshacer, Rehacer y Exportar integrados en la
  escena existente.
- Override de tile visible como volumen coloreado en el mapa.
- Guardar mapping actualiza tambien el perfil del proyecto propio.
- Self-test aislado y self-test de escena pasan.

## Falta

- Revision visual manual con ventana grafica y prueba cruzada con la
  integracion completa.
- Decidir en una siguiente iteracion si se necesita dialogo de archivos en vez
  de rutas editables.

## Bloqueos activos

- Ninguno para cerrar este carril.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El editor exporta un formato propio versionado | Separa autoria de los datos originales | si |
| Los tiles se guardan como overrides dispersos | Evita duplicar el mapa importado | si |
| Los enteros JSON se normalizan al cargar/guardar | Mantiene determinismo entre runtimes | si |

## Notas para quien retome

- Un sprite plano no se convierte automaticamente en malla correcta; el
  perfil 3D debe conservar el id y declarar su geometria/material.
- La escena sigue usando el mapa real importado para visualizacion; el
  proyecto solo agrega autoria encima.
