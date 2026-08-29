# Contrato: qa

Version: 1.1.0
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
