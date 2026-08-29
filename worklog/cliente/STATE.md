# Estado: cliente

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-08-29T05:52:00-06:00
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
- Contrato v1.1.0 publicado con el recorrido de muerte y reentrada del cliente
  TVP 7.72, apoyado en `protocolo-red` 1.1.0.
- `mundo3d.gd` consume `EstadoMundo.jugador_muerto`: bloquea intenciones,
  cancela uso-con, arrastre y objetivo, oculta la interfaz, muestra la
  pantalla de reentrada y envia un unico logout `0x14`.
- `cliente3d/ui/muerte.gd` presenta `You are dead.` —el mismo texto que manda
  el servidor por `0xB4`— y una sola accion para volver al selector.
- El cierre del socket despues de morir ya no salta solo al formulario de
  cuenta: deja la pantalla de reentrada esperando la decision del jugador.
- Un `0xB4` con la palabra logout ya no cancela una muerte; solo cancela una
  salida voluntaria.
- `pruebas/prueba_muerte_reentrada.tscn` cubre las dos mitades con bytes
  reales: 21 comprobaciones en verde y codigo de salida cero.

## Falta

- Integrar la escena propia en el arranque general documentado por
  `integracion`.
- Ejecutar revision visual cruzada y comprobar input de usuario en una ventana
  no headless.
- QA debe adoptar `prueba_muerte_reentrada` en `matriz_qa_local.gd` (esa ruta
  es suya) y hacer la prueba viva de muerte, corpse y loot contra el servidor.

## Bloqueos activos

- Ninguno.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El cliente envia intenciones, no resultados | Mantiene la autoridad del servidor | no |
| La reconexion limpia el estado vivo antes de reintentar | Evita mostrar como confirmado un mundo de una sesion anterior | si |
| La validacion del `WELCOME` vive en el cliente ademas del codec | Impide renderizar datos de mapa incompletos o fuera del modelo | si |
| La muerte manda el `0x14` de inmediato y no al pulsar el boton | `ProtocolGame::logout` ve al jugador ya removido y desconecta; dejar la sesion abierta mientras el jugador lee la pantalla no aporta nada | si |
| El regreso al selector lo pide el jugador, no el cierre del socket | Si el cierre saltara solo al login, la muerte pasaria sin que el jugador la vea | si |
| `_nueva_conexion()` como unico punto de creacion de la conexion | Permite probar muerte y reentrada headless sin abrir un socket real | si |

## Notas para quien retome

- El cliente TVP 7.72 existente es referencia y compatibilidad, no dueño del
  cliente propio.
- La muerte NO tiene opcode propio en esta rama. La unica fuente valida es
  `EstadoMundo.jugador_muerto`; no volver a deducirla del `0x6C` suelto, de la
  barra de vida ni de un texto del chat.
- Continuidad:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_muerte_reentrada.tscn`.
