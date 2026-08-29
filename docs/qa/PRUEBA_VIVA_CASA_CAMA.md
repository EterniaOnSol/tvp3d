# Prueba viva de casa y cama

Estado: BLOQUEADO reproducible (2026-08-29)

Comando:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_casa_cama_vivo.tscn
```

Fixture: casa 6, `Sunset Homes, Flat 01`; entrada `(32333,32232,7)` y cama
server id 1754 en `(32329,32230,7)`. La prueba asigna temporalmente la casa al
personaje god, concede un día premium, intenta usar la cama y deja owner y
premium restaurados al finalizar la investigación.

Resultado observado: el servidor responde `You cannot use this object` y no
expulsa al jugador a dormir. Por tanto no se puede afirmar todavía el ciclo de
despertar ni la persistencia. La hipótesis de trabajo es que la baldosa no
queda en `ZONE_PROTECTION` para la autoridad de cama, o que falta un permiso
de casa en el mapa/runtime; debe resolverse en servidor/mapa antes de repetir.
