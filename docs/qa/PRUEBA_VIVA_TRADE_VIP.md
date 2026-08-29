# Prueba viva de VIP y trade

Fecha: 2026-08-29

Esta prueba abre dos clientes reales contra TVP 7.72. No inventa el resultado
del comercio: el servidor valida alcance, objetos, ofertas y transferencia.

Archivo: `cliente3d/pruebas/prueba_trade_vip_vivo.tscn`.

## Comando exacto

```text
"C:\Users\dell\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path cliente3d pruebas/prueba_trade_vip_vivo.tscn
```

Requiere TVP escuchando en `127.0.0.1:7171/7172` y los personajes locales de
prueba `GOD VALENTINO` y `Valentino`. La prueba respeta la proteccion de
conexiones del servidor dejando seis segundos entre sesiones.

## Recorrido certificado

1. El god elimina a Valentino de VIP y lo agrega otra vez por nombre.
2. TVP devuelve `0xD2` con GUID 2 y estado offline.
3. Valentino entra por otro socket; el god recibe `0xD3` online.
4. El servidor reune ambos personajes en una zona segura y a alcance de trade.
5. Se preparan dos fluid containers reales, server id 2006/client id 2874.
6. Cada cliente presenta su objeto: ambos reciben oferta propia `0x7D` y
   contraparte `0x7E`.
7. Ambos aceptan con `0x7F`. TVP mueve los dos objetos, actualiza los
   inventarios y cierra las dos ventanas sin error mecanico.
8. Valentino sale limpiamente; el god recibe `0xD4` offline.

La corrida final termino en codigo 0 y dejo estas comprobaciones en verde:

```text
OK: VIP agrega por nombre y devuelve GUID real
OK: VIP agregado aparece offline
OK: servidor reune ambos jugadores a distancia de trade
OK: Valentino recoge un objeto real para contraofertar
OK: el servidor crea un segundo objeto para la oferta del god
OK: ambos clientes reciben oferta propia y contraparte
OK: servidor cierra trade en ambas sesiones tras aceptar
OK: trade aceptado no devuelve error mecanico
OK: trade transfiere ambos objetos en inventarios autoritativos
OK: VIP informa online -> offline
RESULTADO: OK (0 fallas)
```

El objetivo se puede cambiar sin duplicar la prueba:

```text
... prueba_trade_vip_vivo.tscn -- --personaje="Son Goku" --guid=16
```

Para otra cuenta admite `--cuenta=<numero> --clave-env=<variable>`. La clave
se toma del entorno y nunca se imprime. La certificacion adicional con Son
Goku termino tambien en codigo 0. Como no se uso ni expuso su clave, durante
esa corrida se asocio temporalmente el personaje a la cuenta de pruebas y un
bloque `finally` restauro su cuenta original al terminar.

## Mutaciones y limite encontrado

La prueba altera deliberadamente los personajes: normaliza sus manos, crea
dos vials mediante la talkaction real `/i`, intercambia los objetos y conserva
la entrada VIP del god. Los `Sorry, not possible.` producidos al intentar
vaciar una ranura que ya estaba vacia son precondiciones esperadas y ocurren
antes del trade; un error recibido durante la oferta o aceptacion hace fallar
la corrida.

`Conexion772` expone aceptar, cancelar y mirar trade, pero no expone la
solicitud inicial `0x7D` (`position + client id + stackpos + player id`). QA
arma ese payload exacto para certificar la autoridad sin modificar el carril
ocupado `protocolo-red`. Falta publicar el metodo de produccion y conectarlo a
una interaccion del mundo; hasta entonces el servidor y la transferencia estan
probados, pero un jugador normal no puede iniciar el comercio desde la UI.
