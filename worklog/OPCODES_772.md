# Matriz de opcodes TVP 7.72

Documento de continuidad para terminar la capa de protocolo sin inventar
payloads. La fuente de verdad es servidor/src/protocolgame.cpp; el lector
del cliente es cliente3d/red/estado_mundo.gd y el emisor es
cliente3d/red/conexion772.gd.

## Como leer la matriz

- HECHO: opcode usado y probado en el cliente.
- PARCIAL: el payload se consume, pero aun falta guardar el estado, emitir
  evento, dibujarlo o exponer una accion de UI.
- FALTA: aun no hay implementacion cliente.
- SKIP: se consume para no desalinear el paquete, pero se pierde la funcion.
- N/A: opcode de otra direccion o de una variante no usada por Windows 7.72.

## Cliente hacia servidor

| Opcode | Funcion 7.72 | Estado actual |
|---|---|---|
| 0x14 | logout | FALTA |
| 0x1D | pingback | PARCIAL |
| 0x1E | respuesta/ping | HECHO, respuesta al ping del servidor |
| 0x32 | extended opcode | FALTA |
| 0x64 | auto-walk con lista de direcciones | HECHO |
| 0x65-0x68 | paso norte/este/sur/oeste | HECHO |
| 0x69 | detener auto-walk | FALTA |
| 0x6A-0x6D | paso diagonal | FALTA como metodo publico |
| 0x6F-0x72 | girar norte/este/sur/oeste | FALTA como metodo publico |
| 0x78 | throw/mover objeto | HECHO |
| 0x7D | solicitar trade | FALTA |
| 0x7E | mirar objeto en trade | FALTA |
| 0x7F | aceptar trade | FALTA |
| 0x80 | cerrar trade | FALTA |
| 0x82 | usar item | HECHO |
| 0x83 | usar item sobre item | FALTA |
| 0x84 | usar item sobre criatura | FALTA |
| 0x85 | rotar item | FALTA |
| 0x87 | cerrar contenedor | HECHO |
| 0x88 | subir al contenedor padre | FALTA |
| 0x89 | responder text window | FALTA |
| 0x8A | responder house window | FALTA |
| 0x8C | mirar objeto/casilla | FALTA |
| 0x8D | mirar criatura en battle list | FALTA |
| 0x96 | hablar | HECHO |
| 0x97 | pedir lista de canales | FALTA |
| 0x98 | abrir canal | FALTA |
| 0x99 | cerrar canal | FALTA |
| 0x9A | abrir canal privado | FALTA |
| 0x9B | procesar rule violation | FALTA |
| 0x9C | cerrar rule violation | FALTA |
| 0x9D | cancelar rule violation | FALTA |
| 0xA0 | modos de combate | HECHO |
| 0xA1 | atacar criatura | HECHO |
| 0xA2 | seguir criatura | HECHO |
| 0xA3 | invitar a party | FALTA |
| 0xA4 | aceptar party | FALTA |
| 0xA5 | revocar invitacion de party | FALTA |
| 0xA6 | pasar liderazgo de party | FALTA |
| 0xA7 | salir de party | FALTA |
| 0xA8 | shared party experience | FALTA |
| 0xAA | crear canal privado | FALTA |
| 0xAB | invitar al canal | FALTA |
| 0xAC | expulsar del canal | FALTA |
| 0xBE | cancelar ataque/seguimiento | FALTA |
| 0xC9 | actualizar casilla | FALTA |
| 0xCA | actualizar contenedor | FALTA |
| 0xD2 | pedir ventana de outfit | FALTA |
| 0xD3 | elegir outfit | FALTA |
| 0xDC | agregar VIP | FALTA |
| 0xDD | quitar VIP | FALTA |
| 0xE6 | bug report | FALTA |
| 0xE8 | debug assert | FALTA |
| 0xF9 | respuesta de modal window | FALTA |

## Servidor hacia cliente

| Opcode | Funcion 7.72 | Estado actual |
|---|---|---|
| 0x0A | entrada al mundo, own id | HECHO |
| 0x0B | derechos de gamemaster | SKIP |
| 0x14 | rechazo de login/game | HECHO |
| 0x15 | FYI box | PARCIAL, se consume sin evento |
| 0x1D/0x1E | ping | PARCIAL, 0x1E emite pedido_ping |
| 0x32 | extended opcode | FALTA |
| 0x64 | mapa completo | HECHO |
| 0x65-0x68 | franjas de mapa | HECHO |
| 0x69 | actualizacion completa de casilla | HECHO |
| 0x6A | agregar objeto a casilla | HECHO |
| 0x6B | reemplazar objeto/turn creature | HECHO, turn se conserva parcial |
| 0x6C | quitar objeto de casilla | HECHO |
| 0x6D | mover criatura | HECHO |
| 0x6E | abrir contenedor | HECHO |
| 0x6F | cerrar contenedor | HECHO |
| 0x70 | agregar objeto a contenedor | HECHO |
| 0x71 | reemplazar objeto de contenedor | HECHO |
| 0x72 | quitar objeto de contenedor | HECHO |
| 0x78 | actualizar inventario | HECHO |
| 0x79 | vaciar slot de inventario | HECHO |
| 0x82 | luz del mundo | SKIP |
| 0x83 | efecto magico | SKIP |
| 0x84 | texto animado | SKIP |
| 0x85 | proyectil a distancia | SKIP |
| 0x86 | cuadrado de criatura | SKIP |
| 0x8C | vida de criatura | SKIP |
| 0x8D | luz de criatura | SKIP |
| 0x8E | outfit de criatura | PARCIAL, payload consumido |
| 0x8F | velocidad de criatura | SKIP |
| 0x90 | skull de criatura | SKIP |
| 0x91 | shield de party | SKIP |
| 0xA0 | stats del jugador | HECHO |
| 0xA1 | skills del jugador | HECHO |
| 0xA2 | iconos de condiciones | SKIP |
| 0xA3 | cancelar objetivo | SKIP |
| 0xA7 | modos de combate | SKIP |
| 0xAA | habla en mapa/canal/privado | HECHO |
| 0xAB | dialogo de canales | FALTA |
| 0xAC | canal abierto | FALTA |
| 0xAD | canal privado abierto | FALTA |
| 0xAE | rule violations channel | FALTA |
| 0xAF | remover rule violation | FALTA |
| 0xB0 | cancelar rule violation | FALTA |
| 0xB1 | bloquear rule violation | FALTA |
| 0xB2 | crear canal privado | FALTA |
| 0xB3 | cerrar canal privado | PARCIAL, se consume sin evento |
| 0xB4 | text message | HECHO |
| 0xB5 | cancelar paso | HECHO |
| 0xC8 | ventana de outfit | FALTA |
| 0xD2 | entrada VIP | PARCIAL, se consume sin estado |
| 0xD3/0xD4 | VIP online/offline | PARCIAL, se consume sin estado |
| 0xFA | modal window | FALTA |

## Payloads ya comprobados en el servidor

No cambiar estos tamaños sin volver a revisar protocolgame.cpp:

- criatura completa dentro del mapa: marcador u16, ids, nombre opcional,
  vida u8, direccion u8, outfit, luz nivel/color, velocidad u16, skull u8 y
  party shield u8;
- 0x82 mundo: nivel de luz u8 y color u8;
- 0x83 efecto: posicion de 5 bytes y tipo u8;
- 0x84 texto animado: posicion de 5 bytes, color u8 y string;
- 0x85 tiro: posicion origen de 5 bytes, destino de 5 bytes y tipo u8;
- 0x8C criatura: id u32 y porcentaje de vida u8;
- 0x8D criatura: id u32, nivel u8 y color u8;
- 0x8E criatura: id u32 y AddOutfit;
- 0x8F criatura: id u32 y velocidad u16;
- 0x90 criatura: id u32 y skull u8;
- 0x91 criatura: id u32 y shield u8;
- 0xAB canales: count u8, luego id u16 y nombre string por canal;
- 0xAC canal: id u16 y nombre string;
- 0xAD privado: nombre del receptor string;
- 0xB2 privado: id u16 y nombre string;
- 0xB3 privado: id u16;
- 0xD2 VIP: guid u32, nombre string y estado u8;
- 0xD3/0xD4 VIP: guid u32;
- 0xFA modal: id, titulo, mensaje, botones, choices, escape, enter y
  prioridad, todos en el orden de sendModalWindow.

## Orden recomendado para continuar

1. Implementar en estado_mundo.gd los eventos visuales 0x82-0x91:
   luz, efectos, proyectiles, textos animados y metadatos de criaturas.
2. Implementar 0xAB-0xAD, 0xB2-0xB3 y 0xFA; luego conectarlos a chat,
   canales y ventanas de la UI.
3. Agregar metodos de conexion772.gd para giro, uso sobre objeto/criatura,
   trade, party, VIP, outfit y respuestas de ventanas.
4. Agregar una prueba aislada que construya cada payload y verifique que el
   siguiente opcode del mismo paquete siga alineado.
5. Solo despues completar rule violation, debug y extended opcode.

Regla de trabajo: cada opcode nuevo debe tener payload exacto, estado
persistente o signal, consumidor visual/UI y una prueba. Si falta una de esas
cuatro piezas, debe quedar como PARCIAL y no como HECHO.
