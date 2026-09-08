# Aves: continuidad 2026-09-07

Chicken 111, Flamingo 212, Parrot 217 y Terror Bird 218 incorporados al
catalogo: 40/144 apariencias con modelo, 104 pendientes. Lion, Tiger, Badger
y Skunk contin?an aplazados por elecci?n del usuario.

Las cuatro siluetas son propias: Chicken compacta con cresta y barbillas;
Flamingo con cuello en S y patas altas; Parrot con pico curvo y cola larga;
Terror Bird con torso pesado, patas robustas y pico grande. Todas tienen alas
plegadas separadas, dedos delanteros y trasero, apoyo alternado y RGB que
pertenecen al atlas original. Chicken, Flamingo y Terror Bird conservan tres
fases; Parrot conserva sus cuatro fases originales.

Escalas horizontales: Chicken .62, Flamingo .88, Parrot .72 y Terror Bird
1.25 casillas. Alturas generadas: .43, .96, .38 y .82 casillas. Tri?ngulos por
pose: 6920, 6852, 6104 y 6480 respectivamente.

Verificado desde la ra?z TVP3D en PowerShell:

```powershell
python cliente3d/propio/monstruos3d/referencias.py --ids 111 212 217 218 --output cliente3d/propio/monstruos3d/aves_referencia.png
python cliente3d/propio/monstruos3d/generar.py --ids 111 212 217 218
python cliente3d/propio/monstruos3d/self_test_anatomia.py
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path cliente3d --script res://propio/monstruos3d/self_test.gd
```

Resultado: Python 17/17 y Godot 690/690, cero fallas. Capturas reales revisadas:
`ave_111.png`, `ave_212.png`, `ave_217.png`, `ave_218.png` y
`comparacion_aves.png`; fuente `aves_referencia.png`.

Son prototipos estilizados sujetos a valoraci?n art?stica. Siguen pendientes
partida real, benchmark de grupos y exportaci?n distribuible.

