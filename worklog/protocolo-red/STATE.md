# Estado: protocolo-red

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-09-09T16:35:03-06:00
Contrato publicado: SI

## Ultimo turno cerrado

- Phase 1B publico Protocol V2 `2.0.0` sobre `modelo-comun 2.0.0`.
- Se congelaron las capas TCP/frame/payload, header de 16 bytes, kinds,
  handshake, estados, sync por snapshot, errores, limites y fixtures.
- El perfil propio 1.x y el adaptador TVP 7.72 quedaron historicos/legacy
  separados y preservados como oracle; no se implemento interop.
- No se modifico codigo de red, servidor, cliente, gameplay, mapa ni runtime
  legacy.

## Depende de

- `modelo-comun`: contrato publicado.

## Le toca

Definir y probar framing, version, mensajes, errores y compatibilidad de red.

## Hecho

- Contrato v1.0.0 publicado con framing, mensajes, errores y compatibilidad.
- Framing propio endurecido para conservar buffers fragmentados, rechazar
  opcodes desconocidos y validar payloads del contrato.
- Self-test cubre fragmentacion, concatenacion, round-trip y paquetes
  invalidos sin abrir sockets.
- Prueba punta a punta contra `servidor_propio/servidor.tscn`: `HELLO`,
  `WELCOME`, cuatro movimientos cardinales y cinco estados confirmados.
- Contrato 1.1.0 publicado para el estado de criatura TVP 7.72.
- `AddCreature` conserva luz, velocidad, skull y party shield; el marcador
  corto de giro mantiene los valores anteriores y ya no cura visualmente.
- `0x8D`, `0x8F`, `0x90` y `0x91` actualizan solo criaturas conocidas,
  emiten estado confirmado y consumen IDs desconocidos sin desalinear.
- `0x6C` de `mi_id` con HP autoritativo cero emite `jugador_muerto`; una
  retirada con HP positivo queda distinguida como teleport/refresh posible.
- `estado_criatura_self_test.gd` cubre payload completo, concatenacion,
  truncados, desconocidos, giro corto, teleport y muerte; toda la regresion
  de protocolo, contenedores, controles, eventos, spells, main y editor pasa.
- Contrato 1.2.0: la muerte ya no depende del indice de pila. Se emite cuando
  la retirada `0x6C` es de `mi_id` **o** de la casilla `mi_pos`, y la vida
  autoritativa es cero. `Player::drainHealth` manda ese `0xA0` con vida cero
  antes de `Game::removeCreature`, asi que la vida siempre llega a tiempo; el
  indice de pila no.
- Medido contra el servidor real: la muerte que fallaba tres veces seguidas
  ahora se emite. Prueba viva completa: muerte confirmada, logout `0x14`,
  sesion cerrada por el servidor, reingreso vivo y corpse con loot.
- `red/mapa_self_test.gd`: 13 comprobaciones que codifican los saltos igual que
  `GetFloorDescription` (contador `skip` desde -1, tandas de 255, desfase por
  piso). El lector de mapas cae en la coordenada correcta y consume el mensaje
  entero en todos los casos bien formados.
- `EstadoMundo` comprueba la invariante del servidor —el jugador siempre esta
  descrito en su propia casilla— y, si no se cumple, deja `mapa_alineado` en
  falso y emite `mapa_desalineado` con los client ids sin catalogo.
- `red/diagnostico_pila_viva.gd`: entra con un personaje, no toca nada y
  muestra la pila de la casilla propia y sus vecinas. Es la forma rapida de
  ver si el mapa vivo esta alineado.

- Capturado el mapa vivo que falla: `generated/capturas/entrada_mundo.bin`,
  2242 bytes del `0x64` real en `(32082,32145,6)`. El mismo recorrido en el
  templo `(32369,32241,7)` llega perfecto, asi que el fallo depende del sitio.
- `red/analizar_captura.gd` reproduce el caso sin servidor y descarta causas.
- RESUELTO el desalineamiento del mapa. La causa la dio el OTBM del servidor
  usado como oraculo: en la casilla real numero 256 el lector aterrizaba en
  `(32076,32146,6)` cuando el servidor describia `(32076,32147,6)`. Entre las
  dos casillas el mensaje traia dos marcas pegadas, `(10,0xFF)` y `(1,0xFF)`,
  y el OTBM decia que ahi habia 12 vacias, no 11.
- El motivo: una marca normal se escribe justo antes de describir una casilla,
  y esa casilla puede ocupar cero bytes cuando no tiene suelo, items ni
  criaturas visibles. El lector se salteaba ese casillero y perdia un lugar
  por cada uno.
- Con el arreglo, el mismo mapa vivo entrega 356 casillas —exactamente las que
  el OTBM dice que hay en esa ventana—, el jugador aparece en su casilla y no
  queda ningun client id fuera del catalogo.
- `red/mapa_captura_self_test.gd` fija la regresion con los bytes reales; el
  mensaje se consume entero, incluidos el `0xA2` y el `0x6B` que vienen detras
  del mapa.
- Contrato 1.3.0 con la regla escrita.
- Contrato 1.4.0: transporte de party. Las seis ordenes `0xA3` a `0xA8` con los
  payloads de `protocolgame.cpp:1171-1207`, y un id vacio que no se manda.
- Este servidor no contesta ningun paquete de party: la party se deduce de los
  escudos `0x91`, que `Party` manda para cada miembro e invitado
  (`servidor/src/party.cpp:39-268`).
- `red/party_self_test.gd`: 21 comprobaciones con bytes exactos, incluidos los
  cinco valores de escudo y un escudo de criatura desconocida que se consume
  sin inventarla ni desalinear el mensaje siguiente.
- Comprobado en vivo que el servidor acepta `0xA7` y `0xA8` sin cortar la
  sesion: despues de mandarlos, el mapa del teleport llega alineado.
- Contrato 1.5.0: el `0x7D` saliente de comercio, que `qa` armaba a mano en su
  prueba viva. Se publica junto con el atajo de inventario `(0xFFFF, ranura,
  0)`, y sin `player_id` valido no se manda nada.
- `red/comercio_self_test.gd`: 7 comprobaciones con bytes exactos de `0x7D` a
  `0x80`, incluidas las dos formas de direccionar un objeto.
- Contrato 1.6.0: la ventana de texto. El `0x96` entrante trae id, item,
  maximo, texto y autor; el `0x89` saliente escribe. Hasta ahora el cliente no
  conocia ninguno de los dos, asi que usar un cartel o una etiqueta cortaba el
  resto del mensaje sin decir nada.
- El paquete no dice si el item se puede escribir: las dos ramas de
  `sendTextWindow` mandan la misma forma. El cliente no lo adivina y deja que
  el servidor rechace el `0x89` si no correspondia.
- `red/ventana_texto_self_test.gd`: 15 comprobaciones con bytes exactos, con
  etiqueta en blanco, mensaje pegado detras y ventana truncada.
- La prueba viva completa quedo en un solo fallo, y es de otro carril: la
  limpieza del demon con `/killall`. El corpse del jugador, que fallaba antes,
  ahora pasa.

## Falta

- Validar el recorrido contra el servidor Godot propio con dos clientes.
- Mantener el adaptador TVP 7.72 separado de este framing JSON.
- Actualizar `worklog/OPCODES_772.md`, que todavia describe
  `0x8D/0x8F/0x90/0x91` como SKIP y no menciona party ni el `0x7D` saliente.

## Bloqueos activos

- ATENDIDA el 2026-08-29: la solicitud de interfaz de party. `cliente` 1.3.0
  publico el menu del Battle List con invitar, unirse, revocar, pasar
  liderazgo y salir, armado con los escudos confirmados.
- ATENDIDA el 2026-08-29: la solicitud de party viva. `qa` la corrio con dos
  clientes y los escudos de los dos lados contaron la misma party en cada
  paso (`docs/qa/PRUEBA_VIVA_PARTY.md`).
- SOLICITUD A `qa` (ruta suya): en la corrida viva del mapa ya alineado, el
  unico fallo que queda es "la limpieza retira al demon invocado". `/killall`
  solo alcanza el cuadro alrededor de quien lo dice y el verdugo puede haberse
  movido. Es logica de la prueba, no del protocolo. Conviene tambien adoptar
  `red/mapa_captura_self_test.gd` en la matriz local.

- CERRADO el 2026-08-29: el `0x64` desalineado. Se deja el rastro de lo que se
  descarto antes de dar con la causa, que fue una casilla descrita con cero
  bytes:

  - No es la regla de saltos. Las cuatro variantes posibles (+0/+1 en la marca
    normal, 255/256 en la tanda) dejan la captura igual de desalineada.
  - No es un item suelto con el ancho equivocado. Se probaron las 594
    posiciones de item de la captura sumando y restando un byte: ninguna
    alinea.
  - No es el tamano de la ventana: `Map::maxClientViewportX/Y` valen 8 y 6, y
    `sendMapDescription` manda 18x14, que es lo que pide el lector.
  - No es `GetTileDescription`: suelo, top items, criaturas en orden inverso y
    down items, con tope de 10, es exactamente lo que lee el cliente.
  - No es el algoritmo en si: `red/mapa_self_test.gd` codifica los saltos como
    el C++ —incluido el `skip == 0xFE` propio de esta rama, que hace tandas de
    256 desde -1 y de 255 desde 0— y pasa 13/13.

  Lo que si funciono: usar `servidor/data/world/map.otbm` como oraculo. El
  OTBM dice que casillas existen, y esa secuencia es exactamente la que el
  servidor describe, asi que la primera coordenada en la que el lector se
  aparta senala el punto justo. Vale la pena repetir ese metodo ante cualquier
  duda de alineacion.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| TCP propio como primera version | Encaja con el ritmo de Tibia y simplifica entrega inicial | si |
| Framing de 4 bytes little-endian + opcode de 1 byte + JSON UTF-8 | Coincide con `protocolo_tvp3d.gd` y permite inspeccion sencilla durante la primera rebanada | si |
| El decoder devuelve siempre `buffer`, incluso con un frame incompleto | Evita perder bytes cuando TCP fragmenta el encabezado o el cuerpo | si |
| La muerte no depende del indice de pila del `0x6C` | El indice solo vale si la pila local coincide con la del servidor, y eso se rompe cuando el mapa llega desalineado; la casilla y la vida cero son autoritativas siempre | si |
| Un mapa desalineado se denuncia, no se corrige adivinando | Los anchos de item no se pueden deducir del mensaje: inventarlos corrompe todo lo que sigue sin dejar rastro | no |
| La captura del mapa vivo se versiona como fixture | Permite reproducir el fallo sin servidor y sin depender de donde este parado nadie | si |

## Notas para quien retome

- No mezclar el framing propio con el protocolo TVP 7.72.
- `cliente3d/red/` mantiene el adaptador legacy TVP 7.72; este turno solo toca
  el codec propio y su self-test dentro del carril de protocolo.
- El warning de cierre `Unreferenced static string to 0: servers` proviene del
  runtime de Godot al apagar el servidor de prueba y no afecto su codigo de
  salida ni el recorrido.
- Herramientas de este carril, ninguna toca el mundo:
  `--script res://red/diagnostico_pila_viva.gd` entra, va al campo y muestra la
  pila de la casilla propia; `--script res://red/analizar_captura.gd` recorre
  la captura versionada sin servidor.
- Continuidad: ejecutar
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d --script res://red/estado_criatura_self_test.gd`.
  El siguiente carril no debe volver a inferir muerte solo desde `0x6C`: debe
  consumir la señal ya validada y conservar la autoridad del servidor.
