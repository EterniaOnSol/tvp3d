# Trolls: continuidad 2026-09-07

Troll 15, Frost Troll 53 y Swamp Troll 76 incorporados al catalogo: 36/144
apariencias con modelo, 108 pendientes. Lion/Tiger/Badger/Skunk aplazados.
Tres poses discretas, paletas RGB originales, manos y pies modelados y postura
encorvada. Escalas y alturas en ESCALAS.md. 20624 triangulos por pose.

Verificado: 16 pruebas Python y 619 comprobaciones Godot, cero fallas.
Desde la raiz TVP3D en PowerShell:

```powershell
python cliente3d/propio/monstruos3d/generar.py --ids 15 53 76
python cliente3d/propio/monstruos3d/self_test_anatomia.py
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path cliente3d --script res://propio/monstruos3d/self_test.gd
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64.exe' --path cliente3d --script res://propio/monstruos3d/visor.gd -- --tipo 15 --comparar --grupo 21,15,53,76,33,16
```

Capturas revisadas: troll_15.png (fase 0), troll_53.png (fase 1, angulo 1.3),
troll_76.png (fase 2, angulo 3.1, elevacion .35), comparacion_trolls.png.
Referencia original: trolls_referencia.png. El visor admite --fase, --angulo,
--elevacion y --captura res://propio/monstruos3d/nombre.png; requiere renderer real.

Se corrigio la prueba incompleta que leia el nivel incorrecto del catalogo,
y se cubrieron extremos de tubos en hombros, munecas y tobillos.
Prototipos sujetos a valoracion artistica: las masas corporales son visibles;
no hay rig continuo. Partida real, benchmark de grupos y exportacion pendientes.
