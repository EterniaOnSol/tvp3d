# Estado: cliente

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-08-29T07:45:00-06:00
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
- Contrato v1.2.0 publicado con el estado de criatura visible: de donde sale
  cada dato y que significa cada valor.
- `cliente3d/ui/marca_criatura.gd` dibuja la calavera y el escudo de party con
  las tablas `Skulls_t` y `PartyShields_t` copiadas de `servidor/src/const.h`.
- El Battle List y el panel Target muestran esas dos marcas junto al nombre,
  con el texto de la tabla como tooltip.
- La fila `Speed` de Skills muestra la velocidad confirmada de `mi_id`; antes
  leia un campo que el `0xA0` de 7.72 no manda y siempre valia cero.
- `pruebas/prueba_estado_criatura_ui.tscn`: 20 comprobaciones en verde,
  incluidos los cambios `0x90`, `0x91` y `0x8F` en vivo y el valor desconocido
  que se oculta.

## Falta

- Integrar la escena propia en el arranque general documentado por
  `integracion`.
- Ejecutar revision visual cruzada y comprobar input de usuario en una ventana
  no headless; las marcas todavia no se han visto dibujadas en pantalla real.
- Representar la calavera y el escudo tambien sobre la criatura en el mundo 3D.
  Hoy no hay placa de nombre flotante en `mundo3d.gd`, asi que ese trabajo es
  otro turno.
- Solicitud a `qa` (ruta suya): adoptar `prueba_estado_criatura_ui` en
  `matriz_qa_local.gd` y marcar en `docs/qa/PARIDAD_772_2026-08-29.md` que el
  punto 1 del orden verificable quedo cubierto en Battle, Target y Skills.

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
| La calavera y el escudo se dibujan por codigo, no con un sprite importado | Esta rama no tiene `Tibia.pic`, que es donde vive ese icono en el cliente 2D; inventar un PNG parecido seria peor que una forma propia con el color exacto de la tabla | si |
| La velocidad solo se muestra del personaje propio | El cliente 7.72 no ensena la velocidad ajena en ningun panel; mostrarla del objetivo seria informacion que el juego original no da | si |
| El texto de cada valor va en tooltip y en ingles | La pantalla es en ingles como Tibia, y el color solo no distingue una invitacion enviada de una recibida | si |

## Notas para quien retome

- El cliente TVP 7.72 existente es referencia y compatibilidad, no dueño del
  cliente propio.
- La muerte NO tiene opcode propio en esta rama. La unica fuente valida es
  `EstadoMundo.jugador_muerto`; no volver a deducirla del `0x6C` suelto, de la
  barra de vida ni de un texto del chat.
- Las marcas no calculan nada: si una calavera aparece cuando no toca, el fallo
  esta en `estado_mundo.gd` o en el servidor, no en `marca_criatura.gd`.
- Continuidad:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_muerte_reentrada.tscn`
  y `... pruebas/prueba_estado_criatura_ui.tscn`.
