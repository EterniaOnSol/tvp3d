# Contrato: qa

Version: 1.2.0
Estado: PUBLICADO
Propietario: qa
Depende de: assets, protocolo-red

## Proposito

Verificar recorridos completos y comparar una muestra del estado vivo de TVP
7.72 contra los datos estaticos importados al IR, sin convertir criaturas ni
otros datos dinamicos en parte del mapa fuente.

## Paridad IR vs estado vivo

La prueba ejecutable es:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_paridad_ventana.tscn
```

Reglas:

- Hace login contra el servidor TVP de prueba y espera el mapa inicial `0x64`.
- Compara una ventana de radio 4, es decir, 9x9 tiles en el piso actual.
- Compara cada item como `(client_id, cantidad)` en el orden recibido.
- Las criaturas se cuentan en el reporte, pero se excluyen de la comparacion
  porque son estado vivo y no pertenecen al IR estatico.
- Codigo de salida `0` exige cero diferencias; cualquier diferencia, timeout o
  desconexion produce codigo distinto de cero.

El reporte se escribe en
`cliente3d/generated/reports/live_parity_window.json` y conserva centro,
radio, fuente, conteos y diferencias.

## Resultado de referencia

La muestra ejecutada contra TVP produjo 81/81 tiles coincidentes, 0
diferencias y 1 criatura ignorada.

## No expone

- Credenciales ni secretos de despliegue.
- Autoridad de movimiento en el cliente.
- Cambios en `servidor/data/`; el servidor TVP sigue siendo la fuente viva.

## Compatibilidad

El reporte es adicional y no altera `EstadoMundo`, el IR ni el protocolo.

## Certificacion viva de muerte y corpse

La prueba `pruebas/prueba_muerte_loot_vivo.tscn` solo puede afirmar que falta
un corpse en una casilla si `EstadoMundo.mapa_alineado` sigue verdadero. Si el
jugador no aparece en su propia casilla despues del `0x64`, la pila local no es
evidencia del contenido que mando el servidor: la prueba debe fallar como mapa
desalineado y conservar `items_sin_catalogo`, `cids_sin_catalogo` y el primer
item imposible, sin atribuir el fallo al nombre o a `Creature::dropCorpse`.

La matriz local ejecuta tambien los self-tests de estado de criatura y mapa
7.72. Estos prueban paquetes sinteticos; una corrida viva sigue siendo
obligatoria para certificar que los saltos del servidor real terminan en la
misma casilla y consumen exactamente el `0x64`.

## Certificacion viva de VIP y trade

La prueba explicita es:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_trade_vip_vivo.tscn
```

Reglas:

- Abre `GOD VALENTINO` y `Valentino` en dos sesiones simultaneas y mantiene
  ambos sockets con el ping real del servidor.
- Fuerza remove/add de VIP y exige la secuencia offline, online al entrar y
  offline al salir, conservando el GUID que devuelve TVP.
- Reune a los personajes por autoridad del servidor, prepara dos fluid
  containers reales, envia oferta y contraoferta, acepta desde ambas sesiones
  y exige las actualizaciones de inventario de la transferencia, no solo el
  cierre `0x7F`.
- Es una prueba viva mutante: mueve objetos y actualiza la lista VIP de los
  personajes de prueba. No pertenece a la matriz local sin servidor.
- El objetivo acepta `--personaje=<nombre>` y `--guid=<numero>`. Otra cuenta
  puede darse con `--cuenta=<numero> --clave-env=<variable>`; la clave se lee
  del entorno y no se escribe en argumentos, reportes ni logs.
- Hasta que `protocolo-red` publique el iniciador saliente, la prueba arma el
  `0x7D` exacto dentro de QA. Esto certifica servidor, parser y transferencia,
  pero no declara utilizable la iniciacion desde la interfaz de produccion.
