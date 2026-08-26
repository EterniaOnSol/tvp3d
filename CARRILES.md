# CARRILES.md

Cada carril es asignable a un solo agente por turno. Las rutas listadas son de
propiedad exclusiva salvo las rutas compartidas que aparecen abajo.

## Carriles

### modelo-comun

Objetivo: definir las entidades, coordenadas, tiles, acciones y transiciones
que comparten servidor, cliente, editor y pruebas.

Depende de: ninguno.

Contrato: `worklog/modelo-comun/CONTRATO.md`, con esquemas concretos y tablas
de dominio.

Rutas: `cliente3d/comun/modelo_*.gd`, `cliente3d/comun/mapa_*.gd`.

Cierre: una prueba carga el vocabulario y rechaza un estado, tile o transicion
fuera de la tabla publicada.

### protocolo-red

Objetivo: transportar mensajes versionados entre cliente y servidor sin que el
cliente pueda mutar estado autoritativo.

Depende de: `modelo-comun`.

Contrato: `worklog/protocolo-red/CONTRATO.md`, con framing, mensajes, errores y
compatibilidad.

Rutas: `cliente3d/comun/protocolo_*.gd`, `cliente3d/red/` y los adaptadores de
red dentro de `cliente3d/servidor_propio/protocolo/`.

Cierre: prueba de fragmentacion, concatenacion, paquete invalido y round-trip
de cada mensaje del contrato.

### servidor

Objetivo: ejecutar el mundo autoritativo en Godot headless, incluyendo
movimiento, reglas, entidades, persistencia y servicios de partida.

Depende de: `modelo-comun`, `protocolo-red`, `assets`.

Contrato: `worklog/servidor/CONTRATO.md`, con comandos aceptados, eventos,
errores, autoridad y persistencia.

Rutas: `cliente3d/servidor_propio/`, `servidor_godot/`,
`cliente3d/data/servidor/`.

Cierre: dos clientes reciben el mismo estado; un cliente no puede atravesar un
tile bloqueado ni inventar un resultado; el proceso arranca con `--headless`.

### cliente

Objetivo: presentar el mundo jugable en 3D, enviar intenciones y representar
solo el estado confirmado por el servidor.

Depende de: `modelo-comun`, `protocolo-red`, `assets`.

Contrato: `worklog/cliente/CONTRATO.md`, con estados visuales, input,
reconexion y limites de autoridad.

Rutas: `cliente3d/propio/`, `cliente3d/ui_propio/`,
`cliente3d/escenas/cliente/`.

Cierre: un usuario conecta, ve un mapa 3D, camina con teclado, observa otro
jugador y no puede consolidar un movimiento rechazado.

### assets

Objetivo: importar mapa, sprites, items y metadatos de Tibia a formatos
versionados que puedan consumir el servidor, cliente y editor.

Depende de: ninguno para publicar el contrato; de `modelo-comun` para
implementar exportadores.

Contrato: `worklog/assets/CONTRATO.md`, con formatos de entrada, salida,
versionado, ids y errores de importacion.

Rutas: `herramientas/`, `cliente3d/assets/propios/`, `assets/importados/`.
Los datos originales de `servidor/data/` son referencia de solo lectura.

Cierre: importar un fixture pequeno y reproducir la misma salida byte a byte o
con una regla de normalizacion documentada.

### editor

Objetivo: editar el mapa y asignar a cada id 2D un perfil 3D exportable sin
romper coordenadas ni ids originales.

Depende de: `modelo-comun`, `assets`.

Contrato: `worklog/editor/CONTRATO.md`, con formato de proyecto, operaciones,
guardado, undo/redo y exportacion.

Rutas: `cliente3d/editor/`, `herramientas/editor/`, `assets/proyectos/`.

Cierre: abrir un fixture, cambiar un tile y un perfil 3D, guardar, recargar y
obtener exactamente el mismo resultado.

### integracion

Objetivo: ensamblar escenas, configuracion, comandos de arranque y empaquetado
del servidor y cliente.

Depende de: `servidor`, `cliente`, `editor`, `assets`.

Contrato: `worklog/integracion/CONTRATO.md`, con comandos, puertos, rutas de
datos y perfiles de ejecucion.

Rutas: `cliente3d/project.godot`, `*.bat`, `config/`,
`cliente3d/escenas/arranque/`.

Cierre: una maquina limpia puede arrancar servidor, cliente y editor con los
comandos documentados; los perfiles no imprimen secretos.

### qa

Objetivo: probar contratos y recorridos completos, y bloquear regresiones de
autoridad, red, assets, editor y arranque.

Depende de: todos los contratos anteriores; implementacion de cada carril para
las pruebas de integracion.

Contrato: `worklog/qa/CONTRATO.md`, con matriz de pruebas, fixtures y reporte.

Rutas: `cliente3d/pruebas/`, `qa/`, `docs/qa/`.

Cierre: checklist automatizado con codigo de salida distinto de cero ante
fallos y un reporte reproducible para una revision cruzada.

## Rutas reservadas y compartidas

| Ruta | Propietario | Regla |
|---|---|---|
| `AGENTS.md`, `CARRILES.md`, `PROMPTS.md`, `PLANTILLAS.md` | Orquestacion | Solo cambia al actualizar el sistema de gobierno |
| `worklog/` | Todos, con append-only en `EVENTS.jsonl` | Cada carril escribe solo su `STATE.md` y `CONTRATO.md` |
| `cliente3d/project.godot` | Integracion | Otros carriles solicitan cambios en su worklog |
| `cliente3d/comun/` | Modelo comun y protocolo, por archivo | Ningun carril cambia el archivo del otro |
| `cliente3d/assets/` | Assets | Cliente y editor consumen; no editan fuentes |
| `servidor/data/` | Ningun carril de produccion | Solo lectura, referencia externa del TVP actual |

## Fuente de verdad del dominio

Estas tablas son dato de dominio. El codigo debe cargarlas/validarlas y las
pruebas deben generarse desde ellas; no duplicarlas en condicionales.

### Estados de conexion y mundo

| Estado | Evento valido | Siguiente |
|---|---|---|
| `DESCONECTADO` | `CONECTAR` | `CONECTANDO` |
| `CONECTANDO` | `BIENVENIDA` | `EN_MUNDO` |
| `CONECTANDO` | `ERROR_RED` | `DESCONECTADO` |
| `EN_MUNDO` | `CERRAR` | `DESCONECTADO` |
| `EN_MUNDO` | `ERROR_RED` | `DESCONECTADO` |

### Resolucion de una accion

| Estado | Evento valido | Siguiente |
|---|---|---|
| `SOLICITADA` | `VALIDAR` | `VALIDADA` o `RECHAZADA` |
| `VALIDADA` | `APLICAR` | `APLICADA` |
| `APLICADA` | `EMITIR` | `EMITIDA` |
| `RECHAZADA` | `NOTIFICAR` | `EMITIDA` |

### Vocabulario inicial de tiles

`SUELO`, `PARED`, `AGUA`, `ARBOL`, `ROCA`, `DECORACION`, `ESCALERA`.

Un importador que reciba otro valor debe fallar con el id y el archivo de
origen; no debe convertirlo silenciosamente en `SUELO`.

## Grafo y olas

```text
modelo-comun  ----> protocolo-red ----> servidor ----\
      |                    |             cliente ----+--> integracion --> qa
      |                    |                         /
      +------------------> cliente                  /
assets ------------------> servidor --------------/
assets + modelo-comun ---> editor ----------------/
```

Ola 0: publicar contratos de `modelo-comun` y `assets` en paralelo.

Ola 1: publicar `protocolo-red`; con ese contrato, preparar contratos de
`servidor`, `cliente` y `editor`.

Ola 2: implementar servidor, cliente, assets y editor respetando contratos;
servidor y cliente pueden avanzar en paralelo despues de sus dependencias.

Ola 3: integrar arranque y datos.

Ola 4: ejecutar QA y revision cruzada.
