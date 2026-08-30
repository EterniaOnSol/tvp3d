# Estado: cliente

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-08-29T19:20:00-06:00
Contrato publicado: SI

## Depende de

- `modelo-comun`: contrato publicado.
- `protocolo-red`: contrato publicado.
- `assets`: contrato publicado.

## Le toca

Correccion aplicada: el cliente vuelve al selector al cierre autoritativo del
socket (incluido dormir en cama) y conserva los mensajes 0xB4 del servidor en
el historial para que look y rechazos puedan leerse y copiarse. Verificado con
Godot headless --editor --quit.

Segunda correccion de esta sesion (causa raiz del bloqueo real en Mill Avenue
1 / house 81): la resolucion de clic sobre una cama usaba el rayo contra el
plano del piso, igual que cualquier casilla plana. Una cama tiene
`tiene_alto=true` (su respaldo sube del piso), asi que un clic sobre esa parte
alta pasaba de largo y caia en la casilla siguiente -en el caso reportado, un
tramo de pared (client 1281, "framework wall") en vez de la cabecera real
(client 2493, server 1760). El servidor rechazaba con razon: el `spriteId`
recibido no coincidia con lo que habia en esa casilla
(`Game::playerUseItem`, `item->getClientID() != spriteId`).

Verificado con una prueba headless nueva, no con la cuenta real ni con Docker:
el fix no toca servidor, asi que no hizo falta reconstruir nada. Falta la
confirmacion visual con el cliente jugable real contra la cuenta 123456 /
Guillermo Knight (ver "Notas para quien retome").

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
- Contrato 1.3.0: menu de criatura con las acciones de party. El boton derecho
  del Battle List abre el menu, como en el cliente clasico; atacar y seguir
  siguen ahi dentro.
- Que se ofrece sale solo de los escudos confirmados: invitar, unirse,
  revocar, pasar liderazgo y salir, y nada sobre un monstruo, un NPC o uno
  mismo. Elegir una accion manda su opcode y no cambia ningun escudo: eso lo
  confirma el servidor con el `0x91`.
- La experiencia compartida no se ofrece; el cliente 7.72 no tenia ese boton.
- Contrato 1.4.0: el menu ofrece `Trade with <nombre>`. Son dos pasos como el
  "use with": primero a quien, y el clic siguiente sobre un objeto manda el
  `0x7D`. El derecho cancela, y despues de cancelar el objeto se usa como
  siempre. Si el otro salio de la vista no se manda nada.
- `pruebas/prueba_party_ui.tscn`: 20 comprobaciones en verde, una por cada
  combinacion de escudos, las dos formas de direccionar el objeto ofrecido, y
  las que verifican que mandar no adelanta estado.
- Contrato 1.5.0: la ventana de texto de carteles, cartas y etiquetas. La abre
  el servidor con el `0x96` y la respuesta va por el `0x89`. Muestra el nombre
  del item, quien lo escribio y el texto actual; corta en el maximo que puso el
  servidor y no adivina permisos, porque el paquete no dice si el item se puede
  escribir.
- `pruebas/prueba_ventana_texto_ui.tscn`: 13 comprobaciones en verde, con
  etiqueta en blanco, texto mas largo que el maximo, cartel ya escrito y
  cancelar sin mandar nada. Adoptada en la matriz, que queda 17/17.
- `pruebas/prueba_estado_criatura_ui.tscn`: 20 comprobaciones en verde,
  incluidos los cambios `0x90`, `0x91` y `0x8F` en vivo y el valor desconocido
  que se oculta.
- Contrato 1.6.0: la resolucion de clic sobre una cama (`_cama_bajo_mouse`)
  reutiliza el test de rectangulo en pantalla que ya usan las puertas simples
  (`_hit_puerta_en_pantalla`), en vez del rayo contra el plano del piso. Se
  agrega `_es_pieza_de_cama(cid)`, que reconoce cualquier mitad de cama por su
  nombre de catalogo ("bed"), a diferencia de `_es_cama_modelo` que excluye el
  pie porque esa funcion elige la malla 3D, no resuelve clics.
- La busqueda de cama recorre exclusivamente `EstadoMundo.casillas` (la
  ventana viva), nunca `_mapa_visible` ni el disco, y nunca una casilla vecina
  por cercania. Se eliminaron los dos parches de "vecindario" que un turno
  anterior habia dejado sin terminar en `_usar_en_casilla`: buscaban el
  objeto mas cercano en un radio de 3 casillas cuando el clic resolvia vacio o
  resolvia un objeto que no era cama, lo cual podia enviar un uso a una
  casilla distinta de la que el jugador realmente eligio.
- `_usar_en_casilla` y `_mirar_en_casilla` prueban primero `_cama_bajo_mouse`,
  luego `_puerta_bajo_mouse` y por ultimo el rayo contra el piso, igual que ya
  hacian solo con puertas.
- `pruebas/prueba_cama_bajo_mouse.gd` (`godot --headless -s
  res://pruebas/prueba_cama_bajo_mouse.gd`): reproduce el sintoma real -clic
  sobre el respaldo alto de la cabecera cae, por el rayo contra el piso, en
  una casilla vecina con otro objeto- y comprueba que `_cama_bajo_mouse`
  igual resuelve la cabecera real (client 2493) y el pie real (client 2494)
  cada uno en su propia casilla, que un clic lejano no adivina una cama por
  cercania, y que 1281 ("framework wall") nunca se reconoce como pieza de
  cama. 5/5 comprobaciones en verde, codigo de salida 0. No registrada todavia
  en `matriz_qa_local.gd` (ruta de `qa`); ver "Falta".

## Falta

- Integrar la escena propia en el arranque general documentado por
  `integracion`.
- Ejecutar revision visual cruzada y comprobar input de usuario en una ventana
  no headless; las marcas todavia no se han visto dibujadas en pantalla real.
- Representar la calavera y el escudo tambien sobre la criatura en el mundo 3D.
  Hoy no hay placa de nombre flotante en `mundo3d.gd`, asi que ese trabajo es
  otro turno.
- ATENDIDA: `qa` adopto `prueba_party_ui` en la matriz, que va 16/16, y corrio
  la party viva con dos clientes.
- Solicitud a `qa` (ruta suya): agregar a la prueba viva de trade el camino de
  produccion, que hoy empieza en el menu de criatura y no en la prueba.
- Ver el menu de party en una ventana real: hasta ahora solo se comprobo
  headless, que no dibuja el popup.
- Confirmacion visual en Mill Avenue 1 (house 81) con la cuenta 123456 /
  Guillermo Knight (GUID 4): entrar a la casa, hacer clic sobre cualquiera de
  las dos mitades de la cama real (server 1760 -> client 2493 en
  (32393,32176,7); server 1761 -> client 2494 en (32394,32176,7)) y confirmar
  que el chat ya no repite "You cannot use this object" ni el diagnostico de
  servidor "[BedDiag] sprite mismatch". Esta sesion no abrio esa conexion en
  vivo: el servidor sigue autoritativo (no se cambio nada de `servidor/`) y
  la prueba headless nueva ya prueba la causa raiz del lado del cliente, pero
  falta el vistazo real con la cuenta.
- Solicitud a `qa` (ruta suya, `cliente3d/pruebas/matriz_qa_local.gd`):
  adoptar `prueba_cama_bajo_mouse.gd` en la matriz local, y retomar
  `prueba_casa_cama_vivo.tscn` contra Mill Avenue 1 / house 81 ahora que la
  causa raiz del lado cliente esta corregida. El bloqueo que dejo QA
  (`RETURNVALUE_CANNOTUSETHISOBJECT` en casa 6) puede tener el mismo origen:
  el cliente enviando el sprite/posicion de una casilla vecina en vez de la
  cama real.

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
| El boton derecho del Battle List abre un menu en vez de seguir de una | Es lo que hace el cliente clasico, y seguir sigue estando dentro del menu | si |
| El menu de party se arma con los escudos y no con una lista propia | Esta rama no manda ningun paquete de party; inventar una lista seria estado que el servidor no confirmo | no |
| La experiencia compartida no se ofrece en la interfaz | El cliente 7.72 no tenia ese boton; el transporte queda por si se decide agregarla | si |
| El trade empieza por el jugador y sigue por el objeto | Es el orden inverso al del cliente clasico, pero el menu de criatura ya existe y el patron de dos pasos ya estaba en el cliente; se da vuelta el dia que haya menu de objeto | si |
| La calavera y el escudo se dibujan por codigo, no con un sprite importado | Esta rama no tiene `Tibia.pic`, que es donde vive ese icono en el cliente 2D; inventar un PNG parecido seria peor que una forma propia con el color exacto de la tabla | si |
| La velocidad solo se muestra del personaje propio | El cliente 7.72 no ensena la velocidad ajena en ningun panel; mostrarla del objetivo seria informacion que el juego original no da | si |
| El texto de cada valor va en tooltip y en ingles | La pantalla es en ingles como Tibia, y el color solo no distingue una invitacion enviada de una recibida | si |
| La cama se resuelve con rectangulo en pantalla, no con rayo contra el piso | `tiene_alto=true` hace que el rayo pase de largo por el respaldo; es el mismo mecanismo que ya usan las puertas simples, no uno nuevo | si |
| La busqueda de cama solo mira `EstadoMundo.casillas`, nunca vecinos por cercania | El usuario pidio explicitamente no ocultar el problema con un offset ni con prediccion local; adivinar la casilla mas cercana podia mandar el uso a un objeto que el jugador no eligio | si |
| Se elimino el parche de "vecindario" que un turno anterior dejo sin terminar en `_usar_en_casilla` | Era una heuristica de cercania (radio 3) sin causa raiz identificada; el fix de rectangulo la vuelve innecesaria y evita que un clic normal reciba un objeto adivinado | si |

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

- Corrección pendiente de validación visual: los teletransportes grandes ahora
  fuerzan realineación inmediata del ancla para evitar offsets de interacción.

- Causa raiz del bloqueo de camas reales (esta sesion): NO era un problema de
  mapeo servidor<->cliente (1760/1761 <-> 2493/2494 ya era correcto) ni de
  permisos de casa. Era que el clic se resolvia con un rayo contra el piso, y
  una cama tiene altura (`tiene_alto=true` en `items772.json`). El client id
  1281 que el servidor rechazaba ("You cannot use this object") es
  literalmente "framework wall" en el catalogo -un tramo de pared en la
  casilla vecina, no la cama- lo que probo que el cliente apuntaba a la
  casilla equivocada, no que el servidor tuviera mal la cama.
- El fix reutiliza `_hit_puerta_en_pantalla` (rectangulo en pantalla), ya
  validado para puertas simples. Si algun dia se generaliza a mas objetos con
  `tiene_alto=true`, esa es la funcion a extender; no crear una nueva.
- `_es_pieza_de_cama` y `_es_cama_modelo` NO son intercambiables:
  `_es_cama_modelo` excluye el pie (`IDS_CAMA_PIE`) porque decide que malla 3D
  autorada usar, y el pie no usa esa malla. `_es_pieza_de_cama` es para
  resolucion de clic y SI incluye el pie, porque el jugador puede clickear
  cualquiera de las dos mitades.
- Continuidad de esta correccion:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d -s res://pruebas/prueba_cama_bajo_mouse.gd`
  (el ejecutable de Godot 4.7.2 en esta maquina esta en
  `C:\Users\dell\3DTIBIA\herramientas\godot\`, no en el repo).
- No se toco `servidor/` en esta correccion; los diagnosticos `[BedDiag]` que
  ya estaban en `game.cpp` (sucios, sin commitear al abrir este turno) no se
  modificaron ni se les atribuye autoria de este cierre.
