"""Saca PNGs individuales de los outfits que faltan como referencia visual
(no estan en el pack de imagenes de la web).

Lee Tibia.dat + Tibia.spr con el mismo lector que usa extraer_sprites772.py,
compone la direccion sur (la que mira de frente) en fase 0, y la agranda x4
sin suavizado para que se vea nitida al mostrarsela a un modelo de IA.

Correr:  python herramientas/extraer_referencias_faltantes.py
Sale:    generated/referencias_monstruos/
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from leer_dat_spr import Sprites, cargar_dat, componer

RAIZ = Path(__file__).resolve().parent.parent
CLIENTE = RAIZ / "cliente3d" / "assets" / "cliente772"
DAT = CLIENTE / "Tibia.dat"
SPR = CLIENTE / "Tibia.spr"
SALIDA = RAIZ / "generated" / "referencias_monstruos"

DIRECCION_SUR = 2  # orden del .dat: norte, este, sur, oeste
ESCALA = 4

# nombre de archivo -> look type id (sacado de servidor/data/monster/monsters/*.xml)
FALTANTES = {
    "apocalypse": 35,
    "ashmunrah": 91,
    "bazir": 35,
    "beholder": 17,
    "blacksheep": 13,
    "bluebutterfly": 227,
    "deathslicer": 102,
    "demodras": 204,
    "dharalion": 203,
    "dipthrah": 87,
    "elderbeholder": 108,
    "fernfang": 206,
    "ferumbras": 130,
    "gamemaster": 75,
    "generalmurius": 207,
    "grorlam": 205,
    "illusion": 107,
    "infernatil": 35,
    "mahrdis": 86,
    "mimic": 92,
    "morgaroth": 35,
    "morguthis": 84,
    "necropharus": 209,
    "omruc": 90,
    "orshabaal": 201,
    "rahemos": 88,
    "redbutterfly": 228,
    "thalas": 89,
    "theevileye": 210,
    "thehalloweenhare": 74,
    "thehornedfox": 202,
    "trainingmonk": 57,
    "vashresamun": 85,
    "yellowbutterfly": 10,
    "yeti": 110,
}


def main():
    if not DAT.exists() or not SPR.exists():
        print("Faltan Tibia.dat / Tibia.spr en %s" % CLIENTE)
        raise SystemExit(1)

    print("Leyendo Tibia.dat ...")
    dat = cargar_dat(DAT)
    print("Leyendo Tibia.spr ...")
    spr = Sprites(SPR)

    SALIDA.mkdir(parents=True, exist_ok=True)

    ok, vacios = [], []
    for nombre, oid in sorted(FALTANTES.items()):
        t = dat["outfits"].get(oid)
        if t is None:
            print("  %-20s type=%-4d -> NO EXISTE en el .dat" % (nombre, oid))
            vacios.append(nombre)
            continue
        direccion = min(DIRECCION_SUR, t["dirs"] - 1)
        img = componer(t, spr, direccion, 0, 0)
        if img.getbbox() is None:
            print("  %-20s type=%-4d -> vacio" % (nombre, oid))
            vacios.append(nombre)
            continue
        grande = img.resize((img.width * ESCALA, img.height * ESCALA), Image.NEAREST)
        grande.save(SALIDA / ("%s_type%d.png" % (nombre, oid)))
        ok.append(nombre)
        print("  %-20s type=%-4d -> OK" % (nombre, oid))

    print("")
    print("Extraidos: %d" % len(ok))
    if vacios:
        print("Sin dibujo: %s" % ", ".join(vacios))
    print("-> %s" % SALIDA)


if __name__ == "__main__":
    main()
