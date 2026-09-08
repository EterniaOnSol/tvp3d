# Demon 35

Modelo anatomico basado en las cuatro vistas del atlas original 7.72.
El mismo outfit es compartido por Demon, Apocalypse, Morgaroth, Infernatil
 y Bazir, igual que en el catalogo original.

Referencia: demon_referencia.png. Capturas de Godot: demon_frente.png,
demon_dorso.png, demon_perfil.png, demon_otro_perfil.png.

Cuerpo rojo inclinado, hombros grandes, manos con garras, cuernos marfil
curvados, boca verde/amarilla, relieves dorsales y cola. RGB exclusivamente
del sprite original. Es una interpretacion volumetrica; no una copia pixel
por pixel. Tres poses con apoyo alternado y paleta estable.

Huella artistica: 1.85 casillas; altura: 2.043. No cambia colisiones.
35376 triangulos por pose; archivo 8596392 bytes; cache compartida existente.

Regenerar desde raiz: `python cliente3d/propio/monstruos3d/generar.py --ids 35`.
Verificar: `python cliente3d/propio/monstruos3d/self_test_anatomia.py` (18/18).
Godot `--headless --path cliente3d --script res://propio/monstruos3d/self_test.gd`
(708/708). Visor: `--headless --path cliente3d --script
res://propio/monstruos3d/visor.gd -- --self-test` (18/18).
Abrir: Godot `--path cliente3d --script res://propio/monstruos3d/visor.gd -- --tipo 35`.

Pendiente: revision artistica del usuario, partida viva, benchmark masivo,
exportacion. Las pruebas runtime usan el renderer real con estado sintetico.
