# Contrato: qa

Version: 1.0.0
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
